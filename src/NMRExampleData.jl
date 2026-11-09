"""
Example NMR datasets for NMRTools.jl, NMRAnalysis.jl and NMRScreen.jl, each downloaded the
first time it is used.

Each dataset is a folder in `datasets/` with a `dataset.toml` describing it. The registered
package holds no datasets, only `Datasets.toml`, an index of their `dataset.toml` files.
"""
module NMRExampleData

using Artifacts
using LazyArtifacts
using REPL.TerminalMenus: RadioMenu, request
using TOML

export examples, exampleinfo, example, exampleanalysis

const ROOT = dirname(@__DIR__)
const DATASETS = joinpath(ROOT, "datasets")
const ARTIFACTS = joinpath(ROOT, "Artifacts.toml")
const INDEX = joinpath(ROOT, "Datasets.toml")

"""
    examples()
    examples(format)

Return the names of the example datasets, sorted. Given a `format` such as `:ucsf`, return
only the datasets with data in that format. See [`FORMATS`](@ref NMRExampleData.FORMATS).

# Examples
```julia
julia> examples(:nmrpipe)
2-element Vector{String}:
 "2d_hn_ubq"
 "diffusion1d_asyn"
```
"""
examples() = sort!(collect(keys(catalogue())))

examples(format::Symbol) = filter(n -> haskey(exampleinfo(n).formats, format), examples())

"""
    exampleinfo(name)

Return a description of the dataset `name` from its `dataset.toml`, without downloading it.

The result is a `NamedTuple` with the fields `name` (the full name), `title`, `path`,
`formats`, `description`, `credit`, `citation`, `licence`, `source`, `aliases` and `added`.
`formats` gives the path of each format in the dataset, the default first, such as
`(bruker = "2D_HN", nmrpipe = "2D_HN/test.ft2", ucsf = "2D_HN/hmqc.ucsf")`.

`name` ignores case, and can be an alias or the start of the name or of any part of it:
`"hetnoe"` finds `"hetnoe2d_calr"`. If it matches several datasets, the one added first is
used, so a shortened name keeps finding the same dataset as more are added.

# Examples
```julia
julia> exampleinfo("hetnoe").name
"hetnoe2d_calr"
```
"""
function exampleinfo(name::AbstractString)
    datasets = catalogue()
    n = resolvename(name, datasets)
    d = datasets[n]
    credit = get(d, "credit", String[])
    path = get(d, "path", "")
    others = get(d, "formats", Dict{String,Any}())
    formats = (; format(path) => path,
               (f => others[string(f)] for f in FORMATS
                if haskey(others, string(f)) && f != format(path))...)
    return (; name=n, title=get(d, "title", ""), path, formats,
        description=get(d, "description", ""),
        credit=credit isa AbstractString ? [credit] : credit, citation=get(d, "citation", ""),
        licence=get(d, "licence", ""), source=get(d, "source", ""),
        aliases=get(d, "aliases", String[]), added=get(d, "added", ""))
end

"""
    example(name)
    example(name, format)
    example()

Return the path of the dataset `name`, downloading it if needed. Pass the path to `loadnmr`,
`loadfid` or an analysis.

A series returns a vector of paths in order, and data that an analysis takes in groups
return nested vectors, one per group. Given a `format` such as `:nmrpipe`, return the same
data in that format. Without a name, choose a dataset from a menu.

The first time you use a dataset in a session, its credit, citation and licence are shown.

# Examples
```julia
julia> using NMRTools, NMRAnalysis

julia> spec = loadnmr(example("2d_hn_ubq"))

julia> fid = loadfid(example("2d_hn_ubq"))

julia> pipe = loadnmr(example("2d_hn_ubq", :nmrpipe))

julia> decay, buildup = example("ccr2d_calr")

julia> ccr2d(decay, buildup; T=0.04)
```
"""
function example(name::AbstractString, format::Symbol=:default)
    info = exampleinfo(name)
    format == :default || haskey(info.formats, format) ||
        throw(ArgumentError("example dataset \"$(info.name)\" has no $format data: it has " *
                            join(keys(info.formats), ", ")))
    dir = datasetdir(info.name)
    showcredit(info)
    return within(dir, format == :default ? info.path : info.formats[format])
end

function example()
    names = examples()
    isempty(names) && return nothing
    width = maximum(length, names)
    entries = [rpad(n, width) * "  " * exampleinfo(n).title for n in names]
    if isinteractive() && stdin isa Base.TTY
        i = request("Choose an example dataset:", RadioMenu(entries; pagesize=min(20, length(entries))))
        return i == -1 ? nothing : example(names[i])
    end
    println("Example datasets, to open with example(name):\n")
    foreach(e -> println("  ", e), entries)
    return nothing
end

"""
    exampleanalysis(name)

Return the folder of the NMRAnalysis analysis saved with the dataset `name`, downloading the
dataset if needed. The folder holds the peak list, the results and the record that `reopen`
reads. Throw an `ArgumentError` if the dataset has no saved analysis.

# Examples
```julia
julia> using NMRAnalysis

julia> expt = reopen(exampleanalysis(name))   # ready to refit

julia> peaks = loadpeaks(exampleanalysis(name))
```
"""
function exampleanalysis(name::AbstractString)
    info = exampleinfo(name)
    get(catalogue()[info.name], "analysis", false) ||
        throw(ArgumentError("example dataset \"$(info.name)\" has no saved analysis"))
    dir = datasetdir(info.name)
    showcredit(info)
    return joinpath(dir, "analysis")
