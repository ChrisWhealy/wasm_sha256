# Getting Started With WASI File IO

When you interact with the filesystem using WASI, you are interacting with the operating system at a level that is much lower than you might be used to when working in a high level language such as Python or JavaScript.

## Understanding WebAssembly Sandboxing

All WebAssembly programs run within their own isolated sandbox.
This not only prevents the WebAssembly program from damaging areas of memory that belong to other programs, but it also prevents the WASM program from making inappropriate operating system calls such as accessing the filesystem or the network.

However, there are many situations in which it is perfectly appropriate for a WebAssembly program to interact with the operating system.
In this particular case, our WebAssembly program has a legitimate need to read a file from disk.

This is one of the areas in which WASI bridges the gap between the isolated sandbox in which your WebAssembly program runs, and the "outside world", so to speak.

However, in order to maintain control over which files the WebAssembly program may access, the host enviornment that starts WASI must first ***pre-open*** those directories.
Only then will WebAssembly be granted access.

In other words, if the host environment decides that a WebAssembly program may not access the files in a certain directory, then there is nothing the WebAssembly program can do to alter that decision.

## Using WASI to Pre-open a Directory

The host environment for running this WebAssembly program is, in our case, a JavaScript prgram running within NodeJS.[^1]

Before the JavaScript module can invoke our SHA256 program, we must first create an instance of the WASI environment, then use that instance to start the SHA256 program:

```javascript
import { WASI } from "wasi"

const wasi = new WASI({
  args: process.argv,
  version: "unstable",
  preopens: { ".": process.cwd() }, // This directory is available to WASI as fd 3
})
```

This code does three important things:

1. It creates a new WASI instance
1. The line `args: process.argv` makes the command line arguments received by NodeJS available to the WebAssembly module
1. The `preopens` object contains one or more directories that WASI will preopen for WebAssembly.

   The property name is the directory name as seen by WebAssembly (`"."` in this case), and the property value is the directory on disk to which we are granting WebAssembly access.

   In this case, we are granting access to read files in (or beneath) the directory in which we start NodeJS.

## Understanding File Descriptors

A file descriptor is a handle to access some object in a file system: typically either a file or a directory.
When using WASI, we always works with file descriptors.

A file descriptor must be created with a particular set of capabilities that describe the actions you wish to perform on that object: for example, you must define whether you require read only or read/write access to a file.

### Standard File Descriptors

A file descriptor is identified simply by an integer.
When WASI starts, it automaticaly preopens three file descriptors for you:

* fd 0 = `stdin` (standard in)
* fd 1 = `stdout` (standard out)
* fd 2 = `stderr` (standard error)

Subsequent file descriptors are usually (but not always) allocated in sequential order.
In this case, the file descriptor for the first directory preopened by WASI is `3`

[^1]: In NodeJS versions 18 and higher, the WASI interface is available by default.  In versions from 12 to 16, WASI will only be available if you start `node` with the flag `--experimental-wasi-unstable-preview1`
