# Shared by add.jl, check.jl and release.jl.

using Pkg: Pkg
Pkg.activate(@__DIR__; io=devnull)
# resolve, not just instantiate, so that the manifest follows changes to NMRExampleData's own
# dependencies (instantiate does not look at a package developed from a path)
Pkg.resolve(; io=devnull)
Pkg.instantiate(; io=devnull)

using NMRExampleData
using NMRTools
using TOML

const ROOT = dirname(@__DIR__)
const DATASETS = joinpath(ROOT, "datasets")
const TEMPLATE = joinpath(ROOT, "template", "dataset.toml")

israw(f) = f == "fid" || f == "ser"

# One entry of `credit`: "Name <email>" or "Name".
const PERSON = r"^[^<>,]+?( <[^<>\s@]+@[^<>\s]+>)?$"

# <protein> <dims> <nuclei> <experiment> (<field> MHz, <temperature> K)
const TITLE = r"^\S+ (pseudo-)?\dD \S+ .+ \(\d+(-\d+)? MHz, \d+(-\d+)? K\)$"

# Copy the folder `src` to `dst`, leaving out every file for which `skip(name)` is true.
function copytree(src, dst; skip=f -> false)
    for (root, _, files) in walkdir(src), f in files
        skip(f) && continue
        to = joinpath(dst, relpath(root, src), f)
        mkpath(dirname(to))
        cp(joinpath(root, f), to)
    end
end

function foldersize(dir; skip=f -> false)
    return sum((filesize(joinpath(r, f)) for (r, _, fs) in walkdir(dir)
                for f in fs if !skip(f));
               init=0)
end

megabytes(bytes) = string(round(bytes / 1e6; digits=1), " MB")

hasraw(dir) = any(any(israw, fs) for (_, _, fs) in walkdir(dir))

# Bruker experiment folders inside `dir`, at any depth.
experiments(dir) = [r for (r, _, fs) in walkdir(dir) if "acqus" in fs]
