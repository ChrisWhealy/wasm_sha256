(module
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Import logging functions
  (import "log" "msg_id"
    (func $log_msg_id (param i32) (param i32) (param i32)) ;; Step number, message id, log value
  )

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
  ;; In this particular case, this function serves no purpose; however, it must be present
  (func (export "_start"))

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Memory map
  ;; For simplicity, file data is always written to the start of memory page 2.
  ;; Consequently, most of page 1 remains unused
  ;;
  ;; Page 1: 0x00000000 i32 file_fd
  ;;         0x00000008 i64 File size from fd_seek
  ;;         0x00000010 i32 Pointer to iovec buffer
  ;;         0x00000014 i32 iovec buffer size
  ;;         0x00000018 i32 Bytes read by fd_read
  ;;
  ;; Page 2: 0x00010000     File data
  (global $FD_FILE_PTR    i32 (i32.const 0))
  (global $FILE_SIZE_PTR  i32 (i32.const 8))     ;; Pointer to fd_seek file size
  (global $IOVEC_BUF_PTR  i32 (i32.const 16))    ;; Pointer iovec buffer (2 i32s)
  (global $BYTES_READ_PTR i32 (i32.const 24))    ;; Pointer to bytes read by fd_read

  (global $IOVEC_BUF_ADDR i32 (i32.const 65536)) ;; Memory location for file data

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Open a file with read and seek rights
  ;; Returns:
  ;;   i32 -> $wasi_path_open return code (0 = success)
  ;;   i32 -> Pointer to file descriptor
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $path_open
        (export "path_open")
        (param $fd_dir      i32) ;; File descriptor of preopened directory openend by WASI
        (param $path_offset i32) ;; Location of path name
        (param $path_len    i32) ;; Length of path name
        (param $step        i32) ;; Step counter
        (result i32 i32)

    (local $return_code i32)

    ;; Attempt to open file
    (local.set $return_code
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

    (call $log_msg_id (local.get $step) (i32.const 1) (i32.load (global.get $FD_FILE_PTR)))
    (call $log_msg_id (local.get $step) (i32.const 0) (local.get $return_code))

    (local.get $return_code)
    (global.get $FD_FILE_PTR)
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Discover size of open file
  ;; Returns:
  ;;   i32 -> $wasi_fd_seek return code (0 = success)
  ;;   i64 -> File size in bytes
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $file_size
        (export "file_size")
        (param $fd_file i32) ;; File fd (must already be open and have seek capability)
        (param $step    i32) ;; Step counter
        (result i32 i64)

    (local $return_code i32)
    (local $file_size   i64)

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
    (local.set $file_size (i64.load (global.get $FILE_SIZE_PTR)))

    ;; Reset file pointer back to the start
    (call $wasi_fd_seek
      (local.get $fd_file)
      (i64.const 0)  ;; Offset
      (i32.const 0)  ;; Whence = START
      (global.get $FILE_SIZE_PTR)
    )

    ;; If resetting the file pointer fails, then throw toys out of pram
    (if (then unreachable))

    ;; Write the file size back at the expected location
    (i64.store (global.get $FILE_SIZE_PTR) (local.get $file_size))

    (call $log_msg_id (local.get $step) (i32.const 2) (i32.wrap_i64 (i64.load (global.get $FILE_SIZE_PTR))))
    (call $log_msg_id (local.get $step) (i32.const 0) (local.get $return_code))

    (local.get $return_code)
    (local.get $file_size)
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; If necessary, grow memory to hold the file.
  ;; Prepare iovec buffer with available buffer size
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $grow_memory
        (export "grow_memory")
        (param $step i32)

    (local $size_diff i64)

    ;; Memory before growing
    (call $log_msg_id (local.get $step) (i32.const 3) (memory.size))

    ;; size_diff = FILE_SIZE - (Memory pages * 64Kb)
    (local.set $size_diff
      (i64.sub
        (i64.load (global.get $FILE_SIZE_PTR))
        ;; The first memory page is not available for file data
        (i64.shl
          (i64.extend_i32_u (i32.sub (memory.size) (i32.const 1)))
          (i64.const 16)
        )
      )
    )

    ;; Is more memory needed?
    (block $exit
      (if
        (i64.gt_s (local.get $size_diff) (i64.const 0))
        (then
          (memory.grow
            ;; Convert size difference to 64Kb pages
            ;; Only rarely will the file size be an exact multiple of 64Kb, so add an extra page
            (i32.add (i32.wrap_i64 (i64.shr_u (local.get $size_diff) (i64.const 16))) (i32.const 1))
          )
          drop  ;; Don't care about previous number of memory pages
        )
        (else
          (call $log_msg_id (local.get $step) (i32.const 7) (memory.size))
          (br $exit)
        )
      )

      ;; Memory after growing
      (call $log_msg_id (local.get $step) (i32.const 3) (memory.size))

      ;; Prepare the iovec buffer based on the new memory size
      ;; iovec data structure is 2, 32-bit words
      (i32.store (global.get $IOVEC_BUF_PTR) (global.get $IOVEC_BUF_ADDR)) ;; File data starts at $IOVEC_BUF_ADDR
      (i32.store
        (i32.add (global.get $IOVEC_BUF_PTR) (i32.const 4))             ;; Buffer start + 4
        (i32.shl (i32.sub (memory.size) (i32.const 1)) (i32.const 16))  ;; Buffer length = (memory.size - 1) * 65536
      )

      (call $log_msg_id (local.get $step) (i32.const 5) (i32.wrap_i64 (i64.load (global.get $IOVEC_BUF_PTR))))
      (call $log_msg_id
        (local.get $step)
        (i32.const 6)
        (i32.wrap_i64
          (i64.load (i32.add (global.get $IOVEC_BUF_PTR) (i32.const 4)))
        )
      )
    ) ;; Block $exit
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Read all the data from the open file descriptor into memory
  ;; Returns:
  ;;   i32 -> $wasi_fd_read return code (0 = success)
  ;;   i32 -> iovec_buf_ptr
  ;;   i64 -> Bytes read
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $file_read
        (export "file_read")
        (param $fd_file i32) ;; Opened file fd
        (param $step    i32) ;; Step counter
        (result i32 i32 i64)

    (local $return_code i32)

    ;; Attempt to read file
    (local.set $return_code
      (call $wasi_fd_read
        (local.get $fd_file)         ;; Descriptor of file being read
        (global.get $IOVEC_BUF_PTR)  ;; Pointer to iovec
        (i32.const 1)                ;; iovec count
        (global.get $BYTES_READ_PTR) ;; Write bytes read here
      )
    )

    (call $log_msg_id (local.get $step) (i32.const 4) (i32.wrap_i64 (i64.load (global.get $BYTES_READ_PTR))))
    (call $log_msg_id (local.get $step) (i32.const 0) (local.get $return_code))

    (local.get $return_code)
    (global.get $IOVEC_BUF_PTR)
    (i64.load (global.get $BYTES_READ_PTR))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Read contents of a file into memory and return the file size in bytes
  ;; Returns:
  ;;   i32 -> Last step executed
  ;;   i32 -> Return code of last step executed (0 = success)
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

    (block $exit
      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 0: Open file
      (call $path_open
        (local.get $fd_dir)
        (local.get $path_offset)
        (local.get $path_len)
        (local.get $step)
      )
      drop ;; The file fd already exists at $FD_FILE_PTR
      (local.tee $return_code)

      ;; return code > 0?
      (if (then br $exit))

      ;; Pick up the file descriptor value
      (local.set $fd_file (i32.load (global.get $FD_FILE_PTR)))

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 1: Read file size
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.set $file_size_bytes
        (call $file_size
          (local.get $fd_file)
          (local.get $step)
        )
      )
      (local.tee $return_code)

      ;; return code > 0?
      (if (then br $exit))

      ;; If the file is larger than 4Gb, then WASM cannot process it
      (if
        (i64.gt_u
          (i64.load (global.get $FILE_SIZE_PTR))
          (i64.const 4294967296)
        )
        (then
          (local.set $return_code (i32.const 22)) ;; 22 = "File too large"
          (br $exit)
        )
      )

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 2: Grow memory?
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (call $grow_memory (local.get $step))

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 3: Read file contents
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (call $file_read (local.get $fd_file) (local.get $step))
      drop ;; Not interested in the number of bytes read since we already know this
      drop ;; Not interested iovec_buf_ptr since its a global
      (local.tee $return_code)

      ;; return code > 0?
      (if (then br $exit))

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 3: Close file
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.set $return_code (call $wasi_fd_close (local.get $fd_file)))
    )

    (local.get $step)
    (local.get $return_code)
    (global.get $IOVEC_BUF_PTR)
    (local.get $file_size_bytes)
  )
)
