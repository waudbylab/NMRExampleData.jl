# Release whatever has changed in datasets/ since the last release. The Release workflow
# runs this on every push to main that touches datasets/, so there is normally no need to
# run it yourself.
#
#     julia scripts/release.jl [--yes] [--dry-run]
#
# It finds the datasets changed since the last release, fetches their data from Git LFS,
# checks them, and packs each one whose data has changed, whole except for its dataset.toml.
# The packs go up to a new GitHub release, and Artifacts.toml is updated to point at them.
# The version in Project.toml is bumped and the two files are committed and pushed.
#
# The version is registered from a commit of its own on the branch `release`: this one
# without datasets/, whose Git LFS files the registry's `git archive` would expand, failing
# its tree check, and with Datasets.toml, the index of their dataset.toml files, in their
# place. Registrator is asked to register that commit, and TagBot then tags it.
#
# The version goes up by:
#   - major, when a dataset is removed or renamed without keeping its old name as an alias
#   - minor, when a dataset is added or its data changes
#   - patch, when only dataset.toml files change, since they ship with the package itself
# with 1.0.0 as the first release. A version not yet tagged by TagBot has not been
# registered, so it is released again rather than bumped: Registrator then updates the
# registration still waiting for it. With nothing to release, a version not yet registered
# is registered again, from the latest main.
#
# --yes skips the question before uploading. --dry-run says what would happen and stops.

include("check.jl")

using Dates
using Pkg.Artifacts
using SHA

const ARTIFACTS = joinpath(ROOT, "Artifacts.toml")
const PROJECT = joinpath(ROOT, "Project.toml")
const MESSAGE = "Release example data"

git(args...) = readchomp(Cmd(`git $args`; dir=ROOT))

# dataset.toml is read from the package itself, so it stays out of the packs and editing it
# needs no new upload
skip(f) = f == "dataset.toml"

# The commit of the last release, or nothing before the first.
function lastrelease()
    c = git("log", "-1", "--format=%H", "--grep=^$MESSAGE")
    return isempty(c) ? nothing : c
end

# Datasets with any file changed since commit `base`: all of them before the first release.
function changedsince(base)
    isnothing(base) && return examples()
    files = split(git("diff", "--name-only", base, "HEAD", "--", "datasets"), '\n';
        keepempty=false)
    names = unique(splitpath(f)[2] for f in files)
    return filter(in(names), examples())
end

# Fetch from Git LFS the data of the datasets that are only pointers in this clone.
function fetchdata(names)
    pointers = filter(n -> !NMRExampleData.hasdata(joinpath(DATASETS, n)), names)
    isempty(pointers) && return
    println("Fetching from Git LFS: ", join(pointers, ", "))
    git("lfs", "pull", "--include", join(("datasets/$n/**" for n in pointers), ","))
    return
end

# tags on GitHub, since `gh release create` makes the tag there and not in this clone
function newtag(repo)
    tags = split(readchomp(`gh release list --repo $repo --limit 1000 --json tagName -q '.[].tagName'`))
    base = "data-$(today())"
    tag, k = base, 1
    while tag in tags
        k += 1
        tag = "$base.$k"
    end
    return tag
end

function nextversion(current, uploads, stale, changed)
    names = Set(examples())
    for n in examples()
        union!(names, exampleinfo(n).aliases)
    end
    # a dataset's raw data were once packed separately, as <name>_fid
    removed = filter(n -> !(n in names), unique(replace.(stale, r"_fid$" => "")))
    bump = !isempty(removed) ? :major :
           !isempty(uploads) || !isempty(stale) ? :minor :
           !isempty(changed) ? :patch : nothing
    isnothing(bump) && return nothing, removed
    registered(current) || return current, removed
    current < v"1" && return v"1.0.0", removed
    v = bump == :major ? VersionNumber(current.major + 1, 0, 0) :
        bump == :minor ? VersionNumber(current.major, current.minor + 1, 0) :
        VersionNumber(current.major, current.minor, current.patch + 1)
    return v, removed
end

