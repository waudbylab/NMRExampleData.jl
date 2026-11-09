# Releases

Releases are automatic. Every push to `main` that changes `datasets/` runs the Release
workflow, which runs `scripts/release.jl`. For the datasets changed since the last
release, it:

1. fetches their data from Git LFS and checks them, stopping if any check fails
2. packs those whose data have changed, uploads the packs to a GitHub release, and points
   `Artifacts.toml` at them
3. bumps the version in `Project.toml`, and commits and pushes both files
4. makes the commit to register on the branch `release`, and asks Registrator to register
   it. TagBot then tags it.

Each dataset is packed whole, raw data included, and downloaded the first time it is used.
`dataset.toml` is not packed: it ships with the package itself.

## What is registered

The registered package holds no datasets. The registry archives each registered commit
with `git archive`, which expands Git LFS files, so a commit holding `datasets/` fails its
check that the archive matches the commit. The commit registered is instead `main`
without `datasets/`, with `Datasets.toml`, the index of every `dataset.toml`, in its
place, on a branch `release` of its own. The package reads the index where there is no
`datasets/` folder, and `datasets/` in a clone of `main`. Everything else stays on `main`:
work there as usual, and leave `release` to the workflow.

After a release, the workflow rebuilds this documentation, so the [Catalogue](@ref) shows the
new data.

## Versions

Users get the new data when they next update the package. Each version of the package
points at a fixed set of data, so results stay reproducible.

The version goes up by:

- **major**, when a dataset is removed or renamed without keeping its old name as an alias
- **minor**, when a dataset is added or its data change
- **patch**, when only `dataset.toml` files change. They ship with the package, so no data
  are uploaded.

A version is registered once TagBot has tagged it. Until then, a release keeps the same version
and updates the registration still waiting, rather than adding another version behind it.

The first release is 1.0.0. Depend on the package as `NMRExampleData = "1"` to get new data
with ordinary package updates.

## When something goes wrong

If a release fails, fix the problem and push again, or re-run the workflow from the
Actions tab. To see what would be released, run `julia scripts/release.jl --dry-run`.
Changes to the code alone are not released automatically. To release one, bump the
version in `Project.toml` on `main`, then run the Release workflow from the Actions tab:
with no data to release, it registers the version from `release`. Do not ask Registrator
to register a commit on `main`: it holds `datasets/`, and fails the registry's checks.
