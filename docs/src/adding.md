# Adding data

Datasets live in the [repository](https://github.com/waudbylab/NMRExampleData.jl), one folder
per dataset under `datasets/`, each with a `dataset.toml` describing it. The binary data go to
Git LFS; the parameter files, sample records, analysis results and `dataset.toml` stay in plain
git. Once a dataset is pushed to `main`, it is [released](releases.md) automatically.

## Add a dataset

You need [Git LFS](https://git-lfs.com) once: `brew install git-lfs`, then `git lfs install`.

1. Run `add.jl` with the experiment folders, where they are now. There is no need to copy
   anything first. For a series, give the experiments in the order they should load:

   ```
   julia scripts/add.jl ~/data/calr/11 ~/data/calr/12
   ```

   The script finds the sample record that NMRTools matches to each experiment, so a
   titration across several samples brings all of their records. It then asks for the
   metadata, suggesting what it can work out from the data:

   - the title, a part at a time, in the form
     `<protein> <dims> <nuclei> <experiment> (<field> MHz, <temperature> K)`, such as
     `CALR 2D 1H,15N hetNOE (600 MHz, 298 K)`. Dimensions, nuclei, field and
     temperature are detected for you to confirm. The field is the ¹H Larmor frequency
     rounded to 50 MHz, and a series spanning several temperatures gives a range.
   - the name for the dataset (see [Names](@ref))
   - a description
   - who to credit, one person at a time, as `Name <email>` or `Name`, starting with
     you from your git settings
   - a paper to cite
   - the licence: CC BY 4.0, None, or another
   - other names for the dataset

   Once every answer is in, it makes `datasets/<name>/`, copies the experiments and
   sample records into it, and writes `dataset.toml`. Your original data are not changed.
   The copy leaves out TopSpin bookkeeping files and the imaginary parts of the processed
   data, but keeps the raw `fid` and `ser` files.

2. Optionally, edit `datasets/<name>/dataset.toml` to change any of the answers. The comments
   in `template/dataset.toml` describe each field.

   `path` sets what `example(name)` returns, in the shape it returns it: one experiment, a
   list of them for a series, or nested lists where an analysis takes its data in roles, so
   that `iso, aln = example(name)` unpacks into `rdc2d(iso, aln)`. Give `r1rho` data as a
   list even when there is one experiment: given a single path, `r1rho` offers a menu of
   the experiments in it.

   Where the dataset holds the same experiment in other formats as well, such as nmrPipe or
   UCSF spectra processed from it, list them in a `formats` table at the end of
   `dataset.toml`, each given as `path` is, so that `example(name, :nmrpipe)` finds them:

   ```toml
   path = "1"

   [formats]
   nmrpipe = "1/test.ft2"
   ucsf = "1/hmqc.ucsf"
   ```

   `path` gives the Bruker data wherever there are any. Say in the description how each
   format was processed, since their intensities need not agree. Keep the files small:
   process the other formats over a narrow region where that will do.

3. Optionally, save an analysis with it. Run the analysis on the dataset's own copy of the
   data, from the dataset's folder, and save it to the output folder `analysis`:

   ```julia
   cd("datasets/relaxation2d_ubq")
   relaxation2d("1")              # pick the peaks, fit, and save to "analysis"
   ```

   The saved folder records the analysis with paths relative to itself, so that
   `reopen(exampleanalysis(name))` repeats it wherever the dataset is downloaded.

4. Check it:

   ```
   julia scripts/check.jl <name>
   ```

5. Commit and push to `main`. That is all: the [release](releases.md) is automatic.

You can use a dataset straight away from your own clone, before it is released. To change
a dataset, edit its folder, check it, and push in the same way.

## Add a screen

A screen is added by hand, since NMRScreen describes it in a file of its own. Copy the folder
holding its `experiment.toml`, with the fragment library and the experiments that file names,
to `datasets/<name>/`. Write `dataset.toml` from `template/dataset.toml`, with
`path = "experiment.toml"` and `added` set to the time in UTC. Then check and push it as
above. To include the registration, save it with the screen, so that its `peaklist.csv` is in
the output folder.

## Contributing data

Fork the repository, add the dataset as above on a branch of your fork, push it with Git
LFS, and open a pull request. The Check data workflow fetches the datasets the pull
request changes, checks them, and shows the version that merging it would release.
Nothing is released until it is merged into `main`.

## Names

Name a dataset for what someone would use it for, then the sample, in lowercase letters,
digits and underscores:

- **Data for an analysis:** `<analysis function>_<sample>`, after the NMRAnalysis or
  NMRScreen function it is for, such as `hetnoe2d_calr` or `relaxation2d_ubq`.
- **A plain spectrum**, for loading, processing and plotting:
  `<dims>_<correlation>_<sample>`, such as `1d_1h_ubq`, `1d_19f_sh3`, `2d_hn_ubq` or
  `2d_hc_ubq`. For a 3D, use the experiment: `3d_hnca_ubq`. The pulse sequence (HSQC,
  HMQC, TROSY) is in the title, not the name.
- **A variant** goes last, saying how it differs: `relaxation2d_ubq_r1`,
  `2d_hc_ubq_methyl`, `3d_hnca_ubq_pipe`.

Because a shortened name finds the first dataset added, add the dataset you would want
`"2d_hn"` or `"hetnoe"` to find before any others like it.

A dataset that replaces one of the example datasets of earlier NMRTools versions keeps the
old name as an alias, such as `2D_HN` for `2d_hn_ubq` or `pseudo3D_HN_R2` for
`relaxation2d_ubq`. An alias matches exactly, so NMRTools' documentation, tests and users'
code go on finding the same data however many datasets are added.
