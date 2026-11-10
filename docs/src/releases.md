# Releases

Releases are automatic. When a push to `main` changes `datasets/`, the Release workflow runs
`scripts/release.jl`, which:

1. checks the datasets that have changed since the last release
2. packs each one whose data have changed, uploads it to a GitHub release, and points
   `Artifacts.toml` at it
3. sets the new version in `Project.toml`, and commits and pushes both files
4. registers the new version, from a commit on the branch `release`
5. rebuilds this documentation

Once the registry has merged the new version, TagBot tags it, and its documentation is built
as the stable version.

Each dataset is downloaded whole, raw data included, the first time it is used.

## Versions

Each version of the package points at a fixed set of data, so results stay reproducible.
Depend on the package as `NMRExampleData = "1"` to get new data with ordinary updates.

The version goes up by:

- **major**, when a dataset is removed, or renamed without keeping its old name as an alias
- **minor**, when a dataset is added or its data change
- **patch**, when only `dataset.toml` files change

Until a version is registered, later releases keep its number and update the registration
that is waiting.

## The `release` branch

The registered package holds no datasets. The registry checks each package by archiving it
with `git archive`, which expands Git LFS files, so a commit holding `datasets/` fails. The
commit registered is `main` without `datasets/`, with `Datasets.toml` in its place: an index of
every `dataset.toml`, which the package reads when there is no `datasets/` folder.

Work on `main` as usual, and leave `release` to the workflow. Never ask Registrator to register
a commit on `main`.

## Release a change to the code

Changes to the code alone are not released automatically. To release one, raise the version in
`Project.toml` on `main`, then run the Release workflow from the Actions tab.

## If a release fails

Fix the problem and push again, or run the workflow again from the Actions tab. To see what
would be released, run:

```
julia scripts/release.jl --dry-run
```
