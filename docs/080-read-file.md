# Step 8: Read the File

## Can We Process This File?

Now that we know how big the file is, we are in a position to decide whether WASM can process it.

In other words, is the file smaller than 4Gb?

```wat
(local $file_size_bytes i32)

;; SNIP

(if ;; the file size >= 4Gb
  (i64.ge_u (i64.load (global.get $FILE_SIZE_PTR)) (i64.const 4294967296))
  (then ;; pack up and go home because WASM cannot process a file that big...
    ;; (call $write_step (i32.const 2) (local.get $step) (i32.const 0x16)) ;; Return code 22 means file too large
    (call $writeln (i32.const 2) (global.get $ERR_FILE_TOO_LARGE) (i32.const 21))
    (br $exit)
  )
)

(local.set $file_size_bytes (i32.wrap_i64 (i64.load (global.get $FILE_SIZE_PTR)))) ;; We know the size < 4Gb
```

Now that we're happy the file size is less than 4Gb, we can store the file size in the local variable `$file_size_bytes`.
Notice however that the value returned by `(i64.load (global.get $FILE_SIZE_PTR))` is an `i64` but `$file_size_bytes` is an `i32`.
Since we're unable to process files larger than 4Gb, it is safe to downgrade the `i64` file size to an `i32`; hence the use of the `i32.wrap_i64` command.

## Read the File in 2Mb Chunks

Once all the preparation has been done, reading the file using WASI is actually very straight forward.

The Rust WASI implemention of [`fd_read`](https://github.com/bytecodealliance/wasmtime/blob/06377eb08a649619cc8ac9a934cb3f119017f3ef/crates/wasi-preview1-component-adapter/src/lib.rs#L1210) can be examined if desired, but the WebAssembly call is simply this:

```wat
(call $wasi_fd_read
  (local.get $fd_file)         ;; Descriptor of file being read
  (global.get $IOVEC_BUF_PTR)  ;; Pointer to iovec
  (i32.const 1)                ;; iovec count
  (global.get $IO_BYTES_PTR)   ;; Bytes read
)
```

In this case `$IOVEC_BUF_PTR` points to a single pair of pointers and the `iovec count` argument is `1`.

If we want to read into multiple IO vector buffers, we would supply subsequent pointer pairs, and set the `iovec_count` argument appropriately.

The `i32` at `$IOVEC_BYTES_PTR` will be updated to show the number of bytes read.

Assuming the read operation is successful, we are now almost ready to start calculating the SAH256 value.
