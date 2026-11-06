using Test, LibGit2_wasm_jll, SHA, TOML, Artifacts, Pkg
using Base.BinaryPlatforms: Platform

const TOMLFILE = joinpath(pkgdir(LibGit2_wasm_jll), "Artifacts.toml")
const ENTRY = TOML.parsefile(TOMLFILE)["LibGit2_wasm"]
const V = pkgversion(LibGit2_wasm_jll)

@testset "LibGit2_wasm_jll" begin
    dir = LibGit2_wasm_jll.artifact_dir
    @test isdir(dir)
    @test basename(dir) == ENTRY["git-tree-sha1"]
    @test Pkg.Artifacts.verify_artifact(Base.SHA1(ENTRY["git-tree-sha1"]))

    # licences: libgit2's COPYING (GPL-2.0 with the linking exception, LGPL-2.1 for xdiff) and the bundled ones
    for d in (joinpath(dir, "share", "licenses", "LibGit2_wasm"), joinpath(dir, "wasm32-wasip1", "share", "licenses", "LibGit2"))
        @test occursin("LINKING EXCEPTION", read(joinpath(d, "COPYING"), String))
        @test occursin("GNU LESSER GENERAL PUBLIC LICENSE", read(joinpath(d, "COPYING"), String))
        for f in ("zlib-LICENSE", "pcre2-LICENCE.md", "llhttp-LICENSE-MIT", "sha1dc-LICENSE.txt", "README.md")
            @test isfile(joinpath(d, f))
        end
        @test isdir(joinpath(d, "wasi-libc"))
    end
    # the corresponding source
    src = joinpath(dir, "share", "src", "LibGit2_wasm")
    @test isfile(joinpath(src, "lg2w.c"))
    @test isfile(joinpath(src, "SOURCES.md"))
    @test length(filter(endswith(".patch"), readdir(joinpath(src, "patches")))) >= 8

    # a cross-compiler asks with an explicit wasm platform and gets the same artifact
    @test artifact_meta("LibGit2_wasm", TOMLFILE; platform = Platform("wasm32", "wasi"))["git-tree-sha1"] == ENTRY["git-tree-sha1"]

    # the standalone module: wasm, its imports (WASI preview 1 and WasmHost's fetch) and exports
    @test libgit2_wasm32_wasm == joinpath(dir, "wasm32-wasip1", "lib", "libgit2.wasm")
    bytes = read(libgit2_wasm32_wasm)
    @test bytes[1:4] == codeunits("\0asm")
    m = TOML.parsefile(wasm_provider_wasm32)
    @test m["abi"] == "wasm32-wasip1-ilp32-v0"
    @test m["native"] == Dict("name" => "LibGit2_jll", "uuid" => "e37daf67-58a4-590a-8e99-b0245dd2ffc5",
                              "version" => string(VersionNumber(V.major, V.minor, V.patch)))
    mod = m["modules"]["libgit2"]
    @test bytes2hex(sha256(bytes)) == mod["sha256"]
    @test "wasm_host.http_request" in mod["imports"]
    @test all(i -> startswith(i, "wasi_snapshot_preview1.") || i == "wasm_host.http_request", mod["imports"])

    # the archive and headers
    @test libgit2_wasm32_a == joinpath(dir, "wasm32-wasip1", "lib", "libgit2.a")
    a = read(libgit2_wasm32_a)
    @test a[1:8] == codeunits("!<arch>\n")
    @test bytes2hex(sha256(a)) == m["libraries"]["libgit2"]["sha256"]
    @test isfile(joinpath(dir, "wasm32-wasip1", "include", "git2.h"))
    @test occursin("v$(V.major).$(V.minor).$(V.patch).tar.gz", m["build"]["source"])
end
