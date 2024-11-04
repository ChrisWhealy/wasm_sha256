# [Updated] SHA256 Implementation in WebAssembly Text

I've recently had some time on my hands, so as a learning exercise, I decided to implement the SHA256 hash algorithm in raw WebAssembly text just to see how small I could make the compiled binary.

## Update

The previous version of this program simply calculated the SHA256 of a file that had already been loaded into memory by the JavaScript host environment.

Whilst this worked well enough, it resulted in a very tight coupling between the WASM module and the functionality in the host environment.
This update significantly reduces the degree of coupling bewteen the two programs by moving the coding that opens and reads the file from JavaScript into WebAssembly Text.

Consequently, this version of the WebAssembly program must be started using WASI in order for WebAssembly to be able to interact with the file system.

This program has been tested in Node versions 18.20, 20.9 and 23.1

## Build

```bash
npm run build

> wasm_sha256@2.0.1 build
> npm run compile & npm run opt


> wasm_sha256@2.0.1 compile
> wat2wasm ./src/sha256.wat -o ./bin/sha256.wasm


> wasm_sha256@2.0.1 opt
> wasm-opt ./bin/sha256.wasm --enable-simd --enable-multivalue --enable-bulk-memory -O4 -o ./bin/sha256_opt.wasm
```

## Run

This program calculates the SHA256 hash of the file supplied as a command line argument:

```bash
$ node index.mjs ./tests/war_and_peace.txt
(node:7175) ExperimentalWarning: WASI is an experimental feature and might change at any time
(Use `node --trace-warnings ...` to show where the warning was created)
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  ./tests/war_and_peace.txt
```

Optionally, you can add a second argument of `true` or `yes` to switch on performance tracking.

```bash
$ node index.mjs ./tests/war_and_peace.txt true
(node:12805) ExperimentalWarning: WASI is an experimental feature and might change at any time
(Use `node --trace-warnings ...` to show where the warning was created)
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  ./tests/war_and_peace.txt
Start up                :   0.127 ms
Instantiate WASM module :   1.746 ms
Calculate SHA256 hash   :  99.731 ms
Report result           :   2.419 ms

Done in 104.023 ms
```

## Implementation Details

A detailed discussion of this implementation can be found in [this blog](https://awesome.red-badger.com/chriswhealy/sha256-webassembly)

The inner workings of the SHA256 have been obtained from the excellent [SHA256 Algorithm](https://sha256algorithm.com/) website.
Thanks [@manceraio](https://twitter.com/manceraio)!

## Debugging WASM Functions

This is one area where development in WebAssembly Text is seriously lacking in developer tools.

In order to debug a function in the WASM module, the easiest way has been to create a `log_msg` function in JavaScript that is then imported into WASM.
