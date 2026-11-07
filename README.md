# NMRExampleData.jl

[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://waudbylab.org/NMRExampleData.jl/stable/)

Example NMR data for [NMRTools.jl](https://github.com/waudbylab/NMRTools.jl),
[NMRAnalysis.jl](https://github.com/waudbylab/NMRAnalysis.jl) and
[NMRScreen.jl](https://github.com/waudbylab/NMRScreen.jl). Each dataset is downloaded the
first time it is used.

```julia
using NMRTools
spec = exampledata("titration2d_fir_nbox")
```

The [documentation](https://waudbylab.org/NMRExampleData.jl/stable/) has the
[catalogue](https://waudbylab.org/NMRExampleData.jl/stable/catalogue/) of datasets, and
explains how to use them, [add data](https://waudbylab.org/NMRExampleData.jl/stable/adding/)
and how releases work.

Each dataset's licence is given in its `dataset.toml`. The code is released under the
[MIT licence](LICENSE).