end

"""
    FORMATS

The formats a dataset can hold, in the order [`exampleinfo`](@ref) lists them: `:bruker`
(experiment folders), `:nmrpipe`, `:ucsf` (Sparky), `:bmrb` (NMR-STAR shift lists) and
`:screen` (the `experiment.toml` of an NMRScreen screen).
"""
const FORMATS = (:bruker, :nmrpipe, :ucsf, :bmrb, :screen)

"""
    format(path) -> Symbol

The format of a dataset's `path`, from its name, as `loadnmr` tells formats apart: `.ft1` to
`.ft4` and plane templates (`test%03d.ft3`) are nmrPipe, `.ucsf` is UCSF, `.str` is NMR-STAR,
`experiment.toml` is a screen, and anything else is a Bruker experiment. A series has the
format of its first member.
"""
function format(path::AbstractString)
    endswith(path, ".toml") && return :screen
    endswith(path, ".str") && return :bmrb
    endswith(path, ".ucsf") && return :ucsf
    occursin(r"\.ft[1-4]$", path) && return :nmrpipe
    return :bruker
end
format(path::AbstractVector) = isempty(path) ? :bruker : format(first(path))

# `path` from dataset.toml, inside the dataset's folder, keeping its shape
within(dir, p::AbstractString) = joinpath(dir, p)
within(dir, p::AbstractVector) = [within(dir, q) for q in p]

# Every dataset's dataset.toml, by name, with `analysis = true` for those with a saved
# analysis: read from datasets/ in a clone of the repository, and otherwise from the index
# that takes its place in the registered package.
function catalogue(datasets=DATASETS, index=INDEX)
    isdir(datasets) || return isfile(index) ? TOML.parsefile(index) : Dict{String,Any}()
    names = filter(n -> isfile(joinpath(datasets, n, "dataset.toml")), readdir(datasets))
    return Dict{String,Any}(n => entry(joinpath(datasets, n)) for n in names)
end

function entry(dir)
    d = TOML.parsefile(joinpath(dir, "dataset.toml"))
    isdir(joinpath(dir, "analysis")) && (d["analysis"] = true)
    return d
end

# Write the index of datasets/ to `path`, for the registered package.
function writeindex(path)
    open(path, "w") do io
        println(io, "# The example datasets, written by scripts/release.jl from their dataset.toml files.")
        return TOML.print(io, catalogue(); sorted=true)
    end
    return path
end

# The folder holding a dataset: its own folder in a clone of this repository with the data
# fetched from Git LFS, and otherwise the released artifact, downloaded if need be.
function datasetdir(n)
    here = joinpath(DATASETS, n)
    hasdata(here) && return here
    released(n) ||
        throw(ArgumentError("example dataset \"$n\" has not been released yet. In a clone " *
                            "of NMRExampleData.jl, run `git lfs pull` to use it from the " *
                            "repository"))
    return @artifact_str(n)
end

# datasets whose credit has been shown in this session
const CREDITED = Set{String}()

function showcredit(info)
    info.name in CREDITED && return
    push!(CREDITED, info.name)
    lines = ["Example data $(info.name): $(info.title)"]
    isempty(info.credit) || push!(lines, "Credit: " * join(info.credit, ", "))
    isempty(info.citation) || push!(lines, "Cite: " * info.citation)
    if isempty(info.licence) || info.licence == "None"
        push!(lines, "Licence: none granted. Ask those credited before using these data " *
                     "beyond trying out the software.")
    else
        push!(lines, "Licence: " * info.licence)
    end
    @info join(lines, "\n")
    return
end

# The dataset a name refers to, ignoring case: its full name or an alias, or else a dataset
# whose name, or a part of it between underscores, starts with the name given, so that
# "hetnoe" finds "hetnoe2d_calr". Where several start that way, the one added first.
function resolvename(name::AbstractString, tomls=catalogue())
    names = sort!(collect(keys(tomls)))
    q = lowercase(name)
    q in names && return q
    for n in names
        any(a -> lowercase(a) == q, get(tomls[n], "aliases", String[])) && return n
    end
    found = filter(n -> startswith(n, q) || any(p -> startswith(p, q), split(n, '_')), names)
    isempty(found) && throw(ArgumentError("no example dataset called \"$name\". " *
        "Available: $(join(names, ", "))"))
    # ISO 8601 times in UTC sort as strings. A dataset without one comes last.
    added(n) = (a = get(tomls[n], "added", ""); isempty(a) ? "~" : a)
    sort!(found; by=added)
    (length(found) == 1 || added(found[1]) != added(found[2])) && return found[1]
    return throw(ArgumentError("\"$name\" could be any of $(join(found, ", ")): " *
        "give more of the name"))
end

released(a) = !isnothing(artifact_hash(a, ARTIFACTS))

# True for a dataset folder whose files are all present. In an installed package, as in a
# clone made without Git LFS, the binary files are small text pointers to LFS instead.
function hasdata(dir)
    isdir(dir) || return false
    found = false
    for (root, _, files) in walkdir(dir), f in files
        f == "dataset.toml" && continue
        found = true
        islfspointer(joinpath(root, f)) && return false
    end
    return found
end

function islfspointer(path)
    filesize(path) < 1024 || return false
    return startswith(read(path, String), "version https://git-lfs.github.com/spec/")
end

end
