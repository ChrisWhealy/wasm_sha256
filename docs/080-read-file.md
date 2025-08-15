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

Now that we're happy the file is snaller than 4Gb, we can store the file size in the local variable `$file_size_bytes`.
Notice however that the value returned by `(i64.load (global.get $FILE_SIZE_PTR))` is an `i64` but `$file_size_bytes` is an `i32`.
Since we're unable to process files larger than 4Gb, it is safe to downgrade the `i64` file size to an `i32`; hence the use of the `i32.wrap_i64` command.

## Read the File in 2Mb Chunks

The `wasmtime` Rust implemention of [`fd_read`](https://github.com/bytecodealliance/wasmtime/blob/06377eb08a649619cc8ac9a934cb3f119017f3ef/crates/wasi-preview1-component-adapter/src/lib.rs#L1210) is informative.

The pointer `$IOVEC_READ_BUF_PTR` points to a pair of `i32` values.

The first `i32` is a pointer to the location in memory where the data read from the file should be written, and the second `i32` is the size of the read buffer.

```wat
(i32.store          (global.get $IOVEC_READ_BUF_PTR) (global.get $READ_BUFFER_PTR))
(i32.store offset=4 (global.get $IOVEC_READ_BUF_PTR) (global.get $READ_BUFFER_SIZE)) ;; Wasmer upper limit = 2Mb
```

> ***IMPORTANT***<br>
> Some WebAssembly frameworks allow you to set the read buffer size equal to the file size.
> This means that in a single call to `$wasi.fd_read` you will retrieve the entire file (assuming of course you have allocated enough memory to hold the file).
>
> However, `wasmer` imposes a 2Mb size limit on the read buffer; so specifying a read buffer size greater than 2Mb has no effect.
> Hence, this program has had to be modified to account for this behaviour.

Calls to `$wasi.fd_read` now happen inside a named block called `$process_file` within which is a loop called `$read_file_chunk`.

```wat
(block $process_file
  (loop $read_next_chunk
    (local.tee $return_code
      (call $wasi.fd_read
        (local.get $file_fd)
        (global.get $IOVEC_READ_BUF_PTR)
        (i32.const 1)
        (global.get $NREAD_PTR)
      )
    )

    (if ;; $return_code > 0
      (then
        ;; (call $write_step (i32.const 2) (local.get $step) (local.get $return_code))
        (call $writeln (i32.const 2) (global.get $ERR_READING_FILE) (i32.const 18))
        (br $exit)
      )
    )

    ;; SNIP
  )
)
```

After each read, the return code should always be checked.

## Process the Contents of the Read Buffer

Assuming `$wasi.fd_read` gave a return code of zero, calculate both the `$bytes_read` and the `$bytes_remaining`.
This can be done by nesting a call to `local.tee` (that assigns a value to `$bytes_read` then leaves that value on the stack) inside the calculation of `$bytes_remaining`.

```wat
(local.set $bytes_remaining
  (i32.sub
    (local.get $bytes_remaining)
    (local.tee $bytes_read (i32.load (global.get $NREAD_PTR)))
  )
)
```

How we proceed here depends on whether or not the read buffer is full.

If it is full, then most likely there is more data left on disk to process after we're done with thios one.

At this point, we know that we will need to process at least `div($READ_BUFFER_SIZE, 64)` message blocks; hence the following statement:

```wat
;; We will need to process at least this many message blocks
(local.set $msg_blk_count (global.get $MSG_BLKS_PER_BUFFER))
```

However, there is an edge case in which the file size is an exact integer multiple of the read buffer size.
If this is the case, then at the same time we hit EOF, the read buffer will also be completely full.

Hence the test that says "_If the read buffer is full ***and*** `$bytes_remaining == 0`_", then we've hit EOF.

When we hit this edge case, we need to increment `$msg_blk_count` because we need to create one more message block tha contains just the end-of-data marker (`0x80`) and have the file size in bits written as a 64-bit, unsigned integer to the last 8 bytes of the last message block &mdash; in big endian format.

```wat
(if ;; the read buffer is full
  (i32.eq (local.get $bytes_read) (global.get $READ_BUFFER_SIZE))
  (then ;; check for the edge case in which the file size is an exact integer multiple of the read buffer size
    ;; (call $write_msg (i32.const 1) (global.get $DBG_FULL_BUFFER) (i32.const 22))

    ;; We will need to process at least this many message blocks
    (local.set $msg_blk_count (global.get $MSG_BLKS_PER_BUFFER))

    (if ;; we've hit the edge case where the file size is an exact integer multiple of the buffer size
      (i32.eqz (local.get $bytes_remaining))
      (then ;; an extra message block will be needed containing only the termination values
        (local.set $msg_blk_count (i32.add (local.get $msg_blk_count) (i32.const 1)))

        ;; Initialise the extra message block
        (memory.fill
          (i32.add (global.get $READ_BUFFER_PTR) (global.get $READ_BUFFER_SIZE))
          (i32.const 0)
          (i32.const 64)
        )

        (call $write_eod_marker (global.get $READ_BUFFER_SIZE))
        (call $write_file_size  (local.get $msg_blk_count))
      )
    )
  )

  ;; SNIP
)
```
