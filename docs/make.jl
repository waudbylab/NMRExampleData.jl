# Build the documentation:
#
#     julia --project=docs docs/make.jl
#
# The catalogue is written from each dataset's dataset.toml and parameter files, so no data
# are downloaded and a clone without Git LFS is enough.

using Documenter
using NMRExampleData
using NMRTools

include("catalogue.jl")

# the catalogue is generated, and ignored by git
write(joinpath(@__DIR__, "src", "catalogue.md"), cataloguepage())

makedocs(;
         modules=[NMRExampleData],
         format=Documenter.HTML(; prettyurls=(get(ENV, "CI", nothing) == "true"),
                                canonical="https://waudbylab.org/NMRExampleData.jl/stable/"),
         pages=["Home" => "index.md",
                "Catalogue" => "catalogue.md",
                "Adding data" => "adding.md",
                "Releases" => "releases.md",
                "API" => "api.md"],
         sitename="NMRExampleData.jl",
         authors="Chris Waudby",
         checkdocs=:exports)

deploydocs(;
           repo="github.com/waudbylab/NMRExampleData.jl.git",
           devbranch="main")
