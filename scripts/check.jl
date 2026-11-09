# Check datasets: every one, or those named.
#
#     julia scripts/check.jl [name...]

include("common.jl")

const FIELDS = keys(TOML.parsefile(TEMPLATE))

# A list of problems with dataset `name`, printing what was found as it goes.
function checkdataset(name)
    dir = joinpath(DATASETS, name)
    problems = String[]
    isfile(joinpath(dir, "dataset.toml")) ||
        return ["there is no datasets/$name/dataset.toml"]
    occursin(r"^[a-z0-9_]+$", name) ||
        push!(problems, "the name should be lowercase letters, digits and underscores")
    toml = try
        TOML.parsefile(joinpath(dir, "dataset.toml"))
    catch e
        push!(problems, "dataset.toml does not parse: $(sprint(showerror, e))")
        return problems
    end
    for k in keys(toml)
        k in FIELDS || push!(problems, "dataset.toml has an unknown field \"$k\"")
    end
    title = get(toml, "title", "")
    if isempty(title)
        push!(problems, "dataset.toml needs a title")
    elseif !occursin(TITLE, title)
        println("  warning: the title is not in the form " *
            "<protein> <dims> <nuclei> <experiment> (<field> MHz, <temperature> K)")
    end
    occursin(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$", get(toml, "added", "")) ||
        push!(problems, "dataset.toml needs added, the time it was added in UTC, " *
            "such as \"2026-11-07T10:30:00Z\"")
    credit = get(toml, "credit", String[])
    credit isa AbstractVector || (credit = [credit])
    isempty(credit) &&
        println("  warning: no credit in dataset.toml, so users are not told who to credit")
    for p in credit
        p isa AbstractString && occursin(PERSON, p) ||
            push!(problems, "credit \"$p\" should be \"Name <email>\" or \"Name\"")
    end
    isempty(get(toml, "licence", "")) &&
        println("  warning: no licence in dataset.toml")
    NMRExampleData.hasdata(dir) ||
        return push!(problems, "the data files are Git LFS pointers: run `git lfs pull`")

    path = get(toml, "path", "")
    formats = exampleinfo(name).formats
    for (f, p) in pairs(get(toml, "formats", Dict()))
        Symbol(f) in NMRExampleData.FORMATS ||
            push!(problems, "formats has an unknown format \"$f\": use " *
                            join(NMRExampleData.FORMATS, ", "))
        NMRExampleData.format(p) == Symbol(f) ||
            push!(problems, "formats gives $p as $f, but it looks like " *
                            "$(NMRExampleData.format(p)) data")
        Symbol(f) == NMRExampleData.format(path) &&
            push!(problems, "formats repeats $f, the format of path")
    end
    paths = String[]
    for p in values(formats)
        isempty(p) && continue
        append!(paths, leaves(NMRExampleData.within(dir, p)))
    end
    for p in paths
        ispath(replace(p, r"%\d*d" => "001")) ||
            push!(problems, "$(relpath(p, dir)) does not exist")
    end
    filter!(p -> ispath(replace(p, r"%\d*d" => "001")), paths)
    # spectra in a format not declared would be invisible to users and to tests
    declared = Set(normpath.(paths))
    for (root, _, fs) in walkdir(dir), f in fs
        occursin(r"\.(ft[1-4]|ucsf)$", f) || continue
        p = normpath(joinpath(root, f))
        p in declared || any(d -> occursin('%', d) && dirname(d) == dirname(p), declared) ||
            println("  warning: $(relpath(p, dir)) is not in path or formats")
    end
    # a screen's experiment.toml and BMRB shifts are checked by their own packages
    spectra = isempty(path) ? experiments(dir) :
              filter(p -> NMRExampleData.format(p) in (:bruker, :nmrpipe, :ucsf), paths)
    for p in spectra
        spec = try
            loadnmr(p)
        catch e
            push!(problems, "$(relpath(p, dir)) does not load: $(sprint(showerror, e))")
            continue
        end
        notes = String[]
        hassample(spec) && push!(notes, "sample record")
        hasannotations(spec) && push!(notes, "annotations")
        println("  $(relpath(p, dir)): loads",
            isempty(notes) ? "" : ", " * join(notes, ", "))
    end
    append!(problems, checkanalysis(dir))
    for e in experiments(dir)
        any(f -> isfile(joinpath(e, f)), ("fid", "ser")) || continue
        try
            loadfid(e)
        catch err
            push!(problems,
                "raw data in $(relpath(e, dir)) does not load: " *
                    sprint(showerror, err))
        end
    end

    bytes = foldersize(dir)
    println("  download $(megabytes(bytes))")
    bytes > 100e6 && println("  warning: over 100 MB to download")
    return problems
end

# The paths of `path`, however it is nested.
leaves(p::AbstractString) = [p]
leaves(p::AbstractVector) = reduce(vcat, leaves.(p); init=String[])

# A saved analysis is an NMRAnalysis output folder: its picks in peaklist.csv, and the record
# that `reopen` reads, whose inputs (paths relative to the folder, so starting "../") must
# lie inside the dataset.
function checkanalysis(dir)
    a = joinpath(dir, "analysis")
    isdir(a) || return String[]
    problems = String[]
    isfile(joinpath(a, "peaklist.csv")) ||
        push!(problems, "analysis/ has no peaklist.csv")
    record = joinpath(a, "analysis.toml")
    if !isfile(record)
        push!(problems, "analysis/ has no analysis.toml: save it with NMRAnalysis")
        return problems
    end
    for s in strings(TOML.parsefile(record))
        startswith(s, "../") || continue
        p = normpath(joinpath(a, s))
        startswith(p, normpath(dir)) ||
            push!(problems, "analysis.toml refers to $s, outside the dataset")
        ispath(p) || push!(problems, "analysis.toml refers to $s, which does not exist")
    end
    isempty(problems) && println("  analysis: ok")
    return problems
end

strings(x::AbstractString) = [x]
strings(x::AbstractDict) = reduce(vcat, strings.(values(x)); init=String[])
strings(x::AbstractVector) = reduce(vcat, strings.(x); init=String[])
strings(x) = String[]

# Names and aliases must not collide across datasets, ignoring case as the lookup does.
function checknames()
    seen = Dict{String,String}()
    problems = String[]
    for n in examples(), a in lowercase.([n; exampleinfo(n).aliases])
        haskey(seen, a) && seen[a] != n &&
            push!(problems, "\"$a\" is used by both $(seen[a]) and $n")
        seen[a] = n
    end
    # the first added settles a shortened name that matches several, so no ties
    times = Dict{String,String}()
    for n in examples()
        t = exampleinfo(n).added
        isempty(t) && continue
        haskey(times, t) && push!(problems, "$(times[t]) and $n were added at the same time, $t")
        times[t] = n
    end
    return problems
end

function checkall(names)
    ok = true
    for p in checknames()
        println("✗ ", p)
        ok = false
    end
    for n in names
        println(n)
        problems = checkdataset(n)
        foreach(p -> println("  ✗ ", p), problems)
        isempty(problems) && println("  ✓ ok")
        ok &= isempty(problems)
    end
    return ok
end

if abspath(PROGRAM_FILE) == @__FILE__
    names = isempty(ARGS) ? examples() : ARGS
    isempty(names) && (println("No datasets to check."); exit(0))
    checkall(names) || exit(1)
end
