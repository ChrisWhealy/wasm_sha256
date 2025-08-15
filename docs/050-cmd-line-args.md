# Step 5: Command Line Arguments

## Count Command Line Arguments

The following statement will fetch the number of command line arguments we have received.

```wat
(call $wasi.args_sizes_get (global.get $ARGS_COUNT_PTR) (global.get $ARGV_BUF_LEN_PTR))
drop

;; Remember the argument count and the total length of arguments
(local.set $argc (i32.load (global.get $ARGS_COUNT_PTR)))
```

However, we have no idea which host environment has instantiated the module.
If we've been called by NodeJS, we'll get 3 arguments, but other host environments such as `wasmer` or `wasmtime` will pass in 2.

After the call to `$wasi.args_sizes_get`, we store the argument count (pointed to by `$ARGS_COUNT_PTR`) in the local variable `$argc` and the total length of the argument buffer (pointed to by `$ARGV_BUF_LEN_PTR`) in the local variable `$argv_buf_len`.

![Calling `args_sizes_get`](../img/args_sizes_get.png)
