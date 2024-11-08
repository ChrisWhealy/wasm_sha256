# Step 3: Count the Command Line Arguments

One of the properties passed by JavaScript to the WASI instance is called `args` and has the value `process.argv`.
This means that the same command line received by NodeJS is now also available to the WASM module.

In the WASM function `_start`, we must first determine how many arguments we have received by calling the WASI function `args_sizes_get`.

This function is imported into WebAssembly at the start of the module and is known internally as `$wasi_args_sizes_get`:

```wat
(type $type_wasi_args (func (param i32 i32) (result i32)))
(import "wasi" "args_sizes_get" (func $wasi_args_sizes_get (type $type_wasi_args)))
```

## Take a look at the Rust `wasmtime` implementation

In order to understand how to interact with this function, it is helpful to look at the Rust coding that implements the WASI function [`args_sizes_get()`](https://github.com/bytecodealliance/wasmtime/blob/06377eb08a649619cc8ac9a934cb3f119017f3ef/crates/wasi-preview1-component-adapter/src/lib.rs#L506)

Here, you see the following function signature:

```rust
pub unsafe extern "C" fn args_sizes_get(argc: *mut Size, argv_buf_size: *mut Size) -> Errno
```

If this function call is successful, you get back an error number of `0` that can be ignored by calling `drop`.

## Call `args_sizes_get`

Calling WASI functions generally means passing pointers; however, to avoid having memory addresses hardcoded into function calls, the following global pointers have been declared:

```wat
(global $ARGS_COUNT_PTR     i32 (i32.const 0x000004c0))
(global $ARGV_BUF_SIZE_PTR  i32 (i32.const 0x000004c4))
```

Then, when we call WASI functions, we always reference these global values:

The WASI function then performs its processing and returns information to the calling program by writing it to the memory locations identified by the pointers.

```wat
;; How many command line args have we received?
(call $wasi_args_sizes_get (global.get $ARGS_COUNT_PTR) (global.get $ARGV_BUF_SIZE_PTR))
drop
```

The actual return value of the function call is used only for error handling.
Here, we will assume `args_sizes_get` gives a return code of zero, so we can ignore it by calling `drop`.

![Calling `args_sizes_get`](../img/args_sizes_get.png)

We store the values returned by WASI by loading the `i32` values found at the addresses stored in these pointers:

```wat
;; Remember the argument count and the total length of arguments
(local.set $argc          (i32.load (global.get $ARGS_COUNT_PTR)))
(local.set $argv_buf_size (i32.load (global.get $ARGV_BUF_SIZE_PTR)))
```

For this command line:

```bash
node sha256sum.mjs ./tests/war_and_peace.txt
```

We get back the value `3` for `argc`; however, the value returned for `argv_buf_size` is longer than the string value shown above because `node` and `sha256sum.mjs` are expanded to their fully qualified names.

Hence, the value of `argv_buf_size` is actually `0x83` (131 characters)

The string length of 131 also includes a `0x00` null terminator character at the end of each argument.
This must be accounted for when calculating argument lengths.
