# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule LibGit2_wasm_jll
using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("LibGit2_wasm")
JLLWrappers.@generate_main_file("LibGit2_wasm", Base.UUID("af6da55f-a25c-5e7a-9586-6a6edd93f4c4"))
end  # module LibGit2_wasm_jll
