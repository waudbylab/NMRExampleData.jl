using NMRExampleData
using NMRExampleData: DATASETS, ARTIFACTS, CREDITED, hasdata, catalogue, writeindex
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
               path = ["1", "2"]
               credit = ["A. Tester <a.tester@example.com>", "B. Tester"]
               citation = "Tester et al. (2026)"
               licence = "CC BY 4.0"
               aliases = ["zztestalias"]
               """
        withdataset("zztest"; toml, files=["1/acqus" => "a", "2/acqus" => "b"]) do dir
            @test "zztest" in examples()
            info = exampleinfo("zztest")
            @test info.title == "A test series"
            @test info.path == ["1", "2"]
            @test exampleinfo("zztestalias").name == "zztest"
            @test info.credit == ["A. Tester <a.tester@example.com>", "B. Tester"]
            @test info.citation == "Tester et al. (2026)"
            @test info.licence == "CC BY 4.0"
            @test example("zztest") == [joinpath(dir, "1"), joinpath(dir, "2")]
            @test_throws ArgumentError exampleanalysis("zztest")
        end
    end

    @testset "Shapes of path" begin
        withdataset("zztest"; toml="title = \"A folder\"", files=["1/acqus" => "a"]) do dir
            @test example("zztest") == joinpath(dir, "")
        end
        toml = """
               title = "Pairs"
               path = [["1", "2"], ["3", "4"]]
               """
        files = ["$i/acqus" => "a" for i in 1:4]
        withdataset("zztest"; toml, files) do dir
            iso, aln = example("zztest")
            @test iso == [joinpath(dir, "1"), joinpath(dir, "2")]
            @test aln == [joinpath(dir, "3"), joinpath(dir, "4")]
        end
        toml = """
               title = "A screen"
               path = "experiment.toml"
               """
        withdataset("zztest"; toml, files=["experiment.toml" => "[setup]"]) do dir
            @test example("zztest") == joinpath(dir, "experiment.toml")
        end
    end

    @testset "Formats" begin
        format = NMRExampleData.format
        @test format("1") == :bruker
        @test format("1/pdata/1") == :bruker
        @test format("1/test.ft2") == :nmrpipe
        @test format("smile/test%03d.ft3") == :nmrpipe
        @test format("hnca.ucsf") == :ucsf
        @test format("bmr17769_3.str") == :bmrb
        @test format("experiment.toml") == :screen
        @test format(["1/test.ft2", "2/test.ft2"]) == :nmrpipe

        toml = """
               title = "Several formats"
               path = "1"

               [formats]
               ucsf = "1/hmqc.ucsf"
               nmrpipe = "1/test.ft2"
               """
        files = ["1/acqus" => "a", "1/test.ft2" => "b", "1/hmqc.ucsf" => "c"]
        withdataset("zztest"; toml, files) do dir
            # the default first, then the others in a fixed order
            info = exampleinfo("zztest")
            @test info.formats == (bruker="1", nmrpipe="1/test.ft2", ucsf="1/hmqc.ucsf")
            @test example("zztest") == joinpath(dir, "1")
            @test example("zztest", :nmrpipe) == joinpath(dir, "1", "test.ft2")
            @test example("zztest", :ucsf) == joinpath(dir, "1", "hmqc.ucsf")
            @test_throws ArgumentError example("zztest", :bmrb)
            @test "zztest" in examples(:ucsf)
            @test "zztest" in examples(:bruker)
            @test !("zztest" in examples(:screen))
        end
        # a dataset in one format needs no table
        withdataset("zztest"; toml="title = \"Pipe\"\npath = \"1/test.ft2\"",
                    files=["1/test.ft2" => "b"]) do dir
            @test exampleinfo("zztest").formats == (nmrpipe="1/test.ft2",)
            @test example("zztest", :nmrpipe) == example("zztest")
        end
    end

    @testset "A saved analysis" begin
        toml = """
               title = "Analysed"
               path = "1"
               """
        files = ["1/acqus" => "a", "analysis/peaklist.csv" => "label", "analysis/analysis.toml" => ""]
        withdataset("zztest"; toml, files) do dir
            @test exampleanalysis("zztest") == joinpath(dir, "analysis")
        end
    end

    @testset "Credit, once a session" begin
        toml = """
               title = "Credited"
               path = "1"
               credit = ["A. Tester"]
               licence = "CC BY 4.0"
               """
        withdataset("zztest"; toml, files=["1/acqus" => "a"]) do dir
            delete!(CREDITED, "zztest")
            @test_logs (:info, r"^Example data zztest: Credited\nCredit: A. Tester") example("zztest")
            @test_logs example("zztest")
        end
    end

    @testset "The list of datasets" begin
        withdataset("zztest"; toml="title = \"Listed\"", files=["1/acqus" => "a"]) do dir
            listing = mktemp() do path, io
                redirect_stdout(() -> example(), io)
                close(io)
                read(path, String)
            end
            @test occursin(r"zztest\s+Listed", listing)
        end
    end

    @testset "LFS pointers instead of data" begin
        toml = """
               title = "Not fetched"
               path = "1"
               """
        withdataset("zztest"; toml, files=["1/acqus" => "a", "1/fid" => POINTER]) do dir
            @test !hasdata(dir)
            @test_throws ArgumentError example("zztest")
        end
    end

    @testset "Names: case, aliases, prefixes and the first added" begin
        toml(added; alias="") = """
                                title = "A"
                                aliases = [$(isempty(alias) ? "" : "\"$alias\"")]
                                added = "$added"
                                """
        files = ["1/acqus" => "a"]
        withdataset("zzrelaxation2d_ubq";
            toml=toml("2026-01-01T00:00:00Z"; alias="zzpseudo3D_HN_R2"), files) do _
            withdataset("zzrelaxation2d_zzasyn"; toml=toml("2026-02-01T00:00:00Z"), files) do _
                withdataset("zz2d_hn_ubq"; toml=toml("2026-01-01T00:00:01Z"), files) do _
                    withdataset("zz2d_hn_zzcalr"; toml=toml(""), files) do _
                        # a full name, even one added later
                        @test exampleinfo("zzrelaxation2d_zzasyn").name == "zzrelaxation2d_zzasyn"
                        @test exampleinfo("ZZRelaxation2D_ZZASYN").name == "zzrelaxation2d_zzasyn"
                        # a shortened name that matches several: the first added
                        @test exampleinfo("ZZRelaxation2D").name == "zzrelaxation2d_ubq"
                        @test exampleinfo("zzrelax").name == "zzrelaxation2d_ubq"
                        # one without an added time comes last
                        @test exampleinfo("ZZ2D_HN").name == "zz2d_hn_ubq"
                        # a part that matches only one
                        @test exampleinfo("zzasyn").name == "zzrelaxation2d_zzasyn"
                        @test exampleinfo("zzcalr").name == "zz2d_hn_zzcalr"
                        # aliases ignore case
                        @test exampleinfo("ZZPSEUDO3D_hn_r2").name == "zzrelaxation2d_ubq"
                        @test exampleinfo("zzrelaxation2d_ubq").added == "2026-01-01T00:00:00Z"
                    end
                end
            end
        end
        # a tie cannot be settled
        withdataset("zztie_a"; toml=toml("2026-01-01T00:00:00Z"), files) do _
            withdataset("zztie_b"; toml=toml("2026-01-01T00:00:00Z"), files) do _
                err = try
                    exampleinfo("zztie")
                catch e
                    e
                end
                @test err isa ArgumentError
                @test occursin("could be any of", err.msg)
            end
        end
    end

    @testset "The index in the registered package" begin
        # the registered package has no datasets/, only the index written at release
        withdataset("zzindexed"; toml="title = \"Indexed\"\npath = [[\"1\"], [\"2\"]]\n\n[formats]\nucsf = [[\"1/a.ucsf\"], [\"2/a.ucsf\"]]\n",
                    files=["1/acqus" => "a", "2/acqus" => "b", "analysis/peaklist.csv" => "x"]) do dir
            index = writeindex(tempname())
            fromindex = catalogue(joinpath(tempdir(), "no-datasets-here"), index)
            @test fromindex == catalogue()
            @test fromindex["zzindexed"]["path"] == [["1"], ["2"]]
            @test fromindex["zzindexed"]["formats"]["ucsf"] == [["1/a.ucsf"], ["2/a.ucsf"]]
            @test fromindex["zzindexed"]["analysis"] == true
        end
        @test isempty(catalogue(joinpath(tempdir(), "no-datasets-here"), tempname()))
    end

    @testset "Unknown names" begin
        @test_throws ArgumentError exampleinfo("no_such_dataset")
        @test_throws ArgumentError example("no_such_dataset")
    end
end
