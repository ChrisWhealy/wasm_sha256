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
(After the read operation has completed, we will get back a number of bytes ranging from zero up to the size of the read buffer)

```wat
(i32.store          (global.get $IOVEC_READ_BUF_PTR) (global.get $READ_BUFFER_PTR))
(i32.store offset=4 (global.get $IOVEC_READ_BUF_PTR) (global.get $READ_BUFFER_SIZE)) ;; Wasmer upper limit = 2Mb
```

> ***IMPORTANT***<br>
> Some WebAssembly frameworks allow you to set the read buffer size equal to the file size.
> This means that in a single call to `$wasi.fd_read` you will retrieve the entire file (assuming of course you have allocated enough memory to hold the file).
>
> However, `wasmer` imposes a 2Mb size limit on the read buffer meaning that specifying a buffer size greater than this is simply truncated to 2Mb.
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

How we proceed next depends on whether or not the read buffer is full.

### The Buffer is Full

If the read buffer is full, then most likely there is more data left on disk to process after we're done processing this buffer.
Therefore, we know that we will need to process at least `div($READ_BUFFER_SIZE, 64)` message blocks; hence the following statement:

```wat
;; We will need to process at least this many message blocks
(local.set $msg_blk_count (global.get $MSG_BLKS_PER_BUFFER))
```

However, there is an edge case in which the file size is an exact integer multiple of the read buffer size.
If this is the case, then at the same time we hit EOF, the read buffer will also be completely full.

Hence the test that says "_If the read buffer is full ***and*** `$bytes_remaining == 0`_", then we've hit EOF.

When we hit this edge case, we need to increment `$msg_blk_count` because we need to create one more message block that contains just the end-of-data marker (`0x80`) and have the file size in bits written as a 64-bit, unsigned integer to the last 8 bytes of the last message block &mdash; in big endian format.

The `then` side of this conditions shown below handles the possibility of this edge case:

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
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (else ;; we've just read zero or more bytes
    ;; SNIP
  )

  ;; SNIP
)
```

### The Buffer is Not Full

If the read buffer is not full, then we know two things:

1. We must have hit EOF
2. The read buffer contains at least one spare byte, so we can immediately write the end-of-data marker to the byte following the last data byte.

The `else` clause of the condition shown above itself contains a condition to test whether we've read zero or more than zero bytes.

If we've read zero bytes, then `$wasi.fd_read` has hit EOF and we're done &mdash; so that's easy.

The last situation to handle is where we have a partially full buffer.

Here, we need to:
* Write the EOD marker.
* Calculate how many message blocks will be needed to contain the data in the read buffer.
* Check whether there's enough space in the last message block to hold the 8-byte file length, or do we need to allocate an extra message block.
* If an extra message block is needed, bump the message block counter, initialisise an extra message block, then write the file size at the end.

This functionality is all covered by the inner `then` clause shown below.

```wat
(else ;; we've just read zero or more bytes
  (if ;; we've read more than zero bytes
    (local.get $bytes_read) ;; > 0
    (then ;; we're about to process the last chunk
      (call $write_eod_marker (local.tee $eod_offset (local.get $bytes_read)))

      ;; Add length of EOD marker + 8-byte file size
      (local.set $bytes_read    (i32.add   (local.get $bytes_read) (i32.const 9)))
      (local.set $msg_blk_count (i32.shr_u (local.get $bytes_read) (i32.const 6)))

      ;; Will the 9 extra bytes fit in the current message block?
      (if ;; $msg_blk_count == 0 || $bytes_read - ($msg_blk_count * 64) > 0
        (i32.or
          ;; $msg_blk_count will be zero if the file size is < 64 bytes
          (i32.eqz (local.get $msg_blk_count))
          (i32.gt_s
            (i32.sub (local.get $bytes_read) (i32.shl (local.get $msg_blk_count) (i32.const 6)))
            (i32.const 0)
          )
        )
        (then ;; we require an extra message block
          (local.set $msg_blk_count (i32.add (local.get $msg_blk_count) (i32.const 1)))
        )
      )

      ;; Distance from EOD marker to end of last message block = ($msg_blk_count * 64) - $eod_offset - 1
      (local.tee $distance_to_eob
        (i32.sub
          (i32.sub
            (i32.shl (local.get $msg_blk_count) (i32.const 6))
            (local.get $eod_offset)
          )
          (i32.const 1)
        )
      )

      (if ;; the distance is > 0
        (then
          (memory.fill
            ;; Don't overwrite the EOD marker!
            (i32.add (global.get $READ_BUFFER_PTR) (i32.add (local.get $eod_offset) (i32.const 1)))
            (i32.const 0)
            (local.get $distance_to_eob)
          )
        )
      )

      (call $write_file_size (local.get $msg_blk_count))
    )
    ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    (else ;; fd_read returned 0 bytes, so we're done
      (br $process_file)
    )
  )
)

```

## We Now Know How Many Message Blocks the Read Buffer Contains

Based on the amount of data in the read buffer and whether or not we've hit EOF, the above code really does only two things:

1. It calculates the integer number of 64-byte message blocks the data in the read buffer represents.
2. If we've hit EOF, then potentially, an extra message block needs to be created and populated with the relevant termination values.

Once all that has been done, we can perform (or continue performing) the SHA256 hash calculation on the message blocks in the read buffer.

```wat
;; Continue the hash calculation on the available message blocks
(local.set $blk_ptr (global.get $READ_BUFFER_PTR))

(loop $next_msg_blk
  ;; (call $hexdump (i32.const 1) (local.get $blk_ptr))
  (call $sha_phase_1 (i32.const 48) (local.get $blk_ptr) (global.get $MSG_DIGEST_PTR))
  (call $sha_phase_2 (i32.const 64))

  (local.set $blk_ptr (i32.add (local.get $blk_ptr) (i32.const 64)))

  (br_if $next_msg_blk
    (local.tee $msg_blk_count (i32.sub (local.get $msg_blk_count) (i32.const 1)))
  )
)

;; Keep reading until we hit EOF
(br_if $read_file_chunk (local.get $bytes_read))
```

I have already documented the details of how the SHA256 hash is calculated here <https://awesome.red-badger.com/chriswhealy/sha256-webassembly>


Keep doing this until `$bytes_read` contains zero.
