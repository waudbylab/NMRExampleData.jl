# Add a dataset: copy experiment folders into datasets/<name>, together with the sample
# records NMRTools matches to them, then ask for the metadata and write dataset.toml.
#
#     julia scripts/add.jl <name> <experiment folder>...
#
#     julia scripts/add.jl hetnoe2d_calr ~/data/calr/11 ~/data/calr/12
#
# The experiments are copied from where they are: there is no need to copy them first.
# For a series, give the experiments in the order they should load.

include("common.jl")

# Left out of every copy: TopSpin bookkeeping, and the imaginary parts of the processed data,
# which can be regenerated from the raw data.
const JUNK = Set(["scon2", "shimvalues", "audita.txt", "auditp.txt", "uxnmr.par",
                  "uxnmr.info", "specpar", "prosol_History", "thumb.png", ".DS_Store"])
isjunk(f) = f in JUNK || occursin(r"^[1-9][ri]*i[ri]*$", f)

const LICENCES = ["CC BY 4.0", "None"]

tomlstring(s) = "\"" * escape_string(s) * "\""
tomlarray(v) = "[" * join(tomlstring.(v), ", ") * "]"

const H1 = NMRTools.NMRBase.H1

# What NMRTools can tell about an experiment, to suggest the parts of the title: the
# dimensions and nuclei (empty if the spectrum does not load), the ¹H Larmor frequency
# rounded to 50 MHz, and the temperature to the nearest K (nothing if not known).
function detect(expt)
    e = NMRExperiment(expt)
    t = e[:temperature]
    d = (; dims="", nuclei="", field=protonfield(e[:channels]),
        temperature=isnothing(t) ? nothing : round(Int, t))
    try
        spec = loadnmr(expt)
        n = ndims(spec)
        nuclei = [string(spec[k, :nucleus]) for k in 1:n
                  if dims(spec, k) isa FrequencyDimension && spec[k, :nucleus] isa Nucleus]
        return merge(d, (; dims=(hasnonfrequencydimension(spec) ? "pseudo-$(n)D" : "$(n)D"),
            nuclei=join(nuclei, ",")))
    catch
        return d
    end
end

# The ¹H Larmor frequency in MHz, rounded to 50, from any channel with a known nucleus.
function protonfield(channels)
    cs = sort!([c for c in values(channels)
                if get(c, :nucleus, nothing) isa Nucleus && !isnothing(get(c, :bf, nothing))];
        by=c -> c[:nucleus] != H1)
    isempty(cs) && return nothing
    c = first(cs)
    mhz = c[:bf] / 1e6 * gyromagneticratio(H1) / gyromagneticratio(c[:nucleus])
    return round(Int, mhz / 50) * 50
end

# "308" for one value, "283-308" across a series, or "" if not known.
function span(values)
    any(isnothing, values) && return ""
    lo, hi = extrema(values)
    return lo == hi ? string(lo) : "$lo-$hi"
end

gitconfig(key) = try
    readchomp(`git config $key`)
catch
    ""
end

# The sample record matched to an experiment, from its acqus alone, or nothing.
function samplerecord(expt)
    try
        s = findsample(NMRExperiment(expt))
        return isnothing(s) ? nothing : samplefile(s)
    catch e
        println("  warning: could not look for a sample record for $expt: ",
            sprint(showerror, e))
        return nothing
    end
end

# Ask for a value, offering a default that Return accepts.
function ask(label, default=""; required=false)
    while true
        print(label, isempty(default) ? "" : " [$default]", ": ")
        eof(stdin) && error("no answer for \"$label\": run add.jl in a terminal")
        answer = strip(readline())
        value = isempty(answer) ? String(default) : String(answer)
        (isempty(value) && required) || return value
    end
end

function asklicence()
    println("Licence:")
    for (k, l) in enumerate(LICENCES)
        println("  $k. $l")
    end
    println("  $(length(LICENCES) + 1). Other")
    while true
        k = tryparse(Int, ask("Choose", "1"))
        (isnothing(k) || !(1 <= k <= length(LICENCES) + 1)) && continue
        k <= length(LICENCES) && return LICENCES[k]
        l = ask("Licence name")
        isempty(l) || return l
    end
end

