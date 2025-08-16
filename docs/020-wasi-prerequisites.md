# Step 2: WASI Prerequisites

When WASI is used to start a WebAssembly module, that module is required to fulfil these two prerequisites.
The WebAssembly module ***must***:

1. Export a block of memory called `memory`.

   In our particular case, we use the following WAT statement:

   ```wat
   (memory $memory (export "memory") 34)
   ```

   This means that when it starts, the WebAssembly module:

   * Allocates 34, 64Kb memory pages (64Kb for internal stuff and 2Mb + 64Kb for the read buffer)
   * Makes that memory available to the host environment using the default name `memory`

      > `memory` is simply the name expected by WASI.
      > If you wish to export memory using some other name, that is also possible &mdash; it's just that WASI won't know anything about it...

2. Export a function called `_start` that takes no arguments and returns nothing.

   If the `_start` function is missing, then WASI will throw an exception.

   When using runtime environments such as `wasmer` or `wasmtime`, the `_start` function is called automatically as soon as the WASM instance is created.
   However, when NodeJS is the host environment, the `_start` function will not be called until the JavaScript statement [`wasi.start(instance)`](https://github.com/ChrisWhealy/wasm_sha256/blob/238bbc2cd5389bbd2d90bdc821a446b5994034f7/sha256sum.mjs#L30) is called.

   If your usecase has no need for such a function, then it must still exist as a no-op function:

   ```wat
   (func (export "_start"))
   ```
