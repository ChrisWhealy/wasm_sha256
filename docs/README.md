# Prerequisites

Please check that all the following prerequisites have been met.

1. Are you comfortable writing directly in WebAssembly Text? (Be honest)

   If the answer is "No", then please read my [Introduction to WebAssembly Text](https://awesome.red-badger.com/chriswhealy/introduction-to-web-assembly-text)

1. Install [`wasmtime`](https://wasmtime.dev/).
   This is an Open Source project by the Bytecode Alliance that provides both the WebAssembly development tools we will be using, and the WebAssembly System Interface (WASI) that will be the focus of our attention in this blog.

1. In order to understand how to code againt the WASI interface, it is very helpful to look at the Rust source code that implements the WASI functions you will be calling from your WebAssembly Text program.

   This code can be found in the `wasmtime` Github repo <https://github.com/bytecodealliance/wasmtime>.
   The specific file to look in is `crates/wasi-preview1-component-adapter/src/lib.rs`

# Explanation of Update

The purpose of updating this program was to move all the file IO into WebAssembly.
In doing so, the functionality in the JavaScript wrapper used to start the SHA256 program has become very much simpler.

# Overview of Steps

[Getting Started](./00-getting-started.md)

1. [Import WASI Functions into WebAssembly](./10-import-wasi.md)
1. [Start WASI](./20-start-wasi.md)
1. [Count the Command Line Arguments](./30-count-cmd-line-args.md)
1. [Extract the filename from the command line arguments](./40-parse-cmd-line-args.md)
1. [Open the file](./50-open-file.md)
1. [Read the File Size](./60-read-file-size.md)
1. [Do We Have Enough Memory?](./70-grow-memory.md)
1. [Read the file into memory](./80-read-file.md)
1. [Close the file](./90-close-file.md)

# Extras

1. [WebAssembly Coding Tips and Tricks](./wat_tip_and_tricks.md)
1. [Debugging WASM](./debugging_wasm.md)
