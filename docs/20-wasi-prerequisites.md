# Step 2: WASI Prerequisites

When starting a WebAssembly module instance using WASI, that module must fulfil two prerequisites.

1. WASI requires the WebAssembly module to export a block of memory called `memory`.
   In our particular case, we use the following WAT statement:

   ```wat
   (memory $memory (export "memory") 34)
   ```

   This means that when it starts, the WebAssembly module:

   * Allocates 34, 64Kb memory pages (64Kb for internal stuff and 2Mb + 64Kb for the read buffer)
   * Makes that memory available to the host environment using the default name `memory`

      > `memory` is simply the name expected by WASI.
      > If you wish to export memory using some other name, that is also possible &mdash; it's just that WASI won't know anything about it...

2. WASI also requires the WebAssembly module to export a function called `_start`.

   In cases where NodeJS acts as the host environment, the `_start` function will be called automatically when the JavaScript statement `wasi.start(instance)` is called.

   The `_start` function may not take any arguments and may not return any values.

   If you have no need for such a function, then it must still exist as a no-op function:

   ```wat
   (func (export "_start"))
   ```

   If the `_start` function is missing, then the host environment will throw an exception.
