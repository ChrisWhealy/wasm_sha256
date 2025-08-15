# Prerequisites

Before diving into this blog, please check that the following prerequisites have been met.

1. It is assumed you already have [NodeJS](https://nodejs.org/en/download) installed.

1. Are you comfortable writing directly in WebAssembly Text? (Be honest)

   If the answer is "No", then please read my [Introduction to WebAssembly Text](https://awesome.red-badger.com/chriswhealy/introduction-to-web-assembly-text)

1. Since this version of the program builds on the previous version, you will find it helpful to read the [previous blog](https://awesome.red-badger.com/chriswhealy/sha256-extended) that describes adding file I/O.


1. Install an additional WebAssembly Runtime such as [`wasmer`](https://wasmer.io/) or [`wasmtime`](https://wasmtime.dev/).

1. A WebAssembly program cannot perform tasks such as file I/O directly.  Instead, these tasks are performed by the host environment and requested via the WebAssembly System Interface (WASI).

   Therefore, in order to understand how the WASI interface works, it is very helpful to look at a Rust implementation such as the one by `wasmtime`.
   This code can be found in the GitHub repo <https://github.com/bytecodealliance/wasmtime> where the specific file is `crates/wasi-preview1-component-adapter/src/lib.rs`.

# Explanation of Update

The previous version of this program focused on decoupling the underlying WASM module from its JavaScript wrapper by moving all the file I/O into the WebAssembly module.

Whilst this greatly simplifies the JavaScript coding needed to invoke the WASM module, it adds the requirement that the WASM module must first allocate enough memory to contain the entire file before the SHA256 hash calculation can begin.

This update uses buffered I/O to read the file in 2Mb chunks, thereby avoiding the need to make a potentially large memory allocation.

# Overview of Steps

[Getting Started](./000-getting-started.md)

1. [Import WASI functions into WebAssembly](./010-import-wasi.md)
1. [WASI prerequisites](./020-wasi-prerequisites.md)
1. [Plan memory layout](./030-memory-layout.md)
1. [The `_start` function](./040-start-fn.md)
1. [Process command line arguments](./050-cmd-line-args.md)
1. [Open the file](./060-open-file.md)
1. [Read the file size](./070-read-file-size.md)
1. [Read the file into memory](./080-read-file.md)
1. [Close the file](./090-close-file.md)
2. [Write Hash Value to `stdout`](./100-write-hash.md)

# Extras

1. [WebAssembly Coding Tips and Tricks](./wat_tip_and_tricks.md)
1. [Debugging WASM](./debugging_wasm.md)
