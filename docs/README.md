# Calculating the SHA256 Hash In WebAssembly Text Using Buffered IO

## Prerequisites

Before diving into this blog, please check that the following prerequisites have been met.

1. It is assumed you already have [NodeJS](https://nodejs.org/en/download) installed.

1. Are you comfortable writing directly in WebAssembly Text? (Be honest)

   If the answer is "No", then please read my [Introduction to WebAssembly Text](https://awesome.red-badger.com/chriswhealy/introduction-to-web-assembly-text)

1. Since this version of the program builds on the previous version, you will find it helpful to read the [previous blog](https://awesome.red-badger.com/chriswhealy/sha256-extended) that describes adding file I/O.


1. Install an additional WebAssembly Runtime such as [`wasmer`](https://wasmer.io/) or [`wasmtime`](https://wasmtime.dev/).

1. In order to understand how the WASI interface works, it is helpful to look at a Rust implementation such as the one by `wasmtime`.
   This code can be found in the GitHub repo <https://github.com/bytecodealliance/wasmtime> where the specific file is `crates/wasi-preview1-component-adapter/src/lib.rs`.

## Explanation of Update

### Version 1

<https://awesome.red-badger.com/chriswhealy/sha256-webassembly>

Version 1 of this program implemented nothing more than the SHA256 algorithm in WebAssembly Text.
Consequently, it could not run without a JavaScript wrapper that both read the file into memory and wrote the correct termination values to the end of the last message block.

This was a good first step, but it was not very versatile as the WASM module was tightly coupled to the JavaScript coding running in the host environment.


### Version 2

<https://awesome.red-badger.com/chriswhealy/sha256-extended>

Next, I moved all the file I/O into the WASM module.
This greatly simplified the requirements of the host environment and allowed the program to be run directly from other WebAssembly runtimes such as `wasmtime`.

### Version 3

This documentation covers the current version of the program.

I was surprised to discover that although the WASM module ran successully from NodeJS and `wasmtime`, when run using `wasmer`, it produced the wrong hash value.  🤔

Upon investigation, I had assumed it was fine to calculate the size of the file, allocate sufficient memory to hold that file, specify a read buffer size equal to the file size, then make a single call to `$wasi.fd_read` to grab the entire file all at once.
NodeJS and `wasmtime` are happy to operate this way, but I discovered that `wasmer` imposes a 2Mb limit on the size of the read buffer.

Consequently, I needed to rewrite the file I/O logic to calculate the SHA256 hash on successive 2Mb chunks.
This has the advantage of avoiding the need to allocate a potentially large amount of memory.

## Overview of Steps

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
