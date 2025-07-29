# [Wasmer Update] SHA256 Implementation in WebAssembly Text

I wrote the original version of this module with the assumption that NodeJS would act as the host environment.
This was all fine and everything worked correctly.
However, when I attempted to use [Wasmer](https://wasmer.io) as the host environment, the WASM module did not function as expected due to various differences that was not aware of.

This update accounts for those differences.
However, in making these changes, I needed to implement basic debug/trace functionality in the WASM module, which in turn, bloated the size of the binary to an enormous 2.4Kb (🤣)

## Understanding the SHA256 Algorithm

In order to understand the inner workings of the SHA256 algorithm itself, take a look at this excellent [SHA256 Algorithm](https://sha256algorithm.com/) website.
Thanks [@manceraio](https://twitter.com/manceraio)!

## Wasmer Update

* NodeJS passes three values as command line arguments to the WASM module, but Wasmer passes only two
* When calling this module via the Wasmer CLI, the `--dir` argument does not pre-open the directory in which the file live.<br>
   Instead, you need to use the `--mapdir` argument

## Important

Due to the fact that WASM only has access to the files in (or beneath) the directories preopened by WASI, you cannot run this program against a file located in some arbitrary directory.

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

## Prerqeuisites

Install the Wasmer run time: <https://docs.wasmer.io/runtime>

## Run via Wasmer CLI

```bash
$ wasmer run ./bin/sha256_opt.wasm --mapdir tests::/Users/chris/Developer/WebAssembly/sha256/tests -- /tests/war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  ./tests/war_and_peace.txt
$
```
