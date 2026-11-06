using NMRExampleData
using NMRExampleData: DATASETS, ARTIFACTS, hasdata
using Test
using TOML

# A throwaway dataset written into datasets/ for the duration of the tests.
function withdataset(f, name; toml, files)
    dir = joinpath(DATASETS, name)
    ispath(dir) && error("datasets/$name already exists")
    try
        mkpath(dir)
        write(joinpath(dir, "dataset.toml"), toml)
        for (path, content) in files
            mkpath(dirname(joinpath(dir, path)))
            write(joinpath(dir, path), content)
        end
        f(dir)
    finally
        rm(dir; recursive=true, force=true)
    end
end

const POINTER = """
                version https://git-lfs.github.com/spec/v1
                oid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393
                size 12345
                """

@testset "NMRExampleData" begin
    @testset "Every artifact is lazy" begin
        # a non-lazy artifact would be downloaded by everyone who installs NMRTools
        for (name, entry) in TOML.parsefile(ARTIFACTS)
            @test get(entry, "lazy", false) == true
        end
    end

    @testset "Every dataset.toml has a title" begin
        for n in examples()
            @test !isempty(exampleinfo(n).title)
        end
    end

    @testset "A dataset in the repository" begin
        toml = """
               title = "A test series"
               spectrum = ["1", "2"]
               credit = ["A. Tester <a.tester@example.com>", "B. Tester"]
               citation = "Tester et al. (2026)"
               licence = "CC BY 4.0"
               aliases = ["zztestalias"]
               """
        withdataset("zztest"; toml, files=["1/acqus" => "a", "2/acqus" => "b"]) do dir
            @test "zztest" in examples()
            info = exampleinfo("zztest")
            @test info.title == "A test series"
            @test exampleinfo("zztestalias").name == "zztest"
            @test info.credit == ["A. Tester <a.tester@example.com>", "B. Tester"]
            @test info.citation == "Tester et al. (2026)"
            @test info.licence == "CC BY 4.0"
            @test exampledir("zztest") == dir
            @test examplepath("zztest") == [joinpath(dir, "1"), joinpath(dir, "2")]
            @test examplepath("zztest"; fid=true) == examplepath("zztest")
        end
    end

    @testset "A whole-folder dataset" begin
        toml = """
               title = "A folder"
               """
        withdataset("zztest"; toml, files=["1/acqus" => "a"]) do dir
            @test examplepath("zztest") == joinpath(dir, "")
        end
    end

    @testset "LFS pointers instead of data" begin
        toml = """
               title = "Not fetched"
               spectrum = "1"
               """
        withdataset("zztest"; toml, files=["1/acqus" => "a", "1/fid" => POINTER]) do dir
            @test !hasdata(dir)
            @test_throws ErrorException exampledir("zztest")
        end
    end

    @testset "Partial names" begin
        toml = """
               title = "A"
               """
        withdataset("zzhetnoe2d_zzcalr"; toml, files=["1/acqus" => "a"]) do _
            @test exampleinfo("zzhetnoe2d_zzcalr").name == "zzhetnoe2d_zzcalr"
            @test exampleinfo("zzhetnoe").name == "zzhetnoe2d_zzcalr"
            @test exampleinfo("ZZHetNOE2d").name == "zzhetnoe2d_zzcalr"
            @test exampleinfo("zzcalr").name == "zzhetnoe2d_zzcalr"
            @test exampleinfo("zzhetnoe2d_zz").name == "zzhetnoe2d_zzcalr"
            @test_throws ArgumentError exampleinfo("zzcal_")
            withdataset("zzhetnoe2d_zzasyn"; toml, files=["1/acqus" => "a"]) do _
                err = try
                    exampleinfo("zzhetnoe")
                catch e
                    e
                end
                @test err isa ArgumentError
                @test occursin("could be any of", err.msg)
                @test exampleinfo("zzcalr").name == "zzhetnoe2d_zzcalr"
            end
        end
    end

    @testset "Unknown names" begin
        @test_throws ArgumentError exampleinfo("no_such_dataset")
        @test_throws ArgumentError examplepath("no_such_dataset")
    end
end
