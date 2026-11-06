# LibGit2_wasm_jll.jl

[libgit2](https://libgit2.org) compiled to **WebAssembly**, as a static archive and as a standalone module, packaged as a JLL for Julia programs compiled to WebAssembly (e.g. with [WasmCodegen.jl](https://github.com/gbaraldi/WasmCodegen.jl)). It is input to a linker or to a WebAssembly host, not a library Julia loads: nothing here is `dlopen`ed.

[WasmCompat.jl](https://github.com/pankgeorg/WasmCompat.jl)'s `WasmCompatLibGit2Ext` runs Julia's `LibGit2` standard library on this module, so that a program compiled to WebAssembly (Pkg, for one) clones, fetches and checks out with libgit2 itself.

> **Interim package.** This package stands in for `LibGit2_wasm_jll` until its Yggdrasil recipe, `L/LibGit2_wasm` (branch [`wasm-libgit2`](https://github.com/pankgeorg/Yggdrasil/tree/wasm-libgit2/L/LibGit2_wasm) of pankgeorg/Yggdrasil, for JuliaPackaging/Yggdrasil after [#15468](https://github.com/JuliaPackaging/Yggdrasil/pull/15468)), is merged and registered.
>
> It is what Yggdrasil's registration would generate from that recipe:
> - the same name, and the same UUID (`af6da55f-a25c-5e7a-9586-6a6edd93f4c4`, BinaryBuilder's `jll_uuid("LibGit2_wasm_jll")`);
> - the same artifact name, `LibGit2_wasm`;
> - the same products.
>
> Once the registered package exists, switching needs no code change: `pkg> free LibGit2_wasm_jll`, or remove it and `add` it again from the registry.

## Versions

The libgit2 version must equal the `LibGit2_jll` of the Julia that compiles the program.

| Julia | `LibGit2_jll` | This package | Install |
|---|---|---|---|
| 1.13.2 | 1.9.7+0 | 1.9.7+0 (`main`, tag `LibGit2-v1.9.7+0`) | `pkg> add https://github.com/pankgeorg/LibGit2_wasm_jll.jl` |

## Contents

One flavour, `wasm32-wasip1/` (ILP32, against wasi-libc from wasi-sdk 34). libgit2 needs a libc and a filesystem, so there is no freestanding wasm64 flavour.

| File | Product |
|---|---|
| `wasm32-wasip1/lib/libgit2.wasm` | `libgit2_wasm32_wasm` |
| `wasm32-wasip1/lib/libgit2.a` | `libgit2_wasm32_a` |
| `wasm32-wasip1/share/wasm-provider.toml` | `wasm_provider_wasm32` |

There is also `wasm32-wasip1/include/` (`git2.h`), `share/licenses/` and `share/src/LibGit2_wasm/` (the corresponding source: see *License*).

**`libgit2.wasm`** is libgit2 1.9.7, a wrapper (`lg2w.c`, in the artifact's `share/src/LibGit2_wasm/` and the recipe's `bundled/`) and wasi-libc linked into a reactor module (call `_initialize` first).

It imports:
- WASI preview 1, for its filesystem. Give it a WASI instance of its own over the same preopens and environment as the program's, so both see one filesystem.
- `wasm_host.http_request`, [WasmHost.jl](https://github.com/pankgeorg/WasmHost.jl)'s fetch import (protocol `wasm-fetch 1`). libgit2's smart HTTP transport sends its requests through it, since WASI has no sockets. The import may suspend (JSPI). Response bodies go through files of `$WASMHOST_SPOOL`.

It exports:
- `memory`, `malloc`, `free`, and `mem_load8/32/64` and `mem_store8/32/64` (address, value);
- the libgit2 functions WasmCompat's extension calls (`share/src/LibGit2_wasm/exports.txt`);
- `lg2w_*`, a flat API for hosts: `lg2w_init`, `lg2w_open`, `lg2w_clone(url, path, bare, branch, depth)`, `lg2w_fetch`, `lg2w_revparse`, `lg2w_read`, `lg2w_ls_tree`, `lg2w_checkout_tree`, `lg2w_head`, `lg2w_refs`, ...: strings in, results through `lg2w_out_ptr`/`lg2w_out_len`, errors as libgit2's code, class and message.

Every repository the module opens, initializes or clones gets `core.filemode = false`, because WASI has no permission bits. Its size is 1.1 MB (372 KB gzipped).

**`libgit2.a`** is the library alone, for linking with wasi-libc into a module of your own.

**Build configuration.** libgit2's WASI changes are 10 small patches: the `wasi-v1.9.7` branch of [pankgeorg/libgit2](https://github.com/pankgeorg/libgit2), proposed upstream as `wasi-main`.
- No threads.
- No TLS backend: https is the module's transport over the host's fetch.
- No SSH.
- SHA-1 with collision detection, builtin SHA-256.
- Bundled zlib, PCRE, llhttp and xdiff.

The provider manifest records the native JLL it mirrors (`LibGit2_jll`, its UUID and version), the archive's and the module's sha256, the module's imports, the archive's undefined symbols, and the source, compiler, sysroot and recipe.

## Usage

```julia
using LibGit2_wasm_jll
LibGit2_wasm_jll.libgit2_wasm32_wasm   # .../wasm32-wasip1/lib/libgit2.wasm, the standalone module
LibGit2_wasm_jll.libgit2_wasm32_a      # .../wasm32-wasip1/lib/libgit2.a
LibGit2_wasm_jll.wasm_provider_wasm32  # its manifest
```

With WasmCompat:

```julia
using WasmCodegen, WasmCompat, LibGit2, LibGit2_wasm_jll
config = WasmCompat.libgit2_config(WasmCodegen.Config(host = :wasi))
cp(WasmCompat.libgit2_module(), "libgit2.wasm")   # deploy it with the program
```

In JavaScript, with WasmCompat's `js/libgit2.mjs` and WasmHost's Node adapter:

```js
const wasi = new WASI({ version: 'preview1', preopens, env, returnOnExit: true });
const imports = { ...programImports, ...(await libgit2Imports(fs.readFileSync(path), { wasi, wasmHost: makeImports({ preopens }) })) };
```

On Node 24, run with `--no-turbo-fast-api-calls`: a node:wasi call that allocates while a JSPI stack is active can abort the process (`Check failed: isolate_->IsOnCentralStack()`).

The artifact is platform-independent (`AnyPlatform`): the same bytes on every host, installed by plain `Pkg.add`.

## Provenance

| | |
|---|---|
| Source | https://github.com/libgit2/libgit2/archive/refs/tags/v1.9.7.tar.gz, sha256 `1a4fbe7589e814777ae76b64734ad80f4ecad22cd33a22682a2aaea4ae5375e7` |
| Patches | https://github.com/pankgeorg/libgit2/tree/wasi-v1.9.7 (`git format-patch v1.9.7..wasi-v1.9.7`, in the tarball's `share/src/LibGit2_wasm/patches/`) |
| Recipe | [pankgeorg/Yggdrasil@`wasm-libgit2`](https://github.com/pankgeorg/Yggdrasil/tree/wasm-libgit2/L/LibGit2_wasm) (`L/LibGit2_wasm/build_tarballs.jl`, `bundled/`, `platforms/wasm.jl`): the same patches, wrapper, flags and toolchain pins |
| Builder | **CMake**, the recipe's steps by hand (`share/src/LibGit2_wasm/build/build-all.sh`), on aarch64 Linux: BinaryBuilder's x86_64 sandbox does not run on that host. Reproducible: two builds from different source trees gave byte-identical modules and archives, and the tarball is byte-identical when repackaged |
| Compiler | clang 23.1.0 of wasi-sdk 34.0 (llvm-project `895aa2c896ada719451be2e3673c83da8ddf1141`) |
| Sysroot | `wasi-sysroot-34.0.tar.gz`, sha256 `9d813544eeebe38b7b8f2244ed591de46b6db812c6dd1a257ff9f0d2a905a2be` |

| Release asset | git-tree-sha1 | sha256 |
|---|---|---|
| `LibGit2_wasm.v1.9.7.any.tar.gz` (1.9.7+0) | `8dc091bfae9e3c84faefcdf929d837b22cc37d9b` | `586e4fc97f96ad1df9c4c43e2afa3cb0668818c5703305698eea7e4ee41ca1da` |

## License

The Julia code in this repository (`src/`, `test/`) is MIT-licensed; see [LICENSE](LICENSE).

The binaries are libgit2, which is under `GPL-2.0-only WITH the libgit2 linking exception`. The linking exception lets a program link libgit2 and distribute the combination without the GPL applying to the program. Distributing libgit2 on its own, as this artifact does, is under the GPL. The corresponding source is in the artifact's `share/src/LibGit2_wasm/`: libgit2's release tarball by URL and hash, the patches, the wrapper and the build.

Bundled code:
- xdiff (LGPL-2.1-or-later): the module is a separate instance a program imports, so any build of the same source can replace it;
- PCRE2 (BSD-3-Clause WITH PCRE2-exception);
- zlib (Zlib);
- llhttp (MIT);
- SHA-1 collision detection (MIT);
- wasi-libc (Apache-2.0 WITH LLVM-exception, MIT).

Their texts are in the artifact at `share/licenses/LibGit2_wasm/` and `wasm32-wasip1/share/licenses/LibGit2/`. The wrapper `lg2w.c` is MIT.