function main(args)
    if length(args) < 2
        println("usage: julia scripts/add.jl <name> <experiment folder>...")
        exit(1)
    end
    name, sources = args[1], normpath.(abspath.(args[2:end]))
    occursin(r"^[a-z0-9_]+$", name) ||
        error("a dataset name is lowercase letters, digits and underscores: \"$name\"")
    dest = joinpath(DATASETS, name)
    ispath(dest) && error("datasets/$name already exists")
    for s in sources
        isfile(joinpath(s, "acqus")) || error("$s is not a Bruker experiment folder")
    end
    expnos = basename.(sources)
    allunique(expnos) ||
        error("two experiment folders have the same name: $(join(expnos, ", "))")

    # Each experiment in a series may have its own sample record. They are copied to the
    # top of the dataset, beside the experiments, which is where NMRTools looks for them.
    matched = samplerecord.(sources)
    records = unique(filter(!isnothing, matched))
    for b in unique(basename.(records))
        same = filter(r -> basename(r) == b, records)
        length(unique(read.(same))) == 1 ||
            error("different sample records share the name $b: $(join(same, ", "))")
    end
    unique!(r -> basename(r), records)

    println("Adding $(length(expnos)) experiment(s) as datasets/$name")
    for (e, r) in zip(expnos, matched)
        println("  $e: sample record ", isnothing(r) ? "none found" : basename(r))
    end
    length(expnos) > 1 && println("  loads in this order: ", join(expnos, ", "))
    println()

    # title: <protein> <dims> <nuclei> <experiment> (<field> MHz, <temperature> K)
    found = detect.(sources)
    d = first(found)
    println("Title, in the form <protein> <dims> <nuclei> <experiment> (<field> MHz, <temperature> K)")
    protein = ask("  Protein or sample label, e.g. CALR"; required=true)
    dimlabel = ask("  Dimensions, e.g. 2D or pseudo-3D", d.dims; required=true)
    nuclei = ask("  Nuclei, e.g. 1H,15N", d.nuclei; required=true)
    experiment = ask("  Experiment, e.g. HSQC or hetNOE"; required=true)
    field = ask("  1H Larmor frequency in MHz", span(getproperty.(found, :field));
        required=true)
    temperature = ask("  Temperature in K", span(getproperty.(found, :temperature));
        required=true)
    title = "$protein $dimlabel $nuclei $experiment ($field MHz, $temperature K)"
    println("  → ", title, "\n")

    description = ask("Description (optional)")

    println("Credit: one person at a time, as Name <email> or just Name. " *
        "Return on its own to finish.")
    me = gitconfig("user.name")
    email = gitconfig("user.email")
    isempty(me) || isempty(email) || (me *= " <$email>")
    credit = String[]
    while true
        p = ask("  Person", isempty(credit) ? me : ""; required=isempty(credit))
        isempty(p) && break
        occursin(PERSON, p) || (println("  should be Name <email> or Name"); continue)
        push!(credit, p)
    end

    citation = ask("Citation with DOI (optional)")
    licence = asklicence()
    aliases = filter(!isempty, strip.(split(ask("Other names, comma-separated (optional)"), ",")))

    meta = Dict("title" => title, "description" => description, "citation" => citation,
        "licence" => licence)

    spectrum = length(expnos) == 1 ? tomlstring(only(expnos)) : tomlarray(expnos)
    toml = read(TEMPLATE, String)
    for (k, v) in meta
        toml = replace(toml, Regex("^$k = .*\$", "m") => "$k = " * tomlstring(v))
    end
    toml = replace(toml, r"^spectrum = .*$"m => "spectrum = " * spectrum,
                   r"^credit = .*$"m => "credit = " * tomlarray(credit),
                   r"^source = .*$"m => "source = " * tomlstring(join(sources, ", ")),
                   r"^aliases = .*$"m => "aliases = " * tomlarray(aliases))
    # copy only once every answer is in, so a cancelled run leaves nothing behind
    for (s, e) in zip(sources, expnos)
        copytree(s, joinpath(dest, e); skip=isjunk)
    end
    for r in records
        cp(r, joinpath(dest, basename(r)))
    end
    write(joinpath(dest, "dataset.toml"), toml)

    println("""

            Added datasets/$name, $(megabytes(foldersize(dest))), raw data: $(hasraw(dest) ? "yes" : "no")
            Next, check it:
              julia scripts/check.jl $name""")
    return
end

main(ARGS)
