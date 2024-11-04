(module
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Import log functions
  (import "log" "msg" (func $log_msg (param i32 i32 i32)))

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
  ;; WASI requires the WASM module to export memory using the name "memory"
  (memory $memory (export "memory") 2)

  ;; Memory Map
  ;; Page 1: 0x00000000 - 0x00000003  i32    file_fd
  ;;         0x00000008 - 0x0000000f  i64    File size from fd_seek + 9
  ;;         0x00000010 - 0x00000013  i32    Pointer to iovec buffer
  ;;         0x00000014 - 0x00000017  i32    iovec buffer size
  ;;         0x00000018 - 0x0000001f  i64    Bytes read by fd_read
  ;;         0x00000020 - 0x00000027  i64    File size (Big endian)
  ;;         0x00000028 - 0x0000002f
  ;;         0x00000030 - 0x00000037  i64    File size (Little endian)
  ;;         0x00000038 - 0x0000003f
  ;;         0x00000040 - 0x000000ff  str    File path name written by host
  ;;         0x00000100 - 0x0000011F  data   Constants - fractional part of square root of first 8 primes
  ;;         0x00000120 - 0x0000021F  data   Constants - fractional part of cube root of first 64 primes
  ;;         0x00000220 - 0x0000023F  i32x8  Hash values
  ;;         0x00000260 - 0x0000043F         512 byte message digest
  (global $FD_FILE_PTR        i32 (i32.const 0x00000000))
  (global $FILE_SIZE_PTR      i32 (i32.const 0x00000008))
  (global $IOVEC_BUF_PTR      i32 (i32.const 0x00000010))
  (global $BYTES_READ_PTR     i32 (i32.const 0x00000018))
  (global $FILE_SIZE_BE_PTR   i32 (i32.const 0x00000020))
  (global $FILE_SIZE_LE_PTR   i32 (i32.const 0x00000030))
  (global $INIT_HASH_VALS_PTR i32 (i32.const 0x00000100))
  (global $CONSTANTS_PTR      i32 (i32.const 0x00000120))
  (global $HASH_VALS_PTR      i32 (i32.const 0x00000220))
  (global $MSG_DIGEST_PTR     i32 (i32.const 0x00000260))

  ;; Memory map
  ;; Page 2: 0x00010000 - 0xffffffff     File data (4Gb limit)
  (global $IOVEC_BUF_ADDR     i32 (i32.const 0x00010000))

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; The first 32 bits of the fractional parts of the square roots of the first 8 primes 2..19
  ;; Used to initialise the hash values
  ;; Values below are in little-endian byte order!
  (data (i32.const 0x000100)    ;; $INIT_HASH_VALS_PTR
    "\67\E6\09\6A" "\85\AE\67\BB" "\72\F3\6E\3C" "\3A\F5\4F\A5"  ;; 0x00000100
    "\7F\52\0E\51" "\8C\68\05\9B" "\AB\D9\83\1F" "\19\CD\E0\5B"  ;; 0x00000110
  )

  ;; The first 32 bits of the fractional parts of the cube roots of the first 64 primes 2..311
  ;; Used in phase 2 (hash value calculation)
  ;; Values below are in little-endian byte order!
  (data (i32.const 0x000120)    ;; $CONSTANTS_PTR
    "\98\2F\8A\42" "\91\44\37\71" "\CF\FB\C0\B5" "\A5\DB\B5\E9"  ;; 0x00000120
    "\5B\C2\56\39" "\F1\11\F1\59" "\A4\82\3F\92" "\D5\5E\1C\AB"  ;; 0x00000130
    "\98\AA\07\D8" "\01\5B\83\12" "\BE\85\31\24" "\C3\7D\0C\55"  ;; 0x00000140
    "\74\5D\BE\72" "\FE\B1\DE\80" "\A7\06\DC\9B" "\74\F1\9B\C1"  ;; 0x00000150
    "\C1\69\9B\E4" "\86\47\BE\EF" "\C6\9D\C1\0F" "\CC\A1\0C\24"  ;; 0x00000160
    "\6F\2C\E9\2D" "\AA\84\74\4A" "\DC\A9\B0\5C" "\DA\88\F9\76"  ;; 0x00000170
    "\52\51\3E\98" "\6D\C6\31\A8" "\C8\27\03\B0" "\C7\7F\59\BF"  ;; 0x00000180
    "\F3\0B\E0\C6" "\47\91\A7\D5" "\51\63\CA\06" "\67\29\29\14"  ;; 0x00000190
    "\85\0A\B7\27" "\38\21\1B\2E" "\FC\6D\2C\4D" "\13\0D\38\53"  ;; 0x000001A0
    "\54\73\0A\65" "\BB\0A\6A\76" "\2E\C9\C2\81" "\85\2C\72\92"  ;; 0x000001B0
    "\A1\E8\BF\A2" "\4B\66\1A\A8" "\70\8B\4B\C2" "\A3\51\6C\C7"  ;; 0x000001C0
    "\19\E8\92\D1" "\24\06\99\D6" "\85\35\0E\F4" "\70\A0\6A\10"  ;; 0x000001D0
    "\16\C1\A4\19" "\08\6C\37\1E" "\4C\77\48\27" "\B5\BC\B0\34"  ;; 0x000001E0
    "\B3\0C\1C\39" "\4A\AA\D8\4E" "\4F\CA\9C\5B" "\F3\6F\2E\68"  ;; 0x000001F0
    "\EE\82\8F\74" "\6F\63\A5\78" "\14\78\C8\84" "\08\02\C7\8C"  ;; 0x00000200
    "\FA\FF\BE\90" "\EB\6C\50\A4" "\F7\A3\F9\BE" "\F2\78\71\C6"  ;; 0x00000210
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Irrespective of whether you want/need it, WASI always calls function "_start" when it starts the WASM module
  ;; In our particular case, this function serves no purpose
  (func (export "_start"))

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
    ;; (call $log_msg (i32.const 1) (i32.const 2) (i32.wrap_i64 (local.get $file_size_bytes)))

    ;; Reset file pointer back to the start
    (call $wasi_fd_seek
      (local.get $fd_file)
      (i64.const 0)  ;; Offset
      (i32.const 0)  ;; Whence = START
      (global.get $FILE_SIZE_PTR)
    )

    ;; If resetting the file pointer fails, then throw toys out of pram
    (if (then unreachable))

    ;; Write file size back at the expected location
    (i64.store (global.get $FILE_SIZE_PTR) (local.get $file_size_bytes))

    (local.get $return_code)
    (i64.load (global.get $FILE_SIZE_PTR))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; If necessary, grow memory to hold the file, then update the global iovec buffer with buffer address and size
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
            ;; Convert size difference to 64Kb message blocks
            (i32.wrap_i64 (i64.shr_u (local.get $size_diff) (i64.const 16)))
            (i32.const 1)
          )
        )
        drop  ;; Don't care about previous number of memory pages
        ;; (call $log_msg (i32.const 2) (i32.const 3) (memory.size))
      )
      ;; (else
      ;;   (call $log_msg (i32.const 2) (i32.const 7) (memory.size))
      ;; )
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
  ;;   i32 -> Last step executed (success = reaching step 5)   (Only needed during development)
  ;;   i32 -> Return code of last step executed (success = 0)  (Only needed during development)
  ;;   i32 -> 64-byte message block count
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $read_file
        (param $fd_dir      i32) ;; File descriptor of directory preopened by WASI
        (param $path_offset i32) ;; Location of path name
        (param $path_len    i32) ;; Length of path name

        ;; (result i32 i32 i32)    ;; Extra result values only needed during development
        (result i32)

    ;; (local $step            i32)  ;; Only used during development
    (local $return_code     i32)
    (local $fd_file         i32)
    (local $IOVEC_BUF_PTR   i32)
    (local $msg_blk_count   i32)
    (local $file_size_bytes i64)
    (local $file_size_bits  i64)

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

      ;; Return code > 0?
      (if (then br $exit))
      ;; (call $log_msg (local.get $step) (i32.const 0) (local.get $return_code))

      ;; Pick up the file descriptor value
      (local.set $fd_file (i32.load (global.get $FD_FILE_PTR)))

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 1: Read file size
      ;; (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.set $file_size_bytes (call $file_size (local.get $fd_file)))
      (local.tee $return_code)

      ;; Return code > 0?
      (if (then br $exit))
      ;; (call $log_msg (local.get $step) (i32.const 0) (local.get $return_code))

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
      ;; (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (call $grow_memory (local.get $file_size_bytes))
      ;; (call $log_msg (local.get $step) (i32.const 0) (local.get $return_code))

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 3: Read file contents
      ;; (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.tee $return_code
        (call $wasi_fd_read
          (local.get $fd_file)         ;; Descriptor of file being read
          (global.get $IOVEC_BUF_PTR)  ;; Pointer to iovec
          (i32.const 1)                ;; iovec count
          (global.get $BYTES_READ_PTR) ;; Write bytes read here
        )
      )

      ;; Return code > 0?
      (if (then br $exit))
      ;; (call $log_msg (local.get $step) (i32.const 4) (global.get $BYTES_READ_PTR))

      ;; Write end-of-data marker immediately after file data
      (i32.store8
        ;; Since the file size cannot exceed 4Gb, it is safe to read only the first 32 bits of the file size
        (i32.add (global.get $IOVEC_BUF_ADDR) (i32.load (global.get $FILE_SIZE_PTR)))
        (i32.const 0x80)
      )

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 4: Calculate number of 64 byte message blocks
      ;; (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.set $msg_blk_count (i32.wrap_i64 (i64.shr_u (local.get $file_size_bytes) (i64.const 6))))

      ;; Do we need to allocate an extra message block?
      (if
        (i64.gt_u
          (i64.sub
            (local.get $file_size_bytes)
            (i64.shl (i64.extend_i32_u (local.get $msg_blk_count)) (i64.const 6))
          )
          (i64.const 0)
        )
        (then (local.set $msg_blk_count (i32.add (local.get $msg_blk_count) (i32.const 1))))
      )
      ;; (call $log_msg (local.get $step) (i32.const 2) (i32.wrap_i64 (local.get $file_size_bytes)))
      ;; (call $log_msg (local.get $step) (i32.const 9) (local.get $msg_blk_count))

      ;; Convert file size in bytes to size in bits
      (i64.store (global.get $FILE_SIZE_PTR) (i64.shl (i64.load (global.get $FILE_SIZE_PTR)) (i64.const 3)))

      ;; Swizzle the byte order of the file size into big endian format
      (v128.store
        (global.get $FILE_SIZE_BE_PTR)
        (i8x16.swizzle
          (v128.load (global.get $FILE_SIZE_PTR))
          (v128.const i8x16 7 6 5 4 3 2 1 0 15 14 13 12 11 10 9 8)
        )
      )

      ;; Write big endian file size to the last 8 bytes of the last message block
      ;; File size byte address = $IOVEC_BUF_ADDR + ($msg_blk_count * 64) - 8
      (i64.store
        (i32.sub
          (i32.add
            (global.get $IOVEC_BUF_ADDR)
            (i32.shl (local.get $msg_blk_count) (i32.const 6))
          )
          (i32.const 8)
        )
        (i64.load (global.get $FILE_SIZE_BE_PTR))
      )
      ;; (call $log_msg (local.get $step) (i32.const 0) (local.get $return_code))

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 5: Close file
      ;; (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.set $return_code (call $wasi_fd_close (local.get $fd_file)))
      ;; (call $log_msg (local.get $step) (i32.const 0) (local.get $return_code))
    )

    ;; (local.get $step)         ;; Step counter and step return code only used for debugging purposes
    ;; (local.get $return_code)
    (local.get $msg_blk_count)
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Generic sigma value of argument $val
  ;; sigma = rotr($w2, $rotr1)  XOR rotr($w2, $rotr2) XOR shr_u($w2, $shr)
  ;;
  ;; Returns:
  ;;   i32 -> Twiddled value
  (func $sigma
        (param $val   i32)  ;; Raw binary value
        (param $rotr1 i32)  ;; ROTR twiddle factor 1
        (param $rotr2 i32)  ;; ROTR twiddle factor 2
        (param $shr   i32)  ;; SHR twiddle factor
        (result i32)

    (i32.xor
      (i32.xor
        (i32.rotr (local.get $val) (local.get $rotr1))
        (i32.rotr (local.get $val) (local.get $rotr2))
      )
      (i32.shr_u (local.get $val) (local.get $shr))
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Calculate the big sigma value of argument $val
  ;;
  ;; Returns:
  ;;   i32 -> Twiddled value
  (func $big_sigma
        (param $val   i32)  ;; Raw binary value
        (param $rotr1 i32)  ;; ROTR twiddle factor 1
        (param $rotr2 i32)  ;; ROTR twiddle factor 2
        (param $rotr3 i32)  ;; ROTR twiddle factor 3
        (result i32)

    (i32.xor
      (i32.xor
        (i32.rotr (local.get $val) (local.get $rotr1))
        (i32.rotr (local.get $val) (local.get $rotr2))
      )
      (i32.rotr (local.get $val) (local.get $rotr3))
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Calculate the message digest word at byte offset $ptr using the four words found at the earlier offsets.
  ;; All data must be treated as raw binary:
  ;;
  ;; $w1 = word_at($ptr - (4 * 16))
  ;; $w2 = word_at($ptr - (4 * 15))
  ;; $w3 = word_at($ptr - (4 * 7))
  ;; $w4 = word_at($ptr - (4 * 2))
  ;;
  ;; Returns:
  ;;   i32 -> One word of the message digest
  (func $gen_msg_digest_word
        (param $ptr i32)
        (result i32)

    ;; Result = $w1 + $sigma($w2, 7, 8, 13) + $w3 + $sigma($w4, 17, 19, 10)
    (i32.add
      (i32.add
        (i32.load (i32.sub (local.get $ptr) (i32.const 64)))    ;; word_at($ptr - 16 words)
        (call $sigma                                            ;; Calculate sigma0
          (i32.load (i32.sub (local.get $ptr) (i32.const 60)))  ;; word_at($ptr - 15 words)
          (i32.const 7) (i32.const 18) (i32.const 3)            ;; ROTR twiddle factors
        )
      )
      (i32.add
        (i32.load (i32.sub (local.get $ptr) (i32.const 28)))   ;; word_at($ptr - 7 words)
        (call $sigma                                           ;; Calculate sigma1
          (i32.load (i32.sub (local.get $ptr) (i32.const 8)))  ;; word_at($ptr - 2 words)
          (i32.const 17) (i32.const 19) (i32.const 10)         ;; ROTR and SHR twiddle factors
        )
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Phase 1: Create message digest
  ;; * Populate words 0..15 of the message digest using the next 64 bytes of the message block
  ;; * Populate words 16..63 of the message digest based on words 0..15
  ;;
  ;; For testing purposes, the number of loop iterations was not hard-coded to 48 but was was parameterized so it can be
  ;; run just $n times
  ;;
  ;; Returns: None
  (func $phase_1
    (param $n           i32)
    (param $blk_ptr     i32)
    (param $msg_blk_ptr i32)

    (local $ptr i32)

    ;; Transfer the next 64 bytes from the message block to words 0..15 of the message digest as raw binary.
    (loop $next_msg_sched_vec
      (v128.store
        (i32.add (local.get $msg_blk_ptr) (local.get $ptr))
        ;; Use swizzle to swap big-endian byte order to little-endian
        (i8x16.swizzle
          (v128.load (i32.add (local.get $blk_ptr) (local.get $ptr)))  ;; 4 words of raw binary in network byte order
          (v128.const i8x16 3 2 1 0 7 6 5 4 11 10 9 8 15 14 13 12)     ;; Rearrange bytes into this order of indices
        )
      )

      (local.set $ptr (i32.add (local.get $ptr) (i32.const 16)))
      (br_if $next_msg_sched_vec (i32.lt_u (local.get $ptr) (i32.const 64)))
    )

    ;; Starting at word 16, populate the next $n words of the message digest
    (local.set $ptr (i32.add (global.get $MSG_DIGEST_PTR) (i32.const 64)))

    (loop $next_pass
      (i32.store (local.get $ptr) (call $gen_msg_digest_word (local.get $ptr)))

      (local.set $ptr (i32.add (local.get $ptr) (i32.const 4)))
      (local.set $n   (i32.sub (local.get $n)   (i32.const 1)))

      (br_if $next_pass (i32.gt_u (local.get $n) (i32.const 0)))
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Phase 2: Process message digest to obtain new hash values
  ;; * Set working variables to current hash values
  ;; * For each of the 64 words in the message digest
  ;;   * Calculate the two temp values
  ;;   * Shunt working variables
  ;; * Add working variable values to corresponding hash values
  ;;
  ;; For testing purposes, the number of loop iterations was not hard-coded to 64 but was was parameterized so it can be
  ;; run just $n times
  ;;
  ;; Returns: None
  (func $phase_2
        (param $n i32)

    (local $idx i32)

    ;; Current hash values and their corresponding internal working variables
    (local $h0 i32) (local $h1 i32) (local $h2 i32) (local $h3 i32) (local $h4 i32) (local $h5 i32) (local $h6 i32) (local $h7 i32)
    (local $a  i32) (local $b  i32) (local $c  i32) (local $d  i32) (local $e  i32) (local $f  i32) (local $g  i32) (local $h  i32)

    (local $temp1 i32)
    (local $temp2 i32)

    ;; Remember the current hash values
    (local.set $h0 (i32.load          (global.get $HASH_VALS_PTR)))
    (local.set $h1 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const  4))))
    (local.set $h2 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const  8))))
    (local.set $h3 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const 12))))
    (local.set $h4 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const 16))))
    (local.set $h5 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const 20))))
    (local.set $h6 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const 24))))
    (local.set $h7 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const 28))))

    ;; Set the working variables to the current hash values
    (local.set $a (local.get $h0))
    (local.set $b (local.get $h1))
    (local.set $c (local.get $h2))
    (local.set $d (local.get $h3))
    (local.set $e (local.get $h4))
    (local.set $f (local.get $h5))
    (local.set $g (local.get $h6))
    (local.set $h (local.get $h7))

    (loop $next_update
      ;; temp1 = $h + $big_sigma1($e) + constant($idx) + msg_schedule_word($idx) + $choice($e, $f, $g)
      (local.set $temp1
        (i32.add
          (i32.add
            (i32.add
              (local.get $h)
              (call $big_sigma (local.get $e) (i32.const 6) (i32.const 11) (i32.const 25))
            )
            (i32.add
              ;; Fetch constant at word offset $idx
              (i32.load (i32.add (global.get $CONSTANTS_PTR) (i32.shl (local.get $idx) (i32.const 2))))
              ;; Fetch message digest word at word offset $idx
              (i32.load (i32.add (global.get $MSG_DIGEST_PTR) (i32.shl (local.get $idx) (i32.const 2))))
            )
          )
          ;; Choice = ($e AND $f) XOR (NOT($e) AND $G)
          (i32.xor
            (i32.and (local.get $e) (local.get $f))
            ;; WebAssembly has no bitwise NOT instruction 😱
            ;; NOT is therefore implemented as i32.xor($val, -1)
            (i32.and (i32.xor (local.get $e) (i32.const -1)) (local.get $g))
          )
        )
      )

      ;; temp2 = $big_sigma0($a) + $majority($a, $b, $c)
      (local.set $temp2
        (i32.add
          (call $big_sigma (local.get $a) (i32.const 2) (i32.const 13) (i32.const 22))
          ;; Majority = ($a AND $b) XOR ($a AND $c) XOR ($b AND $c)
          (i32.xor
            (i32.xor
              (i32.and (local.get $a) (local.get $b))
              (i32.and (local.get $a) (local.get $c))
            )
            (i32.and (local.get $b) (local.get $c))
          )
        )
      )

      ;; Shunt internal working variables
      (local.set $h (local.get $g))                                   ;; $h = $g
      (local.set $g (local.get $f))                                   ;; $g = $f
      (local.set $f (local.get $e))                                   ;; $f = $e
      (local.set $e (i32.add (local.get $d) (local.get $temp1)))      ;; $e = $d + $temp1
      (local.set $d (local.get $c))                                   ;; $d = $c
      (local.set $c (local.get $b))                                   ;; $c = $b
      (local.set $b (local.get $a))                                   ;; $b = $a
      (local.set $a (i32.add (local.get $temp1) (local.get $temp2)))  ;; $a = $temp1 + $temp2

      ;; Update index and counter
      (local.set $idx (i32.add (local.get $idx) (i32.const 1)))
      (local.set $n   (i32.sub (local.get $n)   (i32.const 1)))

      (br_if $next_update (i32.gt_u (local.get $n) (i32.const 0)))
    )

    ;; Add working variables to hash values and store back in memory - don't care if addition results in overflow
    (i32.store          (global.get $HASH_VALS_PTR)                 (i32.add (local.get $h0) (local.get $a)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const  4)) (i32.add (local.get $h1) (local.get $b)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const  8)) (i32.add (local.get $h2) (local.get $c)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const 12)) (i32.add (local.get $h3) (local.get $d)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const 16)) (i32.add (local.get $h4) (local.get $e)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const 20)) (i32.add (local.get $h5) (local.get $f)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const 24)) (i32.add (local.get $h6) (local.get $g)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const 28)) (i32.add (local.get $h7) (local.get $h)))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; This function is needed during development
  ;; Validate that the message block count is correct by checking the last message block
  ;; This should contain the end-of-data marker (0x80) and the message length in bits (in big endian format!)
  ;;
  ;; Returns:
  ;;   i32 -> Return code (Success = 0)
  ;; (func $validate_last_msg_blk
  ;;       (param $msg_blk_count i32)
  ;;       (result i32)

  ;;   (local $msg_len_bits  i64)
  ;;   (local $msg_len_bytes i64)
  ;;   (local $msg_len_ptr   i32)
  ;;   (local $eod_ptr       i32)
  ;;   (local $return_code   i32)

  ;;   (local $msg_len_mod_64 i32)

  ;;   ;; The i64 message length should be located at $IOVEC_BUF_ADDR + ($msg_blk_count * 64) - 8
  ;;   (local.set $msg_len_ptr
  ;;       (i32.sub
  ;;         (i32.add
  ;;           (global.get $IOVEC_BUF_ADDR)
  ;;           (i32.shl (local.get $msg_blk_count) (i32.const 6))
  ;;         )
  ;;         (i32.const 8)
  ;;       )
  ;;   )
  ;;   ;; (call $log_msg (i32.const 6) (i32.const 10) (local.get $msg_len_ptr))

  ;;   ;; Swizzle the byte order of the file size back into little endian format
  ;;   (v128.store
  ;;     (global.get $FILE_SIZE_LE_PTR)
  ;;     (i8x16.swizzle
  ;;       (v128.load (local.get $msg_len_ptr))
  ;;       (v128.const i8x16 7 6 5 4 3 2 1 0 15 14 13 12 11 10 9 8)
  ;;     )
  ;;   )

  ;;   (local.set $msg_len_bits  (i64.load  (global.get $FILE_SIZE_LE_PTR)))
  ;;   (local.set $msg_len_bytes (i64.shr_u (local.get $msg_len_bits) (i64.const 3)))

  ;;   ;; (call $log_msg (i32.const 6) (i32.const 11) (i32.wrap_i64 (local.get $msg_len_bits)))
  ;;   ;; (call $log_msg (i32.const 6) (i32.const 12) (i32.wrap_i64 (local.get $msg_len_bytes)))

  ;;   ;; The end-of-data marker 0x80 should be found immediately after the message data at location:
  ;;   ;; $msg_len_mod_64 = $msg_len_bytes mod 64
  ;;   ;; $IOVEC_BUF_ADDR + (($msg_blk_count - ($msg_len_mod_64 > 55 ? 2 : 1)) * 64) + $msg_len_mod_64
  ;;   (local.set $msg_len_mod_64 (i32.wrap_i64 (i64.and (local.get $msg_len_bytes) (i64.const 0x3F))))
  ;;   ;; (call $log_msg (i32.const 6) (i32.const 13) (local.get $msg_len_mod_64))

  ;;   ;; Calculate byte address of EoD marker
  ;;   (local.set $eod_ptr
  ;;     (i32.add
  ;;       (i32.add
  ;;         (global.get $IOVEC_BUF_ADDR)
  ;;         ;; Shift left by 6 bits multiplies block count by 64
  ;;         (i32.shl
  ;;           (i32.sub
  ;;             (local.get $msg_blk_count)
  ;;             ;; If the last block contains 55 bytes or less, then the EoD marker will be in the last block,
  ;;             ;; else it will be in the second last block
  ;;             (if
  ;;               (result i32)
  ;;               (i32.gt_u (local.get $msg_len_mod_64) (i32.const 55))
  ;;               (then i32.const 2)
  ;;               (else i32.const 1)
  ;;             )
  ;;           )
  ;;           (i32.const 6)
  ;;         )
  ;;       )
  ;;       (local.get $msg_len_mod_64)
  ;;     )
  ;;   )
  ;;   ;; (call $log_msg (i32.const 6) (i32.const 16) (local.get $eod_ptr))

  ;;   (if
  ;;     (result i32)
  ;;     (i32.ne (i32.load8_u (local.get $eod_ptr)) (i32.const 0x80))
  ;;     (then (i32.const 8))  ;; Return code 8 => EOD marker not found
  ;;     (else (i32.const 0))  ;; Return code 0
  ;;   )
  ;; )

