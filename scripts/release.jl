# Release whatever has changed in datasets/ since the last release. The Release workflow
# runs this on every push to main that touches datasets/, so there is normally no need to
# run it yourself.
#
#     julia scripts/release.jl [--yes] [--dry-run]
#
# It finds the datasets changed since the last release, fetches their data from Git LFS,
# checks them, and packs each one whose data has changed: `<name>` without the raw data, and
# `<name>_fid` complete (a dataset without raw data is packed once). The packs go up to a
# new GitHub release, and Artifacts.toml is updated to point at them. The version in
# Project.toml is bumped, the two files are committed and pushed, and Registrator is asked
# to register the new version. TagBot then tags it.
#
# The version goes up by:
#   - major, when a dataset is removed or renamed without keeping its old name as an alias
#   - minor, when a dataset is added or its data changes
#   - patch, when only dataset.toml files change, since they ship with the package itself
# with 1.0.0 as the first release.
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
nometa(f) = f == "dataset.toml"

# (pack name, files to leave out)
function packs(name)
    nofid = f -> nometa(f) || israw(f)
    hasraw(joinpath(DATASETS, name)) || return [(name, nofid)]
    return [(name, nofid), (name * "_fid", nometa)]
end

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
    removed = filter(n -> !(n in names), unique(replace.(stale, r"_fid$" => "")))
    bump = !isempty(removed) ? :major :
           !isempty(uploads) || !isempty(stale) ? :minor :
           !isempty(changed) ? :patch : nothing
    isnothing(bump) && return nothing, removed
    current < v"1" && return v"1.0.0", removed
    v = bump == :major ? VersionNumber(current.major + 1, 0, 0) :
        bump == :minor ? VersionNumber(current.major, current.minor + 1, 0) :
        VersionNumber(current.major, current.minor, current.patch + 1)
    return v, removed
end

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
    for name in changed, (a, skip) in packs(name)
        hash = create_artifact(d -> copytree(joinpath(DATASETS, name), d; skip))
        artifact_hash(a, ARTIFACTS) == hash && continue
        tarball = joinpath(build, "$a.tar.gz")
        archive_artifact(hash, tarball)
        push!(uploads, (; a, hash, tarball))
    end
    stale = collect(setdiff(keys(TOML.parsefile(ARTIFACTS)),
        [a for n in examples() for (a, _) in packs(n)]))

    current = VersionNumber(TOML.parsefile(PROJECT)["version"])
    version, removed = nextversion(current, uploads, stale, changed)
    if isnothing(version)
        println("Nothing to release.")
        return
    end

    total = sum((filesize(u.tarball) for u in uploads); init=0)
    println("\nRelease version $version (from $current):")
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
    commit = git("rev-parse", "HEAD")
    run(pipeline(`gh api repos/$repo/commits/$commit/comments -f body="@JuliaRegistrator register"`;
        stdout=devnull))
    println("\nPushed $(commit[1:7]) and asked Registrator to register version $version.")
    return
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
