# NMRExampleData.jl

[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://waudbylab.org/NMRExampleData.jl/stable/)

Example NMR datasets for [NMRTools.jl](https://github.com/waudbylab/NMRTools.jl),
[NMRAnalysis.jl](https://github.com/waudbylab/NMRAnalysis.jl) and
[NMRScreen.jl](https://github.com/waudbylab/NMRScreen.jl). Each dataset is downloaded the first
time you use it.

```julia
using NMRTools
spec = loadnmr(example("2d_hn_ubq"))
```

See the [documentation](https://waudbylab.org/NMRExampleData.jl/stable/) for the
[catalogue](https://waudbylab.org/NMRExampleData.jl/stable/catalogue/) of datasets and how to
[add your own](https://waudbylab.org/NMRExampleData.jl/stable/adding/).

Each dataset's licence is given in the catalogue. The code is released under the
[MIT licence](LICENSE).
