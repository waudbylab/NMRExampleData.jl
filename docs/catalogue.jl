# The catalogue page, written by make.jl from each dataset's dataset.toml and the parameter
# files of its experiments. Only the binary data are in Git LFS, so nothing is downloaded and
# the documentation builds from a clone made without LFS.

using NMRExampleData: DATASETS, released

# What the catalogue says about one dataset.
struct Entry
    info::NamedTuple             # from exampleinfo
    nspectra::Int                # spectra loaded by exampledata
    experiments::Vector{NMRExperiment}
    raw::Bool                    # has fid or ser files
    analysis::Vector{String}     # folders of NMRAnalysis output, relative to the dataset
end

function Entry(name::AbstractString)
    info = exampleinfo(name)
    dir = joinpath(DATASETS, info.name)
    spectra = info.spectrum isa AbstractVector ? info.spectrum :
              isempty(info.spectrum) ? String[] : [info.spectrum]
    folders = isempty(spectra) ? experimentfolders(dir) :
              unique(filter(!isnothing, [experimentfolder(joinpath(dir, s), dir) for s in spectra]))
    nspectra = isempty(spectra) ? length(folders) : length(spectra)
    return Entry(info, nspectra, NMRExperiment.(folders), hasraw(dir), analysisfolders(dir))
end

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

const OUTPUTS = ("results.csv", "global.csv", "peaklist.csv", "regionlist.csv", "series.csv")

function analysisfolders(dir)
    a = joinpath(dir, "analysis")
    isdir(a) || return String[]
    return sort!([relpath(r, dir) for (r, _, fs) in walkdir(a) if any(in(OUTPUTS), fs)])
end

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
    cells = ["[`$(name(e))`](@ref $(name(e)))", markdown(e.info.title), string(e.nspectra),
             yesno(e.raw), yesno(!isempty(samplerecords(e))), yesno(nannotated(e) > 0),
             yesno(!isempty(e.analysis)), markdown(e.info.licence)]
    return "| " * join(cells, " | ") * " |"
end

function section(e::Entry)
    n = name(e)
    io = IOBuffer()
    println(io, "## [`$n`](@id $n)\n")
    println(io, "**", markdown(e.info.title), "**\n")
    isempty(e.info.description) || println(io, markdown(e.info.description), "\n")
    println(io, "```julia\nspec = exampledata(\"$n\")\n```\n")
    println(io, join(facts(e), " "), "\n")
    isempty(e.info.credit) ||
        println(io, "**Credit:** ", markdown(join(person.(e.info.credit), ", ")), "\n")
    isempty(e.info.citation) || println(io, "**Cite:** ", markdown(e.info.citation), "\n")
    println(io, "**Licence:** ", isempty(e.info.licence) ? "not given" : markdown(e.info.licence),
            "\n")
    return String(take!(io))
end

# Sentences describing a dataset's contents.
function facts(e::Entry)
    s = String[]
    push!(s, e.nspectra == 1 ? "Loads as a single spectrum." :
             "Loads as a vector of $(e.nspectra) spectra, in the order given in `dataset.toml`.")
    push!(s, e.raw ? "Includes the raw data: load it with `exampledata(\"$(name(e))\"; fid=true)`." :
             "Processed data only.")
    nexpt = length(e.experiments)
    records = samplerecords(e)
    if nexpt == 0
        push!(s, "There are no Bruker parameter files, so no sample records or annotations.")
    else
        push!(s, isempty(records) ? "No sample records." :
                 "Matched to $(plural(length(records), "sample record")).")
        k = nannotated(e)
        push!(s, k == 0 ? "No pulse programme annotations." :
                 k == nexpt ? "The pulse programme is annotated." :
                 "The pulse programmes of $k of $nexpt experiments are annotated.")
    end
    isempty(e.analysis) ||
        push!(s, "Includes NMRAnalysis results, in " *
                 join(("`$(a)/`" for a in e.analysis), ", ") * ".")
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

                Every dataset in this version of NMRExampleData. Load one with NMRTools by its
                name, as in `exampledata("$(isempty(entries) ? "name" : name(first(entries)))")`. Each is
                downloaded the first time it is used. Raw data are downloaded only when asked for,
                with `fid=true`.
                """)
    if isempty(entries)
        println(io, "There are no datasets yet.")
        return String(take!(io))
    end
    println(io, """
                | Name | Title | Spectra | Raw data | Sample records | Annotations | Analysis | Licence |
                |:-----|:------|--------:|:--------:|:--------------:|:-----------:|:--------:|:--------|""")
    foreach(e -> println(io, summaryrow(e)), entries)
    println(io)
    foreach(e -> println(io, section(e)), entries)
    return String(take!(io))
end
