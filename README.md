# NMRExampleData.jl

Example NMR data for [NMRTools.jl](https://github.com/waudbylab/NMRTools.jl),
[NMRAnalysis.jl](https://github.com/waudbylab/NMRAnalysis.jl) and
[NMRScreen.jl](https://github.com/waudbylab/NMRScreen.jl).

Installing this package downloads no data. Each dataset is downloaded the first time you
use it, and only that one.

## Use a dataset

With [NMRTools](https://github.com/waudbylab/NMRTools.jl), load a dataset by name:

```julia
using NMRTools

spec = exampledata("hsqc_ubq")             # NMRData, downloading it if needed
fid = exampledata("hsqc_ubq"; fid=true)    # the raw time-domain data instead
spec = exampledata()                       # or choose one from a menu
```

A name can be shortened to the start of the full name, or of any part of it, as long as
only one dataset matches: `"hetnoe"` or `"calr"` finds `hetnoe2d_calr`.

A dataset with several experiments, such as a titration or a hetNOE pair, loads as a vector
of `NMRData`, in the order given by `spectrum` in its `dataset.toml`.

Each time `exampledata` loads a dataset, it shows who to credit, what to cite, and the
licence.

Without NMRTools, this package gives you the files:

```julia
using NMRExampleData

examples()                     # the names of every dataset
exampleinfo("hsqc_ubq")        # its title, credit, citation, licence and description
examplepath("hsqc_ubq")        # the experiment(s) to load, downloading if needed
examplepath("hsqc_ubq"; fid=true)  # the same, with the raw fid/ser files
exampledir("hsqc_ubq")         # the dataset's whole folder
```

`examplepath` is the experiment folder to load, or a vector of them for a series.
`exampledir` is the folder that holds the whole dataset: every experiment, the sample
record, and any `analysis/` folder.

## Add a dataset

You need [Git LFS](https://git-lfs.com) once: `brew install git-lfs`, then `git lfs install`.

1. Run `add.jl` with a name for the dataset and the experiment folders, where they are now.
   There is no need to copy anything first. For a series, give the experiments in the
   order they should load:

   ```
   julia scripts/add.jl hetnoe2d_calr ~/data/calr/11 ~/data/calr/12
   ```

   The script finds the sample record that NMRTools matches to each experiment, so a
   titration across several samples brings all of their records. It then asks for the
   metadata, suggesting what it can work out from the data:

   - the title, a part at a time, in the form
     `<protein> <dims> <nuclei> <experiment> (<field> MHz, <temperature> K)`, such as
     `CALR 2D 1H,15N hetNOE (600 MHz, 298 K)`. Dimensions, nuclei, field and
     temperature are detected for you to confirm. The field is the ¹H Larmor frequency
     rounded to 50 MHz, and a series spanning several temperatures gives a range.
   - a description
   - who to credit, one person at a time, as `Name <email>` or `Name`, starting with
     you from your git settings
   - a paper to cite
   - the licence: CC BY 4.0, None, or another
   - other names for the dataset

   Once every answer is in, it makes `datasets/hetnoe2d_calr/` and copies the experiments and
   sample records into it, and writes `dataset.toml`. Your original data is not changed.
   The copy leaves out TopSpin bookkeeping files and the imaginary parts of the processed
   data, but keeps the raw `fid` and `ser` files.

2. Optionally, edit `datasets/hetnoe2d_calr/dataset.toml` to change any of the answers.

3. Optionally, add an `analysis/` folder with the `peaklist.csv` or `regionlist.csv` and
   `results.csv` saved by NMRAnalysis.

4. Check it:

   ```
   julia scripts/check.jl hetnoe2d_calr
   ```

5. Commit and push to `main`. That is all: the release is automatic (see below).

You can use a dataset straight away from your own clone, before it is released. To change
a dataset, edit its folder, check it, and push in the same way.

### Contributing data

Fork the repository, add the dataset as above on a branch of your fork, push it with Git
LFS, and open a pull request. The Check data workflow fetches the datasets the pull
request changes, checks them, and shows the version that merging it would release.
Nothing is released until it is merged into `main`.

### Names

`<experiment>_<sample>`, in lowercase letters, digits and underscores:

- the experiment: the NMRAnalysis function the data demonstrates (`hetnoe2d`,
  `relaxation2d`, `titration2d`, `cest2d`), or else a standard name (`1h`, `19f`, `hsqc`,
  `hmqc`, `hnca`, `xste`)
- the sample: a short code for the protein or molecule (`ubq`, `calr`, `asyn`, `hewl`)
- a suffix, only to tell two datasets apart (`_308k`, `_pipe`)

For example `hetnoe2d_calr`, `relaxation2d_asyn`, `hsqc_ubq`. Old names can be kept as
aliases.

## Release

Releases are automatic. Every push to `main` that changes `datasets/` runs the Release
workflow, which runs `scripts/release.jl`. For the datasets changed since the last
release, it:

1. fetches their data from Git LFS and checks them, stopping if any check fails
2. packs those whose data has changed, uploads the packs to a GitHub release, and points
   `Artifacts.toml` at them
3. bumps the version in `Project.toml`, commits and pushes both files, and asks
   Registrator to register the new version. TagBot then tags it.

Users get the new data when they next update the package. Each version of the package
points at a fixed set of data, so results stay reproducible.

The version goes up by:

- **major**, when a dataset is removed or renamed without keeping its old name as an alias
- **minor**, when a dataset is added or its data changes
- **patch**, when only `dataset.toml` files change. They ship with the package, so no data
  is uploaded.

The first release is 1.0.0. Depend on it as `NMRExampleData = "1"` to get new data with
ordinary package updates.

If a release fails, fix the problem and push again, or re-run the workflow from the
Actions tab. To see what would be released, run `julia scripts/release.jl --dry-run`.
Changes to the code alone are not released automatically: register those by hand, as
for any package.

## Licence

Each dataset's licence is given by `licence` in its `dataset.toml`, usually CC BY 4.0. The
code is released under the [MIT licence](LICENSE).
