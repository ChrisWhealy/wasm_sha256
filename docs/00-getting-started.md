# The Consequences of WebAssembly Sandboxing

All WebAssembly programs are designed to run within their own isolated sandbox.

This is a deliberate design feature that not only prevents a WebAssembly program from damaging areas of memory that belong to other programs, but it also prevents the program from making unexpected operating system calls such as accessing the filesystem or the network.

That said, there are many situations in which it is perfectly appropriate for a WebAssembly program to interact with the operating system.
In our particular case, calculating the SHA256 hash of a file grants us the legitimate need to read that file from disk &mdash; but only that file: we have no need to read a random file located in some arbitrary directory.

So whenever a WebAssembly program wishes to open or read a file, it must make a request to the host environment to perform this task on its behalf.

All WebAssembly host environments therefore implement an interface layer known as the WebAssembly System Interface (or WASI).
WASI then acts as a proxy layer that grants the WebAssembly module access to the underlying `libc` functionality.

You can think of WASI as the bridge between the isolated sandbox in which WebAssembly programs run, and the "_outside world_".

## Getting Started With WASI

Any time a WebAssembly module needs to make a system call, it must invoke the corresponding function in the WASI layer.
Before this can happen however, the WebAssembly module must first use the `import` statement to declare which system calls it wishes to use.

The host environment must also preopen the files or directories before the WASI calls can be successful.

## Using WASI to Preopen a Directory

The syntax used by the WebAssembly host environment to grant access both to the functions in the WASI layer and the preopened resources varies slightly between environments.

The simplest option is to use a runtime environment such as `wasmer` or `wasmtime` because you do not need to write any code.

The following examples all assume you have:

* A local clone of this repo
* You have changed into the repo's top-level directory
* You already have the relevant runtimes installed
* You have the file [`war_and_peace.txt`](https://github.com/ChrisWhealy/wasm_sha256/blob/main/tests/war_and_peace.txt) in your home directory

### Wasmtime

```bash
$ wasmtime --dir /Users/chris ./bin/sha256_opt.wasm -- war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  war_and_peace.txt
$
```

### Wasmer

```bash
$ wasmer run . --mapdir /::/Users/chris -- war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  war_and_peace.txt
$
```

### NodeJs

In order to run this WASM module from NodeJS, you must write a JavaScript module that contains at least the following minimal code.

1. Import the `WASI` library and a function to read a file.

   If you do not care about suppressing the NodeJS warning that the use of `WASI` is experimental, then you can delete the code before the `import` statements:

   ```javascript
   // Suppress ExperimentalWarning message when importing WASI
   process.removeAllListeners('warning')
   process.on(
     'warning',
     w => w.name === 'ExperimentalWarning' ? {} : console.warn(w.name, w.message)
   )

   import { readFileSync } from "fs"
   import { WASI } from "wasi"
   ```

1. Create an `async` function that accepts a single argument of the path to the WASM binary:

   ```javascript
   const startWasm =
     async pathToWasmMod => {
       // TODO
     }
   ```

1. Inside this function, create a new `WASI` instance:

   ```javascript
   const wasi = new WASI({
     args: process.argv,
     version: "unstable",
     preopens: { ".": process.cwd() }, // Available as fd 3
   })
   ```

   In addition to creating the `WASI` instance, this code does two other important things:

   1. The line `args: process.argv` makes the command line arguments received by NodeJS available to the WebAssembly module
   1. The `preopens` object contains one or more directories that WASI will preopen for WebAssembly.

   The property names and values used in the `preopens` object are the directory names as seen by WebAssembly (`"."` in this case), and the directory on disk to which we are granting WebAssembly access.

   In this case, we are granting access to read files in (or beneath) the directory in which we start NodeJS.

1. Create an object that defines which functions the WASM module can `import`

   ```javascript
   const importObj = {
     wasi_snapshot_preview1: wasi.wasiImport,
   }
   ```

   `wasi_snapshot_preview1` is the default WASI library name used by all WASI implementations and its value is set to `wasi.wasiImport` that implements the actual WASI API.


   > Although JavaScript gives you the possibility to rename this property to something shorter (such as `wasi`), doing so will mean your WebAssembly module cannot be invoked by other runtimes such as `wasmer` or `wasmtime` that use the hardcoded default name `wasi_snapshot_preview1`.

## Understanding File Descriptors

A file descriptor is a handle to access some resource in a file system: typically either a file or a directory.

File descriptors are created with a particular set of capabilities that describe the actions you wish to perform on that resource: for example, when opening a file, you must define whether you require read only access or read/write access.

### Standard File Descriptors

A file descriptor is simply by an integer.
When WASI starts, it automaticaly preopens three file descriptors for you:

* fd 0 = `stdin` (standard in)
* fd 1 = `stdout` (standard out)
* fd 2 = `stderr` (standard error)

Subsequent file descriptors are usually (but not always) allocated in sequential order.
In this case, the file descriptor for the first directory preopened by WASI is `3`

[^1]: In NodeJS versions 18 and higher, the WASI interface is available by default.  In versions from 12 to 16, WASI will only be available if you start `node` with the flag `--experimental-wasi-unstable-preview1`
