"""
Example NMR data shared by NMRTools.jl, NMRAnalysis.jl and NMRScreen.jl.

Each example is a folder under `datasets/` with a `dataset.toml`. Released examples are
downloaded the first time they are used, and only then.
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

"""
    examples() -> Vector{String}

Names of the available example datasets, in alphabetical order.

# Example
```julia
julia> examples()
3-element Vector{String}:
 "hetnoe2d_calr"
 "relaxation2d_ubq"
 "titration2d_fir_nbox"
```
"""
function examples()
    isdir(DATASETS) || return String[]
    return filter(n -> isfile(joinpath(DATASETS, n, "dataset.toml")), readdir(DATASETS))
end

"""
    exampleinfo(name) -> NamedTuple

The description of an example dataset, from its `dataset.toml`: `name`, `title`, `path`,
`description`, `credit` (a vector of `"Name <email>"` or `"Name"`), `citation`, `licence`,
`source`, `aliases` and `added`. Nothing is downloaded.

`name` may be the dataset's full name or an alias, in any case, or the start of the name
or of any part of it between underscores: `"hetnoe"` finds `"hetnoe2d_calr"`. Where that
matches several datasets, the one added first is used, so a shortened name keeps meaning
the same dataset as more are added. The full name is returned as `name`.

# Example
```julia
julia> exampleinfo("hetnoe2d_calr").title
"CALR 2D 1H,15N hetNOE (600 MHz, 298 K)"
```
"""
function exampleinfo(name::AbstractString)
    n = resolvename(name)
    d = TOML.parsefile(joinpath(DATASETS, n, "dataset.toml"))
    credit = get(d, "credit", String[])
    return (; name=n, title=get(d, "title", ""), path=get(d, "path", ""),
        description=get(d, "description", ""),
        credit=credit isa AbstractString ? [credit] : credit, citation=get(d, "citation", ""),
        licence=get(d, "licence", ""), source=get(d, "source", ""),
        aliases=get(d, "aliases", String[]), added=get(d, "added", ""))
end

"""
    example(name)
    example()

What an example dataset is opened with, downloading it the first time it is used: the path
given by `path` in its `dataset.toml`, with the same shape. That is an experiment folder or
file, a vector of them for a series, nested vectors where an analysis takes its data in
roles, or the `experiment.toml` of a screen. Where `path` is empty, the dataset's folder.

The first time a dataset is used in a session, who to credit, what to cite and the licence
are shown.

Without a name, choose a dataset from a menu, or outside an interactive session, list them.

See [`exampleinfo`](@ref) for how names are matched, and [`exampleanalysis`](@ref) for a
dataset's saved analysis.

# Examples
```julia
julia> using NMRTools

julia> spec = loadnmr(example("2d_hn_ubq"))          # a spectrum, or a vector of them
julia> fid = loadfid(example("2d_hn_ubq"))           # its raw data
julia> reference, saturated = example("hetnoe2d_calr")
julia> screen(example("screen_bsa"))                  # with NMRScreen
```
"""
function example(name::AbstractString)
    info = exampleinfo(name)
    dir = datasetdir(info.name)
    showcredit(info)
    return within(dir, info.path)
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
    exampleanalysis(name) -> String

The saved analysis of an example dataset: an output folder written by NMRAnalysis, with the
picked peaks in `peaklist.csv`, the results, and the record that `reopen` reads. Downloads
the dataset the first time it is used. Throws an `ArgumentError` for a dataset without one.

# Examples
```julia
julia> using NMRAnalysis

julia> expt = reopen(exampleanalysis("relaxation2d_ubq"))   # as saved, ready to refit
julia> pks = loadpeaks(exampleanalysis("relaxation2d_ubq"))  # just the peaks
```
"""
function exampleanalysis(name::AbstractString)
    info = exampleinfo(name)
    isdir(joinpath(DATASETS, info.name, "analysis")) ||
        throw(ArgumentError("example dataset \"$(info.name)\" has no saved analysis"))
    dir = datasetdir(info.name)
    showcredit(info)
    return joinpath(dir, "analysis")
end

# `path` from dataset.toml, inside the dataset's folder, keeping its shape
within(dir, p::AbstractString) = joinpath(dir, p)
within(dir, p::AbstractVector) = [within(dir, q) for q in p]

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
function resolvename(name::AbstractString)
    names = examples()
    q = lowercase(name)
    q in names && return q
    tomls = Dict(n => TOML.parsefile(joinpath(DATASETS, n, "dataset.toml")) for n in names)
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
