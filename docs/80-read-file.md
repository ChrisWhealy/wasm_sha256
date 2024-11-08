# Step 8: Read the File

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
