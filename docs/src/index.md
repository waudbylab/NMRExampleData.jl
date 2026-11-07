# NMRExampleData.jl

Example NMR data for [NMRTools.jl](https://waudbylab.org/NMRTools.jl/stable/),
[NMRAnalysis.jl](https://waudbylab.org/NMRAnalysis.jl/stable/) and
[NMRScreen.jl](https://waudbylab.org/NMRScreen.jl/stable/): real spectra, with their raw data,
sample records and analyses, for tutorials, documentation and tests. The
[Catalogue](@ref) lists every dataset.

Installing the package downloads no data. Each dataset is downloaded the first time you use it,
and only that one.

## Using the data with NMRTools

NMRTools (version 0.3.2 or later) loads a dataset by name:

```julia
using NMRTools

spec = exampledata("titration2d_fir_nbox")              # NMRData, or a vector of them for a series
fid = exampledata("titration2d_fir_nbox"; fid=true)     # the raw time-domain data instead
path = exampledata("titration2d_fir_nbox"; path=true)   # where it is, without loading it
spec = exampledata()                                    # or choose one from a menu
```

The first time a dataset is used in a session, NMRTools shows who to credit, what to cite, and
the licence. `exampleinfo` gives the same information at any time.

Names ignore case, and can be shortened to the start of the full name or of any part of it:
`"titration2d"` and `"fir"` both find `titration2d_fir_nbox`. Where a shortened name matches
several datasets, the one added first is used, so it keeps meaning the same dataset as more are
added. In code that others will run, give the full name.

A dataset with several experiments, such as a titration or a relaxation series, loads as a
vector of spectra in a fixed order.

## Using the data without NMRTools

The package itself gives you the files, to load however you like:

```julia
using NMRExampleData

examples()                                   # the names of every dataset
exampleinfo("titration2d_fir_nbox")          # title, credit, citation, licence and description
examplepath("titration2d_fir_nbox")          # the experiment(s) to load, downloading if needed
examplepath("titration2d_fir_nbox"; fid=true)  # the same, with the raw fid and ser files
exampledir("titration2d_fir_nbox")           # the dataset's whole folder
```

`examplepath` is the experiment folder to load, or a vector of them for a series. `exampledir`
is the folder holding the whole dataset: every experiment, the sample records, and any
`analysis/` folder of NMRAnalysis results.

## Versions

Each version of the package points at a fixed set of data, so results stay reproducible. Adding
a dataset or changing its data increases the minor version, and removing or renaming one
without keeping the old name as an alias increases the major version. Depend on it as
`NMRExampleData = "1"` to get new data with ordinary package updates.

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
