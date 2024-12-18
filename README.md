# [Updated] SHA256 Implementation in WebAssembly Text

I've recently had some (more) time on my hands, so as a learning exercise, I decided to implement the SHA256 hash algorithm in raw WebAssembly text just to see how small I could make the compiled binary.

The original version of the binary was only 934 bytes.

😎

After this upgrade, the optimised binary is still only 1.8Kb!

😎😎

In order to understand the inner workings of the SHA256 algorithm itself, take a look at this excellent [SHA256 Algorithm](https://sha256algorithm.com/) website.
Thanks [@manceraio](https://twitter.com/manceraio)!

## Update

The [previous version of this program](https://awesome.red-badger.com/chriswhealy/sha256-webassembly) simply calculated the SHA256 of a file that had already been loaded into memory by the JavaScript host environment.

Whilst this worked well enough, it resulted in there being a very tight coupling between the WASM module and the functionality in the host JavaScript environment.
This update significantly reduces the degree of coupling.

Since all WASM modules are strictly sand-boxed, moving the IO operations down into the WebAssembly code will not work unless there is interface layer to bridge the gap between WASM and the operating system.

This is where the **W**eb**A**ssembly **S**ystem **I**nterface (WASI) comes in.
Its purpose is to connect the operating system calls made by WASM to the corresponding calls in the actual operating system.

Consequently, a JavaScript wrapper is still needed, but only a minimal one that performs the following tasks:

* Makes the NodeJS command line arguments available to WASM
* Preopens the current directory
* Starts the WASM module

This program has been tested in Node versions 18.20, 20.9 and 23.1

## Important

Due to the fact that WASM only has access to the files in (or beneath) the directories preopened by WASI, you cannot run this program against a file located anywhere on your disk.

In this case, WASI preopens the directory from which the NodeJS program is called.
Therefore, any files passed to the `sha256sum.mjs` program ***must*** live in (or beneath) that directory.

## Implementation Details

An explanation of how this updated version has been implemented can be found [here](./docs/README.md)

## Build

```bash
$ npm run build

> wasm_sha256@2.0.1 build
> npm run compile & npm run opt


> wasm_sha256@2.0.1 compile
> wat2wasm ./src/sha256.wat -o ./bin/sha256.wasm


> wasm_sha256@2.0.1 opt
> wasm-opt ./bin/sha256.wasm --enable-simd --enable-multivalue --enable-bulk-memory -O4 -o ./bin/sha256_opt.wasm
```

## Run

This program calculates the SHA256 hash of the file supplied as a command line argument.

The `sha256sum` command supplied in macOS is then run on the same file to show that the output is identical.

```bash
$ node sha256sum.mjs ./tests/war_and_peace.txt
(node:49732) ExperimentalWarning: WASI is an experimental feature and might change at any time
(Use `node --trace-warnings ...` to show where the warning was created)
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  ./tests/war_and_peace.txt
$
$ sha256sum ./tests/war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  ./tests/war_and_peace.txt
```
