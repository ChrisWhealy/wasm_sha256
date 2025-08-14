# Step 2: WASI Prerequisites

When starting a WebAssembly module instance using WASI, that module must fulfil two prerequisites.

1. WASI expects the WebAssembly module to export a block of memory called `memory`.
   In our particular case, we use the following WAT statement:

   ```wat
   (memory $memory (export "memory") 34)
   ```

   This means that when it starts, the WebAssembly modeul:

   * Allocate 34, 64Kb memory pages
   * Makes that memort available to the host environment using the default name `memory`

      > `memory` is simply the name expected by WASI.
      > If you wish to export memory using some other name, that is also possible &mdash; it's just that WASI won't know anything about it...

2. WASI also expects the WebAssembly module to export a function called `_start`.

   In the case of Node=JS acting as the host environment, the `_start` function will called automatically when the JavaScript statement `wasi.start(instance)` is called.

   This function must not take any arguments and must not return any values.

   If you have no need for such a function, then it must still exist as a no-op function:

   ```wat
   (func (export "_start"))
   ```

   If the `_start` function is missing, then the host environment will throw an exception.