;; *********************************************************************************************************************
;; PUBLIC API
;; *********************************************************************************************************************

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Calculate the SHA256 of the supplied file name
  ;;
  ;; Returns:
  ;;   i32 -> Return code (Success = 0)    Only needed during development
  ;;   i32 -> Pointer to SHA256
  (func (export "sha256sum")
        (param $fd_dir      i32) ;; File descriptor of directory preopened by WASI
        (param $path_offset i32) ;; Location of path name
        (param $path_len    i32) ;; Length of path name

        ;; (result i32 i32)  ;; Return code, pointer to SHA256
        (result i32)      ;; Pointer to SHA256

    (local $blk_count     i32)
    (local $blk_ptr       i32)
    (local $msg_blk_count i32)
    ;; (local $return_code   i32)

    (local.set $msg_blk_count (call $read_file (local.get $fd_dir) (local.get $path_offset) (local.get $path_len)))

    ;; (block $exit
      ;; ;; Validate the last message block
      ;; (local.tee $return_code (call $validate_last_msg_blk (local.get $msg_blk_count)))

      ;; (if ;; Return code != 0
      ;;   (then br $exit)
      ;; )

      (local.set $blk_ptr (global.get $IOVEC_BUF_ADDR))

      ;; Initialise hash values
      ;; Argument order for memory.copy is non-intuitive: dest_ptr, src_ptr, length
      (memory.copy (global.get $HASH_VALS_PTR) (global.get $INIT_HASH_VALS_PTR) (i32.const 32))

      ;; Process file in 64-byte blocks
      (loop $next_msg_blk
        (call $phase_1 (i32.const 48) (local.get $blk_ptr) (global.get $MSG_DIGEST_PTR))
        (call $phase_2 (i32.const 64))

        (local.set $blk_ptr   (i32.add (local.get $blk_ptr)   (i32.const 64)))
        (local.set $msg_blk_count (i32.sub (local.get $msg_blk_count) (i32.const 1)))

        (br_if $next_msg_blk (i32.gt_u (local.get $msg_blk_count) (i32.const 0)))
      )
    ;; ) ;; Block $exit

    ;; Return values
    ;; (local.get  $return_code)
    (global.get $HASH_VALS_PTR)
  )
)
