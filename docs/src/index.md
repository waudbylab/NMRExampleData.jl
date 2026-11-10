# NMRExampleData.jl

Example NMR datasets for [NMRTools.jl](https://waudbylab.org/NMRTools.jl/stable/),
[NMRAnalysis.jl](https://waudbylab.org/NMRAnalysis.jl/stable/) and
[NMRScreen.jl](https://waudbylab.org/NMRScreen.jl/stable/). Each dataset is downloaded the first
time you use it. The [Catalogue](@ref) lists them all.

## Load a dataset

[`example`](@ref) returns the path of a dataset. Pass it to the function you would use for your
own data:

```julia
using NMRTools

spec = loadnmr(example("2d_hn_ubq"))
fid = loadfid(example("2d_hn_ubq"))
```

A series returns a vector of paths, so `loadnmr(example("titration2d_fir_nbox"))` gives a vector
of spectra. Where an analysis takes its data in groups, unpack them in the order the analysis
takes them:

```julia
using NMRAnalysis

decay, buildup = example("ccr2d_calr")
ccr2d(decay, buildup; T=0.04)
```

NMRTools, NMRAnalysis and NMRScreen export these functions, so you don't need to load
NMRExampleData yourself.

## Find a dataset

Call `example()` to choose a dataset from a menu, or `examples()` to list their names.
[`exampleinfo`](@ref) describes a dataset without downloading it.

You can shorten a name to the start of any part of it: `"hetnoe"` finds `hetnoe2d_calr`. If a
shortened name matches several datasets, you get the one added first. Use full names in code
that other people will run.

## Use other formats

Some datasets also hold their data as nmrPipe or UCSF (Sparky) files. Ask for a format by name:

```julia
loadnmr(example("2d_hn_ubq", :nmrpipe))
examples(:ucsf)                      # the datasets with UCSF data
```

## Credit and licences

The first time you use a dataset in a session, its credit, citation and licence are shown.
Most datasets are shared under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). A
licence of "None" means none has been granted: ask the people credited before you use those
data for anything beyond trying out the software.

To share your own data, see [Adding data](@ref).
