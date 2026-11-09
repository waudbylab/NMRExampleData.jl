# The catalogue page, written by make.jl from each dataset's dataset.toml and the parameter
# files of its experiments. Only the binary data are in Git LFS, so nothing is downloaded and
# the documentation builds from a clone made without LFS.

using NMRExampleData: DATASETS, released

# What the catalogue says about one dataset.
struct Entry
    info::NamedTuple             # from exampleinfo
    paths::Vector{String}        # what `path` gives, flattened, relative to the dataset
    roles::Bool                  # `path` is nested: the data come in roles
    experiments::Vector{NMRExperiment}
    raw::Bool                    # has fid or ser files
    analysis::Bool               # has a saved NMRAnalysis analysis
end

function Entry(name::AbstractString)
    info = exampleinfo(name)
    dir = joinpath(DATASETS, info.name)
    paths = isempty(info.path) ? String[] : leaves(info.path)
    roles = info.path isa AbstractVector && any(p -> p isa AbstractVector, info.path)
    folders = isempty(paths) || isscreen(paths) ? experimentfolders(dir) :
              unique(filter(!isnothing, [experimentfolder(joinpath(dir, p), dir) for p in paths]))
    return Entry(info, paths, roles, NMRExperiment.(folders), hasraw(dir),
                 isdir(joinpath(dir, "analysis")))
end

const FORMATNAMES = Dict(:bruker => "Bruker", :nmrpipe => "nmrPipe", :ucsf => "UCSF",
                         :bmrb => "NMR-STAR", :screen => "NMRScreen")

leaves(p::AbstractString) = [p]

# the file behind a format, or the first of a series
filename(p::AbstractString) = p
filename(p::AbstractVector) = first(leaves(p)) * ", …"
leaves(p::AbstractVector) = reduce(vcat, leaves.(p); init=String[])

# a screen is opened by its experiment.toml
isscreen(paths) = length(paths) == 1 && endswith(only(paths), ".toml")
isscreen(e::Entry) = isscreen(e.paths)

nspectra(e::Entry) = isempty(e.paths) ? length(e.experiments) : length(e.paths)

name(e::Entry) = e.info.name
isreleased(e::Entry) = released(name(e))
samplerecords(e::Entry) = unique(samplefile(x) for x in e.experiments if hassample(x))
nannotated(e::Entry) = count(hasannotations, e.experiments)

# The Bruker experiment folder holding `path`, which may be the folder itself, a pdata folder
# or a file inside it; nothing if there is none inside `root` (nmrPipe or UCSF data alone).
function experimentfolder(path, root)
    root = normpath(root)
    d = normpath(isdir(path) ? path : dirname(path))
    while startswith(d, root)
        isfile(joinpath(d, "acqus")) && return rstrip(d, '/')
        d = dirname(rstrip(d, '/'))
    end
    return nothing
end

experimentfolders(dir) = sort!([r for (r, _, fs) in walkdir(dir) if "acqus" in fs])

hasraw(dir) = any(f -> f == "fid" || f == "ser", (f for (_, _, fs) in walkdir(dir) for f in fs))

# ---- Markdown -----------------------------------------------------------------------------

# Text from dataset.toml as Markdown: punctuation escaped, and web addresses made into links.
function markdown(s::AbstractString)
    escape(t) = replace(t, r"([\\`*_$|<>\[\]#])" => s"\\\1")
    url = r"https?://[^\s<>]+[^\s<>.,;:)]"
    out, i = IOBuffer(), 1
    for m in eachmatch(url, s)
        print(out, escape(s[i:prevind(s, m.offset)]), "[", escape(m.match), "](", m.match, ")")
        i = m.offset + ncodeunits(m.match)
    end
    print(out, escape(s[i:end]))
    return String(take!(out))
end

# "Name <email>" to "Name": the site is public, so addresses stay in dataset.toml.
person(s) = strip(replace(s, r"<[^>]*>" => ""))

yesno(b) = b ? "yes" : "no"

plural(n, one, many=one * "s") = "$n $(n == 1 ? one : many)"

function summaryrow(e::Entry)
    cells = ["[`$(name(e))`](@ref $(name(e)))", markdown(e.info.title),
             isscreen(e) ? "screen" : string(nspectra(e)),
             join((FORMATNAMES[f] for f in keys(e.info.formats)), ", "), yesno(e.raw),
             yesno(!isempty(samplerecords(e))), yesno(nannotated(e) > 0), yesno(e.analysis),
             markdown(e.info.licence)]
    return "| " * join(cells, " | ") * " |"