# The commit to register, made on the branch `release` from main's HEAD: see the top.
function releasecommit(version)
    index = tempname()
    tree = withenv("GIT_INDEX_FILE" => index) do
        git("read-tree", "HEAD")
        git("rm", "-r", "--cached", "--quiet", "datasets")
        blob = git("hash-object", "-w", NMRExampleData.writeindex(tempname()))
        git("update-index", "--add", "--cacheinfo", "100644,$blob,Datasets.toml")
        git("write-tree")
    end
    rm(index; force=true)
    # after the previous release commit, if any, and the main commit it is made from
    parents = ["-p", "HEAD"]
    if !isempty(git("ls-remote", "origin", "refs/heads/release"))
        git("fetch", "--quiet", "origin", "release")
        parents = ["-p", "FETCH_HEAD", parents...]
    end
    main = git("rev-parse", "--short", "HEAD")
    commit = git("commit-tree", tree, parents..., "-m",
        "NMRExampleData v$version, from $main without datasets/")
    git("push", "--quiet", "origin", "$commit:refs/heads/release")
    return commit
end

function register(repo, version)
    commit = releasecommit(version)
    run(pipeline(`gh api repos/$repo/commits/$commit/comments -f body="@JuliaRegistrator register"`;
        stdout=devnull))
    println("\nPushed $(commit[1:7]) to the branch release and asked Registrator to register " *
            "version $version.")
    return
end

# TagBot tags each version once it is registered
registered(v) = !isempty(git("tag", "--list", "v$v"))

function setversion!(v)
    toml = read(PROJECT, String)
    write(PROJECT, replace(toml, r"^version = \".*\"$"m => "version = \"$v\""))
    return
end

function main(args)
    yes, dry = "--yes" in args, "--dry-run" in args
    if !dry
        isempty(git("status", "--porcelain")) || error("commit or stash your changes first")
        git("fetch", "--quiet")
        git("rev-parse", "HEAD") == git("rev-parse", "@{upstream}") ||
            error("this clone is not up to date with GitHub: pull or push first")
    end

    changed = changedsince(lastrelease())
    println("Changed since the last release: ",
        isempty(changed) ? "nothing" : join(changed, ", "))
    fetchdata(changed)
    checkall(changed) || error("fix the problems above first")

    build = mktempdir()
    uploads = []
    for a in changed
        hash = create_artifact(d -> copytree(joinpath(DATASETS, a), d; skip))
        artifact_hash(a, ARTIFACTS) == hash && continue
        tarball = joinpath(build, "$a.tar.gz")
        archive_artifact(hash, tarball)
        push!(uploads, (; a, hash, tarball))
    end
    stale = collect(setdiff(keys(TOML.parsefile(ARTIFACTS)), examples()))

    current = VersionNumber(TOML.parsefile(PROJECT)["version"])
    version, removed = nextversion(current, uploads, stale, changed)
    if isnothing(version)
        registered(current) && (println("Nothing to release."); return)
        println("Nothing to release, but version $current is not yet registered: registering it again.")
        dry || register(readchomp(`gh repo view --json nameWithOwner -q .nameWithOwner`), current)
        return
    end

    total = sum((filesize(u.tarball) for u in uploads); init=0)
    println("\nRelease version $version", version == current ? " (not yet registered)" :
                                                      " (from $current)", ":")
    foreach(u -> println("  upload  $(u.a)  $(megabytes(filesize(u.tarball)))"), uploads)
    foreach(a -> println("  remove  $a"), stale)
    isempty(removed) || println("  no longer available: ", join(removed, ", "))
    isempty(uploads) && isempty(stale) && println("  metadata only: no upload")
    dry && return
    if !yes
        print("Go ahead? [y/N] ")
        lowercase(strip(readline())) == "y" || return
    end

    repo = readchomp(`gh repo view --json nameWithOwner -q .nameWithOwner`)
    if !isempty(uploads)
        tag = newtag(repo)
        run(`gh release create $tag --repo $repo --target $(git("rev-parse", "HEAD"))
             --title $tag --notes "Example data for version $version." $([u.tarball for u in uploads])`)
        for u in uploads
            url = "https://github.com/$repo/releases/download/$tag/$(u.a).tar.gz"
            sha = bytes2hex(open(sha256, u.tarball))
            bind_artifact!(ARTIFACTS, u.a, u.hash; download_info=[(url, sha)], lazy=true,
                force=true)
        end
    end
    foreach(a -> unbind_artifact!(ARTIFACTS, a), stale)
    setversion!(version)

    summary = isempty(changed) ? "" : ": " * join(changed, ", ")
    git("commit", "--quiet", "-m", "$MESSAGE v$version$summary", "--", "Artifacts.toml",
        "Project.toml")
    git("push", "--quiet")
    register(repo, version)
    return
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
