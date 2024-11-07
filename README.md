# [Updated] SHA256 Implementation in WebAssembly Text

I've recently had some time on my hands, so as a learning exercise, I decided to implement the SHA256 hash algorithm in raw WebAssembly text just to see how small I could make the compiled binary.

This version of the binary was only 934 bytes.
After this upgrade, the optimised binary is still less than 2Kb (1871 bytes to be exact)

😎

## Update

The previous version of this program simply calculated the SHA256 of a file that had already been loaded into memory by the JavaScript host environment.

Whilst this worked well enough, it resulted in the WASM module needing to be tightly coupled to the functionality in the host environment.
This update removes that coupling almost entirely.

The JavaScript wrapper is needed only to create a WASI environment that makes the NodeJS command line arguments available to WASM, preopens the current directory, and then connects the various system calls made in WASM to the corresponding system call in the operating system.

This program has been tested in Node versions 18.20, 20.9 and 23.1

## ***Important***

Due to the fact that WASM only has access to the files in (or beneath) the directories preopened by WASI, you cannot run this program against a file located anywhere on your disk.

The file for which you wish to calculate the SHA ***must*** live in (or beneath) this repo's home directory.

Notice in the above example that the `war_and_peace.txt` file lives in the `tests/` directory under the current directory.

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

This program calculates the SHA256 hash of the file supplied as a command line argument:

```bash
$ node sha256sum.mjs ./tests/war_and_peace.txt
(node:49732) ExperimentalWarning: WASI is an experimental feature and might change at any time
(Use `node --trace-warnings ...` to show where the warning was created)
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  ./tests/war_and_peace.txt
```

## Implementation Details

A detailed discussion of the implementation of the SHA256 algorithm can be found in [this blog](https://awesome.red-badger.com/chriswhealy/sha256-webassembly)

In order to understand the inner workings of the SHA256 algorithm itself, look at this excellent [SHA256 Algorithm](https://sha256algorithm.com/) website.
Thanks [@manceraio](https://twitter.com/manceraio)!

## Debugging WASM Functions

This is one area where development in WebAssembly Text is seriously lacks developer tools.

There is a another JavaScript module called `dev_sha256sum.mjs` that was used during development.
This includes extra functionality for performance tracing and logging.
If you wish to use this version and make use of the logging functionality, you will first need to uncomment the `(import ...)` statements at the start of `./src/sha566.wat` and then recompile the WASM module.

In order to debug a function in the WASM module, the easiest way has been to create a `log.msg` function in JavaScript:

```javascript
let { instance } = await WebAssembly.instantiate(
  new Uint8Array(readFileSync(pathToWasmFile)),
  {
    wasi_snapshot_preview1: wasi.wasiImport,
    log: { "msg": logWasmMsg },
  },
)
```

That is then imported by the WebAssembly module:

```wat
(module
  ;; Import log functions
  (import "log" "msg" (func $log_msg (param i32 i32 i32)))

  ;; snip
)
```

Anytime I need to see what value a WASM function is working with, I call a logging function such as `$log_msg` which writes an `i32` value along with a particular message to the console.

Since some WASM functions perform multiple steps (E.G. `path_open` followed by `fd_seek` followed by `fd_read`), it was convenient to assign arbitrary numbers to both the processing steps and the particular messages.
That way, the console output can show which step has been reached, and what value is currently being handled.

For example, when validating that the command line arguments were being parsed correctly, I needed to check certain counter values.

I did this calling the `$log_msg` function in WAT passing in an arbitrary step number, a message id and the `i32` value to be displayed.

The step and message id numbers must correspond to the values declared in `./utils/log_utils.mjs` in tyhe `Map`s `stepNames` and `stepDetails`.

E.G. The log message for step 9, message id 17 will display the number are command lines arguments like this

```wat
(call $log_msg (i32.const 9) (i32.const 17) (local.get $argc))
```

This then produces 

```
WASI: _start() argc = 4
```
