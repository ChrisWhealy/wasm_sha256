(module
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Import log functions
  (import "log" "msg_id" (func $msg_id (param i32 i32 i32)))

  ;; Import wasi_snapshot_preview1 function
  (import "wasi_snapshot_preview1" "path_open"
    (func $wasi_path_open (param i32 i32 i32 i32 i32 i64 i64 i32 i32) (result i32))
  )
  (import "wasi_snapshot_preview1" "fd_seek"
    (func $wasi_fd_seek (param i32 i64 i32 i32) (result i32))
  )
  (import "wasi_snapshot_preview1" "fd_read"
    (func $wasi_fd_read (param i32 i32 i32 i32) (result i32))
  )
  (import "wasi_snapshot_preview1" "fd_close"
    (func $wasi_fd_close (param i32) (result i32))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; WASI requires memory to be exported using the name "memory"
  ;; Depending on the size of the file being read, the number of memory pages might need to grow
  (memory $memory (export "memory") 2)

  ;; Irrespective of whether you want/need it, WASI always calls function "_start" when it starts the WASM module
  ;; In our particular case, this function serves no purpose
  (func (export "_start"))

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Memory map
  ;; For simplicity, file data is always written to the start of memory page 2.
  ;; Consequently, most of page 1 remains unused
  ;;
  ;; Page 1: 0x00000000 - 0x00000003 i32 file_fd
  ;;         0x00000008 - 0x0000000f i64 File size from fd_seek + 9
  ;;         0x00000010 - 0x00000013 i32 Pointer to iovec buffer
  ;;         0x00000014 - 0x00000017 i32 iovec buffer size
  ;;         0x00000018 - 0x0000001f i64 Bytes read by fd_read
  ;;         0x00000020 - 0x00000027
  ;;         0x00000028 - 0x0000002f i64 File size + 9 (Big endian)
  ;;         0x00000030 - 0x0000003f
  ;;         0x00000040 - 0x0000.... str File path name
  ;;
  ;; Page 2: 0x00010000 - 0xffffffff     File data (4Gb limit)
  (global $FD_FILE_PTR      i32 (i32.const 0))
  (global $FILE_SIZE_PTR    i32 (i32.const 8))   ;; Pointer to fd_seek file size (i64)
  (global $IOVEC_BUF_PTR    i32 (i32.const 16))  ;; Pointer iovec buffer (2 i32s)
  (global $BYTES_READ_PTR   i32 (i32.const 24))  ;; Pointer to bytes read by fd_read (i64)
  (global $FILE_SIZE_BE_PTR i32 (i32.const 40))  ;; Pointer to big endian file size (v128)

  (global $IOVEC_BUF_ADDR i32 (i32.const 65536)) ;; Memory location for file data

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Discover size of open file
  ;; Returns:
  ;;   i32 -> $wasi_fd_seek return code (0 = success)
  ;;   i64 -> File size in bytes
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $file_size
        (param $fd_file i32) ;; File fd (must already be open and have seek capability)
        (result i32 i64)

    (local $return_code     i32)
    (local $file_size_bytes i64)

    ;; Seek to the end of the file to determine size
    (local.tee $return_code
      (call $wasi_fd_seek
        (local.get $fd_file)
        (i64.const 0)  ;; Offset
        (i32.const 2)  ;; Whence = END
        (global.get $FILE_SIZE_PTR)
      )
    )

    ;; If reading the file size fails, then throw toys out of pram
    (if (then unreachable))

    ;; Remember file size
    (local.set $file_size_bytes (i64.load (global.get $FILE_SIZE_PTR)))
    (call $msg_id (i32.const 1) (i32.const 2) (i32.wrap_i64 (local.get $file_size_bytes)))

    ;; Reset file pointer back to the start
    (call $wasi_fd_seek
      (local.get $fd_file)
      (i64.const 0)  ;; Offset
      (i32.const 0)  ;; Whence = START
      (global.get $FILE_SIZE_PTR)
    )

    ;; If resetting the file pointer fails, then throw toys out of pram
    (if (then unreachable))

    ;; Write adjusted file size back at the expected location
    (i64.store (global.get $FILE_SIZE_PTR) (local.get $file_size_bytes))

    (local.get $return_code)
    (i64.load (global.get $FILE_SIZE_PTR))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; If necessary, grow memory to hold the file, then prepare iovec buffer with available buffer size
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $grow_memory
    (param $data_size_bytes i64)
    (local $size_diff i64)

    ;; size_diff = FILE_SIZE - (Memory pages * 64Kb)
    (local.set $size_diff
      (i64.sub
        (local.get $data_size_bytes)
        (i64.shl
          ;; Subtract 1 because the first memory page is not available for file data
          (i64.extend_i32_u (i32.sub (memory.size) (i32.const 1)))
          (i64.const 16)
        )
      )
    )

    ;; Is more memory needed?
    (if
      (i64.gt_s (local.get $size_diff) (i64.const 0))
      (then
        (memory.grow
          ;; Only rarely will the file size be an exact multiple of 64Kb, so arbitrarily add an extra memory page
          (i32.add
            ;; Convert size difference to 64Kb pages
            (i32.wrap_i64 (i64.shr_u (local.get $size_diff) (i64.const 16)))
            (i32.const 1)
          )
        )
        drop  ;; Don't care about previous number of memory pages
        (call $msg_id (i32.const 2) (i32.const 3) (memory.size))
      )
      (else
        (call $msg_id (i32.const 2) (i32.const 7) (memory.size))
      )
    )

    ;; Prepare the iovec buffer based on the new memory size
    ;; iovec data structure is 2, 32-bit words
    (i32.store (global.get $IOVEC_BUF_PTR) (global.get $IOVEC_BUF_ADDR)) ;; File data starts at $IOVEC_BUF_ADDR
    (i32.store
      (i32.add (global.get $IOVEC_BUF_PTR) (i32.const 4))             ;; Buffer start + 4
      (i32.shl (i32.sub (memory.size) (i32.const 1)) (i32.const 16))  ;; Buffer length = (memory.size - 1) * 65536
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Read contents of a file into memory
  ;; Returns:
  ;;   i32 -> Last step executed (success = reaching step 5)
  ;;   i32 -> Return code of last step executed (success = 0)
  ;;   i32 -> Pointer to iovec
  ;;   i64 -> File size in bytes
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $read_file
        (export "read_file")
        (param $fd_dir      i32) ;; File descriptor of directory preopened by WASI
        (param $path_offset i32) ;; Location of path name
        (param $path_len    i32) ;; Length of path name
        (result i32 i32 i32 i64)

    (local $step            i32)
    (local $return_code     i32)
    (local $fd_file         i32)
    (local $IOVEC_BUF_PTR   i32)
    (local $file_size_bytes i64)
    (local $msg_blk_count   i64)

    (block $exit
      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 0: Open file
      (local.tee $return_code
        (call $wasi_path_open
          (local.get $fd_dir)        ;; fd of preopened directory
          (i32.const 0)              ;; dirflags (no special flags)
          (local.get $path_offset)   ;; path (pointer to file path in memory)
          (local.get $path_len)      ;; path_len (length of the path string)
          (i32.const 0)              ;; oflags (O_RDONLY for reading)
          (i64.const 6)              ;; Base rights (RIGHTS_FD_READ 0x02 + RIGHTS_FD_SEEK 0x04)
          (i64.const 0)              ;; Inherited rights
          (i32.const 0)              ;; fs_flags (O_RDONLY)
          (global.get $FD_FILE_PTR)  ;; Write new file descriptor here
        )
      )

      ;; return code > 0?
      (if (then br $exit))
      ;; (call $msg_id (local.get $step) (i32.const 0) (local.get $return_code))

      ;; Pick up the file descriptor value
      (local.set $fd_file (i32.load (global.get $FD_FILE_PTR)))

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 1: Read file size
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.set $file_size_bytes (call $file_size (local.get $fd_file)))
      (local.tee $return_code)

      ;; return code > 0?
      (if (then br $exit))
      ;; (call $msg_id (local.get $step) (i32.const 0) (local.get $return_code))

      ;; Actual bytes needed for file data = file_size + 9
      ;; 1 byte for 0x80 end-of-data marker + 8 bytes for the file size as a big endian, 64-bit, unsigned integer
      (local.set $file_size_bytes (i64.add (local.get $file_size_bytes) (i64.const 9)))

      ;; If the file is larger than 4Gb, then pack up and go home because WASM cannot process a file that big
      (if
        (i64.gt_u (local.get $file_size_bytes) (i64.const 4294967296))
        (then
          (local.set $return_code (i32.const 22)) ;; 22 = "File too large"
          (br $exit)
        )
      )

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 2: Grow memory if the file is bigger than one memory page
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (call $grow_memory (local.get $file_size_bytes))
      ;; (call $msg_id (local.get $step) (i32.const 0) (local.get $return_code))

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 3: Read file contents
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.tee $return_code
        (call $wasi_fd_read
          (local.get $fd_file)         ;; Descriptor of file being read
          (global.get $IOVEC_BUF_PTR)  ;; Pointer to iovec
          (i32.const 1)                ;; iovec count
          (global.get $BYTES_READ_PTR) ;; Write bytes read here
        )
      )

      ;; return code > 0?
      (if (then br $exit))
      (call $msg_id (local.get $step) (i32.const 4) (global.get $BYTES_READ_PTR))

      ;; Swizzle the byte order of the i64 file size into big endian format
      (v128.store
        (global.get $FILE_SIZE_BE_PTR)
        (i8x16.swizzle
          (v128.load (global.get $FILE_SIZE_PTR))
          (v128.const i8x16 7 6 5 4 3 2 1 0 15 14 13 12 11 10 9 8)
        )
      )

      ;; Write end-of-data marker immediately after file data
      (i32.store8
        ;; Since the file size cannot exceed 4Gb, it is safe to read only the first 32 bits of the file size
        (i32.add (global.get $IOVEC_BUF_ADDR) (i32.load (global.get $FILE_SIZE_PTR)))
        (i32.const 0x80)
      )
      (call $msg_id
        (local.get $step)
        (i32.const 8)
        (i32.add (global.get $IOVEC_BUF_ADDR) (global.get $FILE_SIZE_PTR))
      )

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 4: Calculate number of 64 byte chunks
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.set
        $msg_blk_count
        (i64.shr_u (i64.load (global.get $BYTES_READ_PTR)) (i64.const 6))
      )
      ;; (call $msg_id (local.get $step) (i32.const 0) (local.get $return_code))

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 5: Close file
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.set $return_code (call $wasi_fd_close (local.get $fd_file)))
      ;; (call $msg_id (local.get $step) (i32.const 0) (local.get $return_code))
    )

    (local.get $step)
    (local.get $return_code)
    (global.get $IOVEC_BUF_PTR)
    (local.get $file_size_bytes)
  )
)
