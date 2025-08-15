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

## Check for Buffer Overrun

In our memory map, we set aside 256 bytes in which to store the command line arguments.
However, at runtime, we could be passed a value of any length; therefore, before reading the actual command argument value, we must check that the supplied value will fit into the allocated space.

```wat
(if ;; total argument length > 256 (buffer overrun)
  (i32.gt_u
    (local.tee $argv_buf_len (i32.load (global.get $ARGV_BUF_LEN_PTR)))
    (i32.const 256)
  )
  (then
    ;; (call $write_step (i32.const 2) (local.get $step) (i32.const 4))
    (call $writeln (i32.const 2) (global.get $ERR_ARGV_TOO_LONG) (i32.const 25))
    (br $exit)
  )
)
```

Notice the use of the `local.tee` statement.
This is a widely used statement that firstly sets the value of a local variable (`$argv_buf_len` in this case), but then leaves that value on the stack ready for the next statement to use.
Hence, the comparison made by `i32.gt_u` already has the value of `$argv_buf_len` on the stack because `local.tee` helpfully left it there.

## Check the Argument Count

Since we don't know which host environment we're being run from, we can only check for the minimum argument count of 2.


```wat
(if ;; less than 2 arguments have been supplied
  (i32.lt_u (local.get $argc) (i32.const 2))
  (then
    ;; (call $write_step (i32.const 2) (local.get $step) (i32.const 4))
    (call $writeln (i32.const 2) (global.get $ERR_MSG_NOARG) (i32.const 26))
    (br $exit)
  )
)
```

## Extract the Filename from the Last Argument

At this point, we make the assumption that the last argument (be it the second or third) contains the filename.

```wat
;; $ARGV_PTRS_PTR points to an array of size [$argc; i32] containing pointers to each command line arg
(call $wasi.args_get (global.get $ARGV_PTRS_PTR) (global.get $ARGV_BUF_PTR))
drop  ;; This is always 0, so ignore it

;; (call $write_args)

;; Fetch pointer to the filename (last pointer in the list)
(local.set $filename_ptr (call $fetch_arg_n (local.get $argc)))
(local.set $filename_len)

(i32.store (global.get $FILE_PATH_PTR)     (local.get $filename_ptr))
(i32.store (global.get $FILE_PATH_LEN_PTR) (local.get $filename_len))
```

Function `$fetch_arg_n` fetches the `n`th (one-based) argument from the `ARGV_BUFFER` the returns two values: a pointer the required argument, followed by its length.

These values are then stored at the locations held in the global pointer references `$FILE_PATH_PTR` and `$FILE_PATH_LEN_PTR`.
