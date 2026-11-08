# NMRExampleData.jl

Example NMR data for [NMRTools.jl](https://waudbylab.org/NMRTools.jl/stable/),
[NMRAnalysis.jl](https://waudbylab.org/NMRAnalysis.jl/stable/) and
[NMRScreen.jl](https://waudbylab.org/NMRScreen.jl/stable/): real spectra, with their raw data,
sample records and analyses, for tutorials, documentation and tests. The
[Catalogue](@ref) lists every dataset.

Installing the package downloads no data. Each dataset is downloaded the first time you use it,
and only that one.

## Opening a dataset

`example(name)` gives what a dataset is opened with, downloading it the first time: a spectrum,
a vector of them for a series, or the `experiment.toml` of a screen. You open it with the
package it is for:

```julia
using NMRTools

spec = loadnmr(example("titration2d_fir_nbox"))   # NMRData, or a vector of them for a series
fid = loadfid(example("titration2d_fir_nbox"))    # the raw data
example()                                         # choose a dataset from a menu
```

With NMRAnalysis, start an analysis from a dataset's spectra, or reopen the analysis saved
with it, with its peaks picked and its parameters set:

```julia
using NMRAnalysis

expt = relaxation2d(example("relaxation2d_ubq"))     # from the start
expt = reopen(exampleanalysis("relaxation2d_ubq"))   # as saved, ready to refit
```

Where an analysis takes its data in roles, `example` returns them in that order, to unpack:

```julia
reference, saturated = example("hetnoe2d_calr")
expt = hetnoe2d(reference, saturated)
```

With NMRScreen, a screen opens from its `experiment.toml`:

```julia
using NMRScreen

screen(example("screen_bsa"))
```

The first time a dataset is used in a session, who to credit, what to cite and the licence are
shown. `exampleinfo` gives the same information at any time, and `examples()` lists every
dataset.

## Names

Names ignore case, and can be shortened to the start of the full name or of any part of it:
`"titration2d"` and `"fir"` both find `titration2d_fir_nbox`. Where a shortened name matches
several datasets, the one added first is used, so it keeps meaning the same dataset as more are
added. In code that others will run, give the full name.

## Versions

Each version of the package points at a fixed set of data, so results stay reproducible.
Depend on it as `NMRExampleData = "1"` to get new data with ordinary package updates; see
[Releases](@ref) for how versions are numbered.

## Credit and licences

Each dataset gives who to credit, a paper to cite where there is one, and the licence it is
shared under, usually [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). A licence of
"None" means that no licence has been granted: ask the people credited before using those data
beyond trying out the software. The code is released under the MIT licence.

To share your own data, see [Adding data](@ref).

## The ecosystem

- [NMRTools.jl](https://waudbylab.org/NMRTools.jl/stable/): loading, processing, plotting and
  peak picking of NMR data, with pulse programme annotations and sample records.
- [NMRAnalysis.jl](https://waudbylab.org/NMRAnalysis.jl/stable/): interactive analysis of
  relaxation, titration, diffusion and other series of spectra.
- [NMRScreen.jl](https://waudbylab.org/NMRScreen.jl/stable/): analysis of NMR screens.
- [MulticomplexNumbers.jl](https://github.com/waudbylab/MulticomplexNumbers.jl): the algebra
  NMRTools uses for multidimensional quadrature data.
- [The Waudby lab](https://waudbylab.org) at the UCL School of Pharmacy.
