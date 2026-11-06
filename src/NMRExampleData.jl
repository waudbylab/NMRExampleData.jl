"""
Example NMR data shared by NMRTools.jl, NMRAnalysis.jl and NMRScreen.jl.

Each example is a folder under `datasets/` with a `dataset.toml`. Released examples are
downloaded the first time they are used, and only then.
"""
module NMRExampleData

using Artifacts
using LazyArtifacts
using TOML

export examples, exampleinfo, exampledir, examplepath

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
 "relaxation2d_asyn"
 "tract_ubq"
```
"""
function examples()
    isdir(DATASETS) || return String[]
    return filter(n -> isfile(joinpath(DATASETS, n, "dataset.toml")), readdir(DATASETS))
end

"""
    exampleinfo(name) -> NamedTuple

The description of an example dataset, from its `dataset.toml`: `name`, `title`,
`spectrum`, `description`, `credit` (a vector of `"Name <email>"` or `"Name"`), `citation`,
`licence`, `source` and `aliases`. Nothing is downloaded.

`name` may be the dataset's full name, an alias, or the start of the name or of any part of
it between underscores, provided that matches only one dataset: `"hetnoe"` finds
`"hetnoe2d_calr"`. The full name is returned as `name`.

# Example
```julia
julia> exampleinfo("hetnoe").title
"CALR 2D 1H,15N hetNOE (600 MHz, 298 K)"
```
"""
function exampleinfo(name::AbstractString)
    n = resolvename(name)
    d = TOML.parsefile(joinpath(DATASETS, n, "dataset.toml"))
    credit = get(d, "credit", String[])
    return (; name=n, title=get(d, "title", ""),
        spectrum=get(d, "spectrum", ""), description=get(d, "description", ""),
        credit=credit isa AbstractString ? [credit] : credit, citation=get(d, "citation", ""),
        licence=get(d, "licence", ""),
        source=get(d, "source", ""), aliases=get(d, "aliases", String[]))
end

"""
    exampledir(name; fid=false) -> String

The folder holding the whole of an example dataset: every experiment in it, any sample
record, and any `analysis/` folder. Downloads the dataset the first time it is used.

The download leaves out the raw time-domain data (`fid` and `ser` files) unless
`fid=true`. In a clone of this repository with the data fetched from Git LFS, the dataset's
own folder is used instead and nothing is downloaded.

# Example
```julia
julia> dir = exampledir("hetnoe2d_calr")
julia> readdir(dir)
```
"""
function exampledir(name::AbstractString; fid::Bool=false)
    n = resolvename(name)
    here = joinpath(DATASETS, n)
    hasdata(here) && return here
    a = fid && released(n * "_fid") ? n * "_fid" : n
    released(a) ||
        error("example dataset \"$n\" has not been released yet. In a clone of " *
            "NMRExampleData.jl, run `git lfs pull` to use it from the repository")
    return @artifact_str(a)
end

"""
    examplepath(name; fid=false) -> String or Vector{String}

The path of the experiment to load from an example dataset, as given by `spectrum` in its
`dataset.toml`. Where `spectrum` lists several experiments (a titration, a hetNOE pair, a
relaxation series) this is a vector of paths in that order. Where `spectrum` is empty, the
dataset's folder. Downloads the dataset the first time it is used; see
[`exampledir`](@ref).

# Example
```julia
julia> using NMRTools
julia> spec = loadnmr.(examplepath("relaxation2d_asyn"))
```
"""
function examplepath(name::AbstractString; fid::Bool=false)
    info = exampleinfo(name)
    dir = exampledir(info.name; fid)
    s = info.spectrum
    return s isa AbstractVector ? [joinpath(dir, p) for p in s] : joinpath(dir, s)
end

# The dataset a name refers to: its full name or an alias, or else the one dataset whose
# name, or a part of it between underscores, starts with the name given, so that "hetnoe"
# finds "hetnoe2d_calr".
function resolvename(name::AbstractString)
    names = examples()
    name in names && return String(name)
    for n in names
        d = TOML.parsefile(joinpath(DATASETS, n, "dataset.toml"))
        name in get(d, "aliases", String[]) && return n
    end
    q = lowercase(name)
    found = filter(n -> startswith(n, q) || any(p -> startswith(p, q), split(n, '_')), names)
    length(found) == 1 && return only(found)
    isempty(found) && throw(ArgumentError("no example dataset called \"$name\". " *
        "Available: $(join(names, ", "))"))
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
