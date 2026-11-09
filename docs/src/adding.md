# Adding data

Each dataset is a folder in `datasets/`, holding the experiments and a `dataset.toml` that
describes them. Binary data are stored with [Git LFS](https://git-lfs.com); everything else is
plain git. Pushing a new dataset to `main` [releases](releases.md) it.

## Add a dataset

Before you start, install Git LFS once: `brew install git-lfs`, then `git lfs install`.

1. Run `scripts/add.jl` with the experiment folders, in the order they should load:

   ```
   julia scripts/add.jl ~/data/calr/11 ~/data/calr/12
   ```

   The script asks for the title, name, description, credit, citation and licence, suggesting
   what it can from the data. It then copies the experiments, and the sample records that
   NMRTools matches to them, into `datasets/<name>/`, and writes `dataset.toml`. Your original
   data are not changed.

2. Optional: edit `datasets/<name>/dataset.toml`. The comments in
   [`template/dataset.toml`](https://github.com/waudbylab/NMRExampleData.jl/blob/main/template/dataset.toml)
   describe each field.

3. Check the dataset:

   ```
   julia scripts/check.jl <name>
   ```

4. Commit and push to `main`.

You can use a dataset from your own clone before it is released. To change a dataset, edit its
folder, check it and push.

## Name a dataset

Use lowercase letters, digits and underscores:

- For data meant for an analysis, use the analysis function, then the sample:
  `hetnoe2d_calr`, `titration2d_fir_nbox`.
- For a plain spectrum, use the dimensions, the correlation and the sample: `1d_1h_ubq`,
  `2d_hn_ubq`. For a 3D, use the experiment: `3d_hnca_ubq`.
- Add any variant last: `2d_hc_ubq_methyl`.

A shortened name finds the first dataset added, so add the dataset you want `"2d_hn"` to find
before any others like it.

## Set what `example` returns

`path` in `dataset.toml` sets what `example(name)` returns, in the same shape:

- one experiment: `path = "1"`
- a series, in order: `path = ["1", "2", "3"]`
- data in groups, for an analysis that takes them that way:
  `path = [["10107", "10110"], ["10108", "10109"]]` gives `decay, buildup` for `ccr2d`
- a processed spectrum other than `pdata/1`: `path = "21/pdata/231"`

Give R1ρ data as a list even when there is one experiment: given a single path, `r1rho` offers
a menu of the experiments in it.

## Add other formats

To include the same data as nmrPipe or UCSF files, put them in the dataset and list them in a
`[formats]` table at the end of `dataset.toml`, each in the same shape as `path`:

```toml
path = "1"

[formats]
nmrpipe = "1/test.ft2"
ucsf = "1/hmqc.ucsf"
```

Keep `path` for the Bruker data. Say in the description how each format was processed, since
their intensities need not match. To keep the files small, process a narrow region.

## Save an analysis

To include an NMRAnalysis analysis, run it on the dataset's own copy of the data and save it to
the folder `analysis`:

```julia
cd("datasets/relaxation2d_asyn")
relaxation2d("pseudo3D_HN_R2")   # pick peaks, fit, then save to the folder analysis
```

`reopen(exampleanalysis(name))` then repeats the analysis wherever the dataset is downloaded.

## Add a screen

Add a screen by hand. Copy the folder holding its `experiment.toml`, with the fragment library
and the experiments it names, to `datasets/<name>/`. Write `dataset.toml` from the template,
with `path = "experiment.toml"` and `added` set to the time in UTC. To include the registration,
save it with the screen so that its `peaklist.csv` is in the output folder. Then check and push
the dataset as above.

## Contribute from a fork

Fork the repository, add the dataset on a branch, and open a pull request. The Check data
workflow checks the datasets the pull request changes, and shows the version that merging it
would release. Nothing is released until it is merged.
