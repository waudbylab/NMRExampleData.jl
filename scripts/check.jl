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

    paths = examplepath(name)
    paths = paths isa AbstractVector ? paths : [paths]
    for p in paths
        ispath(p) || push!(problems, "spectrum $(relpath(p, dir)) does not exist")
    end
    filter!(ispath, paths)
    spectra = isempty(get(toml, "spectrum", "")) ? experiments(dir) : paths
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

    processed = foldersize(dir; skip=israw)
    println("  download $(megabytes(processed)), with raw data $(megabytes(foldersize(dir)))")
    processed > 100e6 && println("  warning: over 100 MB to download without the raw data")
    return problems
end

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
