# Debugging WASM Functions

This is one area where development in WebAssembly Text seriously lacks developer tools.

The bulk of the JavaScript coding accompanying this WASM module exists simply to provide a test framework through which individual WASM functions can be tested and debugged.

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

The step and message id numbers must correspond to the values declared in `./utils/log_utils.mjs` in the `Map`s `stepNames` and `stepDetails`.

E.G. The log message for step 9, message id 17 will display the number of command lines arguments:

```wat
(call $log_msg (i32.const 9) (i32.const 17) (local.get $argc))
```

This then produces

```
WASI: _start() argc = 4
```