end

function section(e::Entry)
    n = name(e)
    io = IOBuffer()
    println(io, "## [`$n`](@id $n)\n")
    println(io, "**", markdown(e.info.title), "**\n")
    isempty(e.info.description) || println(io, markdown(e.info.description), "\n")
    println(io, "```julia\n", join(usage(e), "\n"), "\n```\n")
    println(io, join(facts(e), " "), "\n")
    isempty(e.info.credit) ||
        println(io, "**Credit:** ", markdown(join(person.(e.info.credit), ", ")), "\n")
    isempty(e.info.citation) || println(io, "**Cite:** ", markdown(e.info.citation), "\n")
    println(io, "**Licence:** ", isempty(e.info.licence) ? "not given" : markdown(e.info.licence),
            "\n")
    return String(take!(io))
end

# The lines that open a dataset.
function usage(e::Entry)
    n = "\"$(name(e))\""
    isscreen(e) && return ["screen(example($n))"]
    lines = e.roles ? ["data = example($n)   # in the roles of its analysis"] :
            ["spec = loadnmr(example($n))"]
    for f in Iterators.drop(keys(e.info.formats), 1)
        push!(lines, "spec = loadnmr(example($n, :$f))")
    end
    e.raw && push!(lines, "fid = loadfid(example($n))")
    e.analysis && push!(lines, "expt = reopen(exampleanalysis($n))   # with NMRAnalysis")
    return lines
end

# Sentences describing a dataset's contents.
function facts(e::Entry)
    s = String[]
    k = nspectra(e)
    if isscreen(e)
        push!(s, "A screen, opened with NMRScreen from its `experiment.toml`.")
    elseif e.roles
        push!(s, "$k spectra, in the roles their analysis takes them, as given in `dataset.toml`.")
    else
        push!(s, k == 1 ? "Loads as a single spectrum." :
                 "Loads as a vector of $k spectra, in the order given in `dataset.toml`.")
    end
    isscreen(e) || push!(s, e.raw ? "Includes the raw data." : "Processed data only.")
    length(e.info.formats) > 1 &&
        push!(s, "The same data in " *
                 join(("$(FORMATNAMES[f]) (`$(filename(p))`)" for (f, p) in pairs(e.info.formats)),
                      ", ", " and ") * ".")
    nexpt = length(e.experiments)
    records = samplerecords(e)
    if nexpt == 0
        push!(s, "There are no Bruker parameter files, so no sample records or annotations.")
    else
        push!(s, isempty(records) ? "No sample records." :
                 "Matched to $(plural(length(records), "sample record")).")
        a = nannotated(e)
        push!(s, a == 0 ? "No pulse programme annotations." :
                 a == nexpt ? "The pulse programme is annotated." :
                 "The pulse programmes of $a of $nexpt experiments are annotated.")
    end
    e.analysis && push!(s, "Includes a saved NMRAnalysis analysis, with its peak list and results.")
    isempty(e.info.aliases) ||
        push!(s, "Also called " * join(("`$a`" for a in e.info.aliases), ", ") * ".")
    isreleased(e) ||
        push!(s, "Not yet released: use it from a clone of the repository, with " *
                 "`git lfs pull`.")
    return s
end

function cataloguepage()
    entries = Entry.(examples())
    io = IOBuffer()
    println(io, """
                ```@meta
                EditURL = nothing
                ```

                # Catalogue

                Every dataset in this version of NMRExampleData. Open one by its name, as in
                `loadnmr(example("$(isempty(entries) ? "name" : name(first(entries)))"))` with NMRTools.
                Each is downloaded the first time it is used.
                """)
    if isempty(entries)
        println(io, "There are no datasets yet.")
        return String(take!(io))
    end
    println(io, """
                | Name | Title | Spectra | Formats | Raw data | Sample records | Annotations | Analysis | Licence |
                |:-----|:------|--------:|:--------|:--------:|:--------------:|:-----------:|:--------:|:--------|""")
    foreach(e -> println(io, summaryrow(e)), entries)
    println(io)
    foreach(e -> println(io, section(e)), entries)
    return String(take!(io))
end
