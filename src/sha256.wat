(module
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Function types for WASI calls
  (type $type_wasi_args      (func (param i32 i32)                             (result i32)))
  (type $type_wasi_path_open (func (param i32 i32 i32 i32 i32 i64 i64 i32 i32) (result i32)))
  (type $type_wasi_fd_seek   (func (param i32 i64 i32 i32)                     (result i32)))
  (type $type_wasi_fd_io     (func (param i32 i32 i32 i32)                     (result i32)))
  (type $type_wasi_fd_close  (func (param i32)                                 (result i32)))

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Import OS system calls via WASI
  (import "wasi_snapshot_preview1" "args_sizes_get" (func $wasi.args_sizes_get (type $type_wasi_args)))
  (import "wasi_snapshot_preview1" "args_get"       (func $wasi.args_get       (type $type_wasi_args)))
  (import "wasi_snapshot_preview1" "path_open"      (func $wasi.path_open      (type $type_wasi_path_open)))
  (import "wasi_snapshot_preview1" "fd_seek"        (func $wasi.fd_seek        (type $type_wasi_fd_seek)))
  (import "wasi_snapshot_preview1" "fd_read"        (func $wasi.fd_read        (type $type_wasi_fd_io)))
  (import "wasi_snapshot_preview1" "fd_write"       (func $wasi.fd_write       (type $type_wasi_fd_io)))
  (import "wasi_snapshot_preview1" "fd_close"       (func $wasi.fd_close       (type $type_wasi_fd_close)))

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; WASI requires the WASM module to export memory using the name "memory"
  ;; Memory page   1     Internal stuff
  ;; Memory pages  2-33  2MB IO read buffer
  ;; Memory page  34     File contents (which will grow dynamically if needed)
  (memory $memory (export "memory") 34)

  (global $DEBUG_ACTIVE i32 (i32.const 0))

  ;; Memory Map
  ;;             Offset  Length   Type    Description
  ;; Page 1: 0x00000000       4   i32     file_fd
  ;; Unused
  ;;         0x00000008       8   i64     fd_seek file size + 9
  ;;         0x00000010       8   i32x2   Pointer to read iovec buffer address + size
  ;;         0x00000018       8   i32x2   Pointer to write iovec buffer address + size
  ;;         0x00000020       8   i64     Bytes transferred by the last io operation
  ;;         0x00000030       8   i64     File size (Little endian)
  ;;         0x00000040       8   i64     File size (Big endian)
  ;;         0x00000050       4   i32     Pointer to file path name
  ;;         0x00000054       4   i32     Pointer to file path length
  ;; Unused
  ;;         0x00000100      26           Error message "File name argument missing"
  ;;         0x00000120      25           Error message "No such file or directory"
  ;;         0x00000140      24           Error message "Unable to read file size"
  ;;         0x00000160      21           Error message "File too large (>4Gb)"
  ;;         0x00000180      18           Error message "Error reading file"
  ;;         0x000001A0      48           Error message "Neither a directory nor a symlink to a directory"
  ;;         0x000001D0      19           Error message "Bad file descriptor"
  ;;         0x000001F0      26           Error message "Memory allocation failed: "
  ;; Unused
  ;;         0x00000210       6           Debug message "argc: "
  ;;         0x00000220      14           Debug message "argv_buf_len: "
  ;;         0x00000230      15           Debug message "msg_blk_count: "
  ;;         0x00000240       6           Debug message "Step: "
  ;;         0x00000250      13           Debug message "Return code: "
  ;;         0x00000260      28           Debug message "Bytes read by wasi.fd_seek: "
  ;;         0x00000280      28           Debug message "Bytes read by wasi.fd_read: "
  ;;         0x000002A0      20           Debug message "wasi.fd_read count: "
  ;;         0x000002C0      18           Debug message "Copy to new addr: "
  ;;         0x000002F0      18           Debug message "Copy length     : "
  ;;         0x00000310      30           Debug message "Allocated extra memory pages: "
  ;;         0x00000340      27           Debug message "No memory allocation needed"
  ;;         0x00000360      32           Debug message "Current memory page allocation: "
  ;; Unused
  ;;         0x00000400      32   i32x8   Constants - fractional part of square root of first 8 primes
  ;;         0x00000420     256   i32x64  Constants - fractional part of cube root of first 64 primes
  ;;         0x00000520      64   i32x8   Hash values
  ;;         0x00000560     512   data    Message digest
  ;;         0x00000770      64   data    ASCII representation of SHA value
  ;;         0x000007B0       2   data    Two ASCII spaces
  ;;         0x000007C0       4   i32     Number of command line arguments
  ;;         0x000007C4       4   i32     Command line buffer size
  ;;         0x000007C8       4   i32     Pointer to array of pointers to arguments (needs double dereferencing!)
  ;; Unused
  ;;         0x00000800       ?   data    Command line args buffer
  ;;         0x00001000       ?   data    Buffer for strings being written to the console
  ;;         0x00001400       ?   data    Buffer for a 2Mb chunk of file data

  (global $FD_FILE_PTR         i32 (i32.const 0x00000000))
  (global $FILE_SIZE_PTR       i32 (i32.const 0x00000008))
  (global $IOVEC_READ_BUF_PTR  i32 (i32.const 0x00000010))
  (global $IOVEC_WRITE_BUF_PTR i32 (i32.const 0x00000018))
  (global $NREAD_PTR           i32 (i32.const 0x00000020))
  (global $FILE_SIZE_LE_PTR    i32 (i32.const 0x00000030))
  (global $FILE_SIZE_BE_PTR    i32 (i32.const 0x00000040))
  (global $FILE_PATH_PTR       i32 (i32.const 0x00000050))
  (global $FILE_PATH_LEN_PTR   i32 (i32.const 0x00000054))

  (global $ERR_MSG_NOARG       i32 (i32.const 0x00000100))
  (global $ERR_MSG_NOENT       i32 (i32.const 0x00000120))
  (global $ERR_FILE_SIZE_READ  i32 (i32.const 0x00000140))
  (global $ERR_FILE_TOO_LARGE  i32 (i32.const 0x00000160))
  (global $ERR_READING_FILE    i32 (i32.const 0x00000180))
  (global $ERR_NOT_DIR_SYMLINK i32 (i32.const 0x000001A0))
  (global $ERR_BAD_FD          i32 (i32.const 0x000001D0))
  (global $ERR_MEM_ALLOC       i32 (i32.const 0x000001F0))

  (global $DBG_MSG_ARGC        i32 (i32.const 0x00000210))
  (global $DBG_MSG_ARGV_LEN    i32 (i32.const 0x00000220))
  (global $DBG_MSG_BLK_COUNT   i32 (i32.const 0x00000230))
  (global $DBG_STEP            i32 (i32.const 0x00000240))
  (global $DBG_RETURN_CODE     i32 (i32.const 0x00000250))
  (global $DBG_FILE_SIZE       i32 (i32.const 0x00000260))
  (global $DBG_BYTES_READ      i32 (i32.const 0x00000280))
  (global $DBG_READ_COUNT      i32 (i32.const 0x000002A0))
  (global $DBG_COPY_MEM_TO     i32 (i32.const 0x000002C0))
  (global $DBG_COPY_MEM_LEN    i32 (i32.const 0x000002F0))
  (global $DBG_MEM_GROWN       i32 (i32.const 0x00000310))
  (global $DBG_NO_MEM_ALLOC    i32 (i32.const 0x00000340))
  (global $DBG_MEM_SIZE        i32 (i32.const 0x00000360))

  (global $INIT_HASH_VALS_PTR  i32 (i32.const 0x00000400))
  (global $CONSTANTS_PTR       i32 (i32.const 0x00000420))
  (global $HASH_VALS_PTR       i32 (i32.const 0x00000520))
  (global $MSG_DIGEST_PTR      i32 (i32.const 0x00000560))
  (global $ASCII_HASH_PTR      i32 (i32.const 0x00000770))
  (global $ASCII_SPACES        i32 (i32.const 0x000007B0))
  (global $ARGS_COUNT_PTR      i32 (i32.const 0x000007C0))
  (global $ARGV_BUF_LEN_PTR    i32 (i32.const 0x000007C4))
  (global $ARGV_PTRS_PTR       i32 (i32.const 0x000007C8))
  (global $ARGV_BUF_PTR        i32 (i32.const 0x00000800))
  (global $STR_WRITE_BUF_PTR   i32 (i32.const 0x00001000))

  ;; Memory map: Pages 2-33: 2Mb IO Buffer
  (global $READ_BUFFER_PTR     i32 (i32.const 0x00010000))
  (global $READ_BUFFER_SIZE    i32 (i32.const 0x00020000))     ;; fd_read buffer size = 2Mb

  ;; Memory map: Pages 34-???
  (global $IOVEC_BUF_ADDR      i32 (i32.const 0x0021F000))     ;; addr = (34 - 1) * 65536

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Debug and error messages
  (data (i32.const 0x00000100) "File name argument missing")
  (data (i32.const 0x00000120) "No such file or directory")
  (data (i32.const 0x00000140) "Unable to read file size")
  (data (i32.const 0x00000160) "File too large (>4Gb)")
  (data (i32.const 0x00000180) "Error reading file")
  (data (i32.const 0x000001A0) "Neither a directory nor a symlink to a directory")
  (data (i32.const 0x000001D0) "Bad file descriptor")
  (data (i32.const 0x000001F0) "Memory allocation failed: ")

  (data (i32.const 0x00000210) "argc: ")
  (data (i32.const 0x00000220) "argv_buf_len: ")
  (data (i32.const 0x00000230) "msg_blk_count: ")
  (data (i32.const 0x00000240) "Step: ")
  (data (i32.const 0x00000250) "Return code: ")
  (data (i32.const 0x00000260) "Bytes read by wasi.fd_seek: ")
  (data (i32.const 0x00000280) "Bytes read by wasi.fd_read: ")
  (data (i32.const 0x000002A0) "wasi.fd_read count: ")
  (data (i32.const 0x000002C0) "Copy to new addr: ")
  (data (i32.const 0x000002F0) "Copy length     : ")
  (data (i32.const 0x00000310) "Allocated extra memory pages: ")
  (data (i32.const 0x00000340) "No memory allocation needed")
  (data (i32.const 0x00000360) "Current memory page allocation: ")

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; The first 32 bits of the fractional part of the square roots of the first 8 primes 2..19
  ;; Used to initialise the hash values
  ;; The byte order of the raw values defined below is little-endian!
  (data (i32.const 0x00000400)                                   ;; $INIT_HASH_VALS_PTR
    "\67\E6\09\6A" "\85\AE\67\BB" "\72\F3\6E\3C" "\3A\F5\4F\A5"  ;; 0x00000400
    "\7F\52\0E\51" "\8C\68\05\9B" "\AB\D9\83\1F" "\19\CD\E0\5B"  ;; 0x00000410
  )

  ;; The first 32 bits of the fractional part of the cube roots of the first 64 primes 2..311
  ;; Used in phase 2 (hash value calculation)
  ;; The byte order of the raw values defined below is little-endian!
  (data (i32.const 0x00000420)                                   ;; $CONSTANTS_PTR
    "\98\2F\8A\42" "\91\44\37\71" "\CF\FB\C0\B5" "\A5\DB\B5\E9"  ;; 0x00000420
    "\5B\C2\56\39" "\F1\11\F1\59" "\A4\82\3F\92" "\D5\5E\1C\AB"  ;; 0x00000430
    "\98\AA\07\D8" "\01\5B\83\12" "\BE\85\31\24" "\C3\7D\0C\55"  ;; 0x00000440
    "\74\5D\BE\72" "\FE\B1\DE\80" "\A7\06\DC\9B" "\74\F1\9B\C1"  ;; 0x00000450
    "\C1\69\9B\E4" "\86\47\BE\EF" "\C6\9D\C1\0F" "\CC\A1\0C\24"  ;; 0x00000460
    "\6F\2C\E9\2D" "\AA\84\74\4A" "\DC\A9\B0\5C" "\DA\88\F9\76"  ;; 0x00000470
    "\52\51\3E\98" "\6D\C6\31\A8" "\C8\27\03\B0" "\C7\7F\59\BF"  ;; 0x00000480
    "\F3\0B\E0\C6" "\47\91\A7\D5" "\51\63\CA\06" "\67\29\29\14"  ;; 0x00000490
    "\85\0A\B7\27" "\38\21\1B\2E" "\FC\6D\2C\4D" "\13\0D\38\53"  ;; 0x000004A0
    "\54\73\0A\65" "\BB\0A\6A\76" "\2E\C9\C2\81" "\85\2C\72\92"  ;; 0x000004B0
    "\A1\E8\BF\A2" "\4B\66\1A\A8" "\70\8B\4B\C2" "\A3\51\6C\C7"  ;; 0x000004C0
    "\19\E8\92\D1" "\24\06\99\D6" "\85\35\0E\F4" "\70\A0\6A\10"  ;; 0x000004D0
    "\16\C1\A4\19" "\08\6C\37\1E" "\4C\77\48\27" "\B5\BC\B0\34"  ;; 0x000004E0
    "\B3\0C\1C\39" "\4A\AA\D8\4E" "\4F\CA\9C\5B" "\F3\6F\2E\68"  ;; 0x000004F0
    "\EE\82\8F\74" "\6F\63\A5\78" "\14\78\C8\84" "\08\02\C7\8C"  ;; 0x00000500
    "\FA\FF\BE\90" "\EB\6C\50\A4" "\F7\A3\F9\BE" "\F2\78\71\C6"  ;; 0x00000510
  )

  ;; Two ASCII spaces
  (data (i32.const 0x000007B0) "  ")

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; WASI automatically calls the "_start" function when started by the host environment
  ;;
  ;; * Check and extract the command line arguments
  ;; * Attempt topen the file
  ;; * Read file size
  ;; * Calculate how many 64-byte message blocks are needed to contain the file followed by an end-of-data marker
  ;;   (0x80) and the 8-byte file length (in bits)
  ;; * Repeatedly call wasi.fd_read processing each 2Mb chunk
  ;; * Assemble the SHA256 hash value and write it to stdout
  ;;
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func (export "_start")
    (local $argc            i32)  ;; Argument count
    (local $argv_buf_len    i32)  ;; Total argument length.  Each argument value is null terminated
    (local $filename_ptr    i32)
    (local $filename_len    i32)
    (local $file_fd         i32)  ;; File descriptor of target file
    (local $chunk_size      i32)  ;; fd_read buffer size = min($file_size_bytes, 2Mb)
    (local $bytes_read      i32)  ;; How many bytes fd_read has returned
    (local $copy_to_addr    i32)  ;; Where should the next file chunk be written
    (local $msg_blk_count   i32)  ;; File contains this many 64-byte message blocks
    (local $return_code     i32)
    (local $step            i32)

    (local $file_size_bytes i64)

    (block $exit
      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 0: Fetch command line arguments
      ;;
      ;; NodeJS supplies 3 arguments, but other environments such as wasmer and wasmtime supply only 2
      ;; Either way, we expect the file name to be the last argument
      (call $wasi.args_sizes_get (global.get $ARGS_COUNT_PTR) (global.get $ARGV_BUF_LEN_PTR))
      drop

      ;; $ARGV_PTRS_PTR points to an array of pointers of size [$argc; i32]
      ;; The nth pointer in the array points to the nth command line argument value
      (call $wasi.args_get (global.get $ARGV_PTRS_PTR) (global.get $ARGV_BUF_PTR))
      drop

      ;; Remember the argument count and the total length of arguments
      (local.set $argc         (i32.load (global.get $ARGS_COUNT_PTR)))
      (local.set $argv_buf_len (i32.load (global.get $ARGV_BUF_LEN_PTR)))

      ;; Check that at least 2 arguments have been supplied
      (if (i32.lt_u (local.get $argc) (i32.const 2))
        (then
          (call $write_args_to_stderr)
          (call $writeln_to_fd (i32.const 2) (global.get $ERR_MSG_NOARG) (i32.const 26))
          (br $exit)
        )
      )

      ;; Fetch pointer to the filename (last pointer in the list)
      (local.set $filename_ptr (call $fetch_arg_n (local.get $argc)))
      (local.set $filename_len)

      (i32.store (global.get $FILE_PATH_PTR)     (local.get $filename_ptr))
      (i32.store (global.get $FILE_PATH_LEN_PTR) (local.get $filename_len))

      (call $writeln_to_fd
        (i32.const 1)
        (i32.load (global.get $FILE_PATH_PTR))
        (i32.load (global.get $FILE_PATH_LEN_PTR))
      )

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 1: Open file
      (local.set $file_fd
        (call $file_open
          (local.tee $step (i32.add (local.get $step) (i32.const 1)))
          (i32.const 3)              ;; Preopened fd is assumed to be 3
          (local.get $filename_ptr)
          (local.get $filename_len)
        )
      )
      (local.tee $return_code)

      (if ;; $return_code > 0
        (then (br $exit))
      )

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 2: Determine file size
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (call $file_size_get (local.get $file_fd))  ;; This function will either succeed or fail catastrophically
      (local.set $file_size_bytes (i64.load (global.get $FILE_SIZE_PTR)))

      (call $write_msg_with_value
        (i32.const 1)
        (global.get $DBG_FILE_SIZE) (i32.const 28)
        (i32.wrap_i64 (local.get $file_size_bytes))
      )

      ;; Actual space needed = file_size + 9 bytes
      ;; 1 byte for 0x80 end-of-data marker + 8 bytes for the file size in bits as a 64-bit, big endian integer
      (local.set $file_size_bytes (i64.add (local.get $file_size_bytes) (i64.const 9)))

      ;; If the file size > 4Gb, then pack up and go home because WASM cannot process a file that big...
      (if
        (i64.gt_u (local.get $file_size_bytes) (i64.const 4294967296))
        (then
          ;; Return code 22 means file too large
          (call $write_step_to_fd (i32.const 2) (local.get $step) (local.tee $return_code (i32.const 22)))
          (call $writeln_to_fd    (i32.const 2) (global.get $ERR_FILE_TOO_LARGE) (i32.const 21))
          (br $exit)
        )
      )

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 3: If necessary, grow memory
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (if (call $grow_memory (local.get $file_size_bytes)) ;; $return_code > 0
        (then (br $exit))
      )

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 4: Read file contents
      (local.set $step (i32.add (local.get $step) (i32.const 1)))

      ;; The amount of data returned by fd_read varies depending on which host environment invokes this module.
      ;; Some runtimes allow you to specify a buffer size equal to the file size, thus returning the entire file in a
      ;; single call to fd_read.  Wasmer, on the other hand, imposes a 2Mb upper limit on the read buffer size.
      ;; Consequently, multiple calls to fd_read may be required before we have the entire file.
      (local.set $chunk_size
        (select
          (global.get $READ_BUFFER_SIZE) (i32.wrap_i64 (local.get $file_size_bytes))
          (i64.ge_u (local.get $file_size_bytes) (i64.extend_i32_u (global.get $READ_BUFFER_SIZE)))
        )
      )
      (i32.store          (global.get $IOVEC_READ_BUF_PTR)                (global.get $READ_BUFFER_PTR))
      (i32.store (i32.add (global.get $IOVEC_READ_BUF_PTR) (i32.const 4)) (local.get  $chunk_size))

      ;; Initial destination address for memory.copy after fd_read
      (local.set $copy_to_addr (global.get $IOVEC_BUF_ADDR))

      (loop $read_file_chunk
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
            (call $write_msg_with_value
              (i32.const 2)
              (global.get $DBG_RETURN_CODE) (i32.const 13)
              (local.get $return_code)
            )
            (call $writeln_to_fd (i32.const 2) (global.get $ERR_READING_FILE) (i32.const 18))
            (br $exit)
          )
        )

        (local.set $bytes_read (i32.load (global.get $NREAD_PTR)))
        (call $write_msg_with_value (i32.const 1) (global.get $DBG_BYTES_READ) (i32.const 28) (local.get $bytes_read))

        ;; Keep reading until fd_read returns 0 bytes read
        (if (local.get $bytes_read) ;; > 0?
          (then
            (call $write_msg_with_value (i32.const 1) (global.get $DBG_COPY_MEM_TO)  (i32.const 18)(local.get $copy_to_addr))
            (call $write_msg_with_value (i32.const 1) (global.get $DBG_COPY_MEM_LEN) (i32.const 18)(local.get $bytes_read))

            ;; Copy the bytes just read out of the read buffer, then shunt the $copy_to_addr
            (memory.copy (local.get $copy_to_addr) (global.get $READ_BUFFER_PTR) (local.get $bytes_read))
            (local.set $copy_to_addr (i32.add (local.get $copy_to_addr) (local.get $bytes_read)))

            (br $read_file_chunk)
          )
        )
      )

      ;; Write end-of-data marker (0x80) immediately after the file data
      (i32.store8
        ;; Since the file size cannot exceed 4Gb, it is safe to read only the first 32 bits of the file size
        (i32.add (global.get $IOVEC_BUF_ADDR) (i32.load (global.get $FILE_SIZE_PTR)))
        (i32.const 0x80)
      )


      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 5: Calculate number of 64 byte message blocks
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.set $msg_blk_count (i32.wrap_i64 (i64.shr_u (local.get $file_size_bytes) (i64.const 6))))

      ;; Do we need to allocate an extra message block?
      (if ;; file_size_bytes - ($msg_blk_count * 64) > 0
        (i64.gt_s
          (i64.sub
            (local.get $file_size_bytes)
            (i64.shl (i64.extend_i32_u (local.get $msg_blk_count)) (i64.const 6))
          )
          (i64.const 0)
        )
        (then (local.set $msg_blk_count (i32.add (local.get $msg_blk_count) (i32.const 1))))
      )

      ;; Convert file size in bytes to size in bits
      (i64.store (global.get $FILE_SIZE_LE_PTR) (i64.shl (i64.load (global.get $FILE_SIZE_PTR)) (i64.const 3)))

      ;; Swap the byte order of the little endian file size into big endian order
      (v128.store
        (global.get $FILE_SIZE_BE_PTR)
        (i8x16.swizzle
          (v128.load (global.get $FILE_SIZE_LE_PTR))
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

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 6: Close file
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.set $return_code (call $wasi.fd_close (local.get $file_fd)))

      (call $write_msg_with_value
        (i32.const 1)
        (global.get $DBG_MSG_BLK_COUNT) (i32.const 15)
        (local.get $msg_blk_count)
      )

      ;; Calculate SHA256 value
      (call $sha256sum (local.get $msg_blk_count))
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Attempt to open the file living in $fd_dir whose name exists at $path_offset($path_len)
  ;; Returns:
  ;;   i32 -> Return code (0 = Success)
  ;;   i32 -> Fd of opened file
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $file_open
        (param $step        i32) ;; Arbitrary processing step number (only used for error tracing)
        (param $fd_dir      i32) ;; File descriptor of directory preopened by WASI
        (param $path_offset i32) ;; Location of path name
        (param $path_len    i32) ;; Length of path name
        (result i32 i32)

    (local $return_code i32)
    (local $file_fd     i32)

    (block $exit
      (local.tee $return_code
        (call $wasi.path_open
          (local.get $fd_dir)        ;; fd of preopened directory
          (i32.const 0)              ;; dirflags (no special flags)
          (local.get $path_offset)   ;; path (pointer to file path in memory)
          (local.get $path_len)      ;; path_len (length of the path string)
          (i32.const 0)              ;; oflags (O_RDONLY for reading)
          (i64.const 6)              ;; Base rights (RIGHTS_FD_READ 0x02 + RIGHTS_FD_SEEK 0x04)
          (i64.const 0)              ;; Inherited rights
          (i32.const 0)              ;; fdflags (O_RDONLY)
          (global.get $FD_FILE_PTR)  ;; Write new file descriptor here
        )
      )

      (if ;; $return_code > 0
        (then
          (call $write_step_to_fd (i32.const 2) (local.get $step) (local.get $return_code))

          ;; Bad file descriptor (Did the target directory suddenly disappear since starting the program?)
          (if (i32.eq (local.get $return_code) (i32.const 0x08))
            (then (call $writeln_to_fd (i32.const 2) (global.get $ERR_BAD_FD) (i32.const 19)))
          )

          ;; File not found
          (if (i32.eq (local.get $return_code) (i32.const 0x2c))
            (then (call $writeln_to_fd (i32.const 2) (global.get $ERR_MSG_NOENT) (i32.const 25)))
          )

          ;; Not a directory or a symlink to a directory (probably bad values passed to --mapdir)
          (if (i32.eq (local.get $return_code) (i32.const 0x36))
            (then (call $writeln_to_fd (i32.const 2) (global.get $ERR_NOT_DIR_SYMLINK) (i32.const 48)))
          )

          (br $exit)
        )
      )

      ;; Pick up the file descriptor value
      (local.set $file_fd (i32.load (global.get $FD_FILE_PTR)))
    )

    (local.get $return_code)
    (local.get $file_fd)
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Discover the size of open file descriptor
  ;; If calling fd_seek fails for any reason, then the target file has probably been moved or deleted since the program
  ;; started.  This makes it impossible to continue, so immediately abort execution.
  ;; Consequently, there is no need for this function to give back a return code.
  ;;
  ;; Return:
  ;;   Indirect -> File size is written to location held in the global pointer $FILE_SIZE_PTR
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $file_size_get
        (param $file_fd i32) ;; File fd (must point to a file that is already open with seek capability)

    (local $return_code     i32)
    (local $file_size_bytes i64)

    ;; Determine size by seek to the end of the file
    (local.tee $return_code
      (call $wasi.fd_seek
        (local.get $file_fd)
        (i64.const 0)  ;; Offset
        (i32.const 2)  ;; Whence = END
        (global.get $FILE_SIZE_PTR)
      )
    )

    (if ;; fd_seek fails, then throw toys out of pram
      (then
        (call $writeln_to_fd (i32.const 2) (global.get $ERR_FILE_SIZE_READ) (i32.const 24))
        unreachable
      )
    )

    ;; Remember file size
    (local.set $file_size_bytes (i64.load (global.get $FILE_SIZE_PTR)))

    ;; Reset file pointer back to the start
    (call $wasi.fd_seek
      (local.get $file_fd)
      (i64.const 0)  ;; Offset
      (i32.const 0)  ;; Whence = START
      (global.get $FILE_SIZE_PTR)
    )

    (if ;; we can't reset the seek ptr, then throw toys out of pram
      (then
        (call $writeln_to_fd (i32.const 2) (global.get $ERR_FILE_SIZE_READ) (i32.const 24))
        unreachable
      )
    )

    ;; After seek pointer reset, write file size back to the expected location
    (i64.store (global.get $FILE_SIZE_PTR) (local.get $file_size_bytes))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; When this module starts, a single memory page is available for the file contents.
  ;; However, if the file is larger than 64Kb, then additional memory will be needed.
  ;;
  ;; Grow memory by enough pages to hold the file plus the 9 bytes required by the end-of-data marker (0x80) and the
  ;; end-of-block file size (8 bytes)
  ;;
  ;; Returns:
  ;;   i32 -> Return code. (0 = Success, 4 = Unable to grow memory)
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $grow_memory
      (param $file_size_bytes i64)
      (result i32)

    (local $return_code        i32)
    (local $required_mem_pages i32)
    (local $total_file_size    i64)

    ;; Total memory needed by SHA256 algorithm = file size on disk + 9 bytes
    (local.set $total_file_size (i64.add (local.get $file_size_bytes) (i64.const 9)))

    (if ;; the file is larger than 64Kb
      (i64.gt_u (local.get $total_file_size) (i64.const 0x10000))
      (then
        (local.set $required_mem_pages
          ;; Add an extra memory page just to be safe
          (i32.add
            ;; Convert file size to 64Kb message blocks
            (i32.wrap_i64 (i64.shr_u (local.get $total_file_size) (i64.const 16)))
            (i32.const 1)
          )
        )

        (if ;; Memory allocation failed (memory.grow returned -1)
          (i32.eq (memory.grow (local.get $required_mem_pages)) (i32.const 0xFFFFFFFF))
          (then
            (call $write_msg_with_value
              (i32.const 1)
              (global.get $ERR_MEM_ALLOC) (i32.const 26)
              (local.get $required_mem_pages)
            )
            (local.set $return_code (i32.const 4))
          )
          (else
            (call $write_msg_with_value
              (i32.const 1)
              (global.get $DBG_MEM_GROWN) (i32.const 30)
              (local.get $required_mem_pages)
            )
          )
        )
      )
      (else ;; The file will fit into existing available memory
        (if (global.get $DEBUG_ACTIVE)
          (then (call $writeln_to_fd (i32.const 1) (global.get $DBG_NO_MEM_ALLOC) (i32.const 27)))
        )
      )
    )

    (call $write_msg_with_value (i32.const 1) (global.get $DBG_MEM_SIZE) (i32.const 32) (memory.size))
    (local.get $return_code)
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Write data to the console on either stdout or stderr
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $write_to_fd
        (param $fd      i32)  ;; fd of stdout (1) or stderr (2)
        (param $str_ptr i32)  ;; Pointer to string
        (param $str_len i32)  ;; String length

    ;; Prepare iovec buffer write values: data offset + length
    (i32.store          (global.get $IOVEC_WRITE_BUF_PTR)                (local.get $str_ptr))
    (i32.store (i32.add (global.get $IOVEC_WRITE_BUF_PTR) (i32.const 4)) (local.get $str_len))

    ;; Write data to console
    (call $wasi.fd_write
      (local.get $fd)
      (global.get $IOVEC_WRITE_BUF_PTR) ;; Location of string data's offset/length
      (i32.const 1)                     ;; Number of iovec buffers to write
      (global.get $NREAD_PTR)           ;; Bytes written
    )

    drop  ;; Don't care about the number of bytes written
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Starting at $str_ptr, write $str_len bytes to the specified fd followed by a line feed
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $writeln_to_fd
        (param $fd      i32)  ;; File descriptor
        (param $str_ptr i32)  ;; Pointer to string
        (param $str_len i32)  ;; String length

    ;; If the message pointer already points to the start of the write buffer, then skip the memcpy because we can
    ;; assume the caller has already built the write buffer contents themselves
    (if (i32.ne (local.get $str_ptr) (global.get $STR_WRITE_BUF_PTR))
      (then
        (memory.copy (global.get $STR_WRITE_BUF_PTR) (local.get $str_ptr) (local.get $str_len))
      )
    )
    (i32.store (i32.add (global.get $STR_WRITE_BUF_PTR) (local.get $str_len)) (i32.const 0x0A))
    (call $write_to_fd (local.get $fd) (global.get $STR_WRITE_BUF_PTR) (i32.add (local.get $str_len) (i32.const 1)))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Build message + value in the write buffer, then write it to the specified fd
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $write_msg_with_value
        (param $fd      i32)  ;; Write to this file descriptor
        (param $msg_ptr i32)  ;; Pointer to error message text
        (param $msg_len i32)  ;; Length of error message
        (param $msg_val i32)  ;; Some i32 value to be prefixed with "0x" then printed after the message text

    (local $buf_ptr i32)

    ;; Do nothing unless we are either writing to stderr or $DEBUG_ACTIVE is true
    (if
      (i32.or
        (global.get $DEBUG_ACTIVE)
        (i32.eq (local.get $fd) (i32.const 2))
      )
      (then
        (local.set $buf_ptr (global.get $STR_WRITE_BUF_PTR))

        ;; Write message text
        (memory.copy (local.get $buf_ptr) (local.get $msg_ptr) (local.get $msg_len))
        (local.set $buf_ptr (i32.add (local.get $buf_ptr) (local.get $msg_len)))

        ;; Write "0x"
        (i32.store16 (local.get $buf_ptr) (i32.const 0x7830)) ;; (little endian)
        (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 2)))

        ;; Write i32 value as hex string
        (call $i32_to_hex_str (local.get $msg_val) (local.get $buf_ptr))
        (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 8)))

        ;; Write LF
        (i32.store8 (local.get $buf_ptr) (i32.const 0x0A))
        (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 1)))

        (call $write_to_fd
          (local.get $fd)
          (global.get $STR_WRITE_BUF_PTR)
          (i32.sub (local.get $buf_ptr) (global.get $STR_WRITE_BUF_PTR)) ;; length = end address - start address
        )
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Write the return code of the current processing step to the specified fd
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $write_step_to_fd
        (param $fd       i32)
        (param $step_no  i32)
        (param $ret_code i32)

    (local $buf_ptr i32)

    ;; Do nothing unless we are either writing to stderr or $DEBUG_ACTIVE is true
    (if
      (i32.or
        (global.get $DEBUG_ACTIVE)
        (i32.eq (local.get $fd) (i32.const 2))
      )
      (then
        (local.set $buf_ptr (global.get $STR_WRITE_BUF_PTR))

        ;; Write step text
        (memory.copy (local.get $buf_ptr) (global.get $DBG_STEP) (i32.const 6))
        (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 6)))

        ;; Write "0x" prefix
        (i32.store16 (local.get $buf_ptr) (i32.const 0x7830)) ;; (little endian)
        (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 2)))

        ;; Write step number as hex string
        (call $i32_to_hex_str (local.get $step_no) (local.get $buf_ptr))
        (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 8)))

        ;; Write "  " padding
        (i32.store16 (local.get $buf_ptr) (i32.load16_u (global.get $ASCII_SPACES)))
        (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 2)))

        ;; Write return code text
        (memory.copy (local.get $buf_ptr) (global.get $DBG_RETURN_CODE) (i32.const 13))
        (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 13)))

        ;; Write "0x" prefix
        (i32.store16 (local.get $buf_ptr) (i32.const 0x7830)) ;; (little endian)
        (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 2)))

        ;; Write return code as hex string
        (call $i32_to_hex_str (local.get $ret_code) (local.get $buf_ptr))
        (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 8)))

        ;; Write LF
        (i32.store8 (local.get $buf_ptr) (i32.const 0x0A))
        (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 1)))

        (call $write_to_fd
          (local.get $fd)
          (global.get $STR_WRITE_BUF_PTR)
          (i32.sub (local.get $buf_ptr) (global.get $STR_WRITE_BUF_PTR)) ;; length = end address - start address
        )
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Returns the n'th (one-based) command line argument.
  ;; $wasi.args_get *must* be called before calling this function, otherwise you'll get garbage values back
  ;; The value of $arg_num is not range checked - so don't pass a garbage value!
  ;;
  ;; Returns:
  ;;   i32 -> offset of argument n
  ;;   i32 -> length of argument n
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $fetch_arg_n
        (param $arg_num i32)  ;; One-based argument number being returned
        (result i32 i32)      ;; Offset and length of the value of argument n

    (local $argc         i32)  ;; Argument count returned by wasi_args_get
    (local $argv_buf_len i32)  ;; Argument count returned by wasi_args_get
    (local $arg_n_ptr    i32)
    (local $arg_n_len    i32)

    (local.set $argc         (i32.load (global.get $ARGS_COUNT_PTR)))
    (local.set $argv_buf_len (i32.load (global.get $ARGV_BUF_LEN_PTR)))

    (local.set $arg_n_ptr
      ;; Pointer to arg n = ARGV_PTRS_PTR + ((arg_num - 1) * 4)
      (i32.load
        (i32.add
          (global.get $ARGV_PTRS_PTR)
          (i32.mul (i32.sub (local.get $arg_num) (i32.const 1)) (i32.const 4)))
      )
    )

    (local.tee $arg_n_len
      (i32.sub ;; Need to subtract 1 to account for the value's null terminator
        (if (result i32)
          ;; Are we calculating the length of the last arg?
          (i32.eq (local.get $arg_num) (local.get $argc))
          (then
            ;; Length of last arg = (arg1_ptr + argv_buf_len) - arg_n_ptr
            (i32.sub
              (i32.add (i32.load (global.get $ARGV_PTRS_PTR)) (local.get $argv_buf_len))
              (local.get $arg_n_ptr)
            )
          )
          (else
            ;; Length of nth arg = arg_n+1_ptr - arg_n_ptr
            (i32.sub
              ;; Pointer to arg n+1
              (i32.load (i32.add (global.get $ARGV_PTRS_PTR) (i32.mul (local.get $arg_num) (i32.const 4))))
              (local.get $arg_n_ptr)
            )
          )
        )
        (i32.const 1)
      )
    )
    (local.get $arg_n_ptr)
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Write argc and argv list to stderr
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $write_args_to_stderr
    (local $argc         i32)  ;; Argument count
    (local $argc_count   i32)  ;; Loop counter
    (local $argv_buf_len i32)  ;; Total length of argument string
    (local $arg_ptr      i32)  ;; Pointer to current cmd line argument
    (local $arg_len      i32)  ;; Length of current cmd line argument

    (local.set $argc         (i32.load (global.get $ARGS_COUNT_PTR)))
    (local.set $argv_buf_len (i32.load (global.get $ARGV_BUF_LEN_PTR)))

    ;; Write "argc: 0x" to output buffer followed by value of $argc
    (call $write_msg_with_value (i32.const 2) (global.get $DBG_MSG_ARGC) (i32.const 6) (local.get $argc))

    ;; Print "argv_buf_len: 0x" line followed by the value of argv_buf_len
    (call $write_msg_with_value (i32.const 2) (global.get $DBG_MSG_ARGV_LEN) (i32.const 14) (local.get $argv_buf_len))

    (local.set $argc_count (i32.const 1))

    ;; Write command lines args to output buffer
    (loop $arg_loop
      (local.set $arg_ptr (call $fetch_arg_n (local.get $argc_count)))
      (local.set $arg_len)

      ;; Write the current line to stderr
      (call $writeln_to_fd (i32.const 2) (local.get $arg_ptr) (local.get $arg_len))

      ;; Bump argc_count then repeat as long as argc_count <= argc
      (local.set $argc_count (i32.add (local.get $argc_count) (i32.const 1)))
      (br_if $arg_loop (i32.le_u (local.get $argc_count) (local.get $argc)))
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Convert the i32 pointed to by arg1 into an 8 character ASCII hex string in network byte order
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $i32_ptr_to_hex_str
        (param $i32_ptr i32)  ;; Pointer to the i32 to be converted
        (param $str_ptr i32)  ;; Write the ASCII characters here

    (call $i32_to_hex_str (i32.load (local.get $i32_ptr)) (local.get $str_ptr))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Convert an i32 into an 8 character ASCII hex string in network byte order
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $i32_to_hex_str
        (param $i32_val i32)  ;; i32 to be converted
        (param $str_ptr i32)  ;; Write the ASCII characters here

    (call $byte_to_ascii_pair
      (i32.shr_u (local.get $i32_val) (i32.const 24))
      (local.get $str_ptr)
    )
    (call $byte_to_ascii_pair
      (i32.and (i32.shr_u (local.get $i32_val) (i32.const 16)) (i32.const 0xFF))
      (i32.add (local.get $str_ptr) (i32.const 2))
    )
    (call $byte_to_ascii_pair
      (i32.and (i32.shr_u (local.get $i32_val) (i32.const 8)) (i32.const 0xFF))
      (i32.add (local.get $str_ptr) (i32.const 4))
    )
    (call $byte_to_ascii_pair
      (i32.and (local.get $i32_val) (i32.const 0xFF))
      (i32.add (local.get $str_ptr) (i32.const 6)))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Convert a single byte to a pair of hexadecimal ASCII characters
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $byte_to_ascii_pair
        (param $byte    i32)  ;; Convert this byte
        (param $out_ptr i32)  ;; Write ASCII character pair here

    (local $nybble_hi i32)
    (local $nybble_lo i32)

    ;; Extract the high and low nybbles
    (local.set $nybble_hi (i32.shr_u (local.get $byte) (i32.const 4)))
    (local.set $nybble_lo (i32.and   (local.get $byte) (i32.const 0x0F)))

    (i32.store8
      (local.get $out_ptr)
      (i32.add
        (local.get $nybble_hi)
        ;; If nybble < 10 add 0x30 -> ASCII "0" to "9", else add 0x57 -> ASCII "a" to "f"
        (select (i32.const 0x30) (i32.const 0x57)
          (i32.lt_u (local.get $nybble_hi) (i32.const 0x0A))
        )
      )
    )

    (i32.store8 offset=1
      (local.get $out_ptr)
      (i32.add
        (local.get $nybble_lo)
        ;; If nybble < 10 add 0x30 -> ASCII "0" to "9", else add 0x57 -> ASCII "a" to "f"
        (select (i32.const 0x30) (i32.const 0x57)
          (i32.lt_u (local.get $nybble_lo) (i32.const 0x0A))
        )
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Use the supplied twiddle factors to calculate the sigma value of argument $val
  ;;
  ;; Returns:
  ;;   i32 -> (rotr($val, $rotr1) XOR rotr($val, $rotr2)) XOR shr_u($val, $shr)
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
  ;; Use the supplied twiddle factors to calculate the big sigma value of argument $val
  ;;
  ;; Returns:
  ;;   i32 -> (rotr($val, $rotr1) XOR rotr($val, $rotr2)) XOR rotr($val, $rotr3)
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
  ;;   i32 -> $w1 + $sigma($w2, 7, 8, 13) + $w3 + $sigma($w4, 17, 19, 10)
  (func $gen_msg_digest_word
        (param $ptr i32)
        (result i32)

    (i32.add
      (i32.add
        (i32.load (i32.sub (local.get $ptr) (i32.const 64)))    ;; word_at($ptr - 16 words)
        (call $sigma                                            ;; Calculate sigma0
          (i32.load (i32.sub (local.get $ptr) (i32.const 60)))  ;; word_at($ptr - 15 words)
          (i32.const 7) (i32.const 18) (i32.const 3)            ;; ROTR and SHR twiddle factors
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
    ;; Swizzle big-endian byte order to little-endian order
    (v128.store
      (local.get $msg_blk_ptr)
      (i8x16.swizzle
        (v128.load (local.get $blk_ptr))
        (v128.const i8x16 3 2 1 0 7 6 5 4 11 10 9 8 15 14 13 12)
      )
    )

    (v128.store offset=16
      (local.get $msg_blk_ptr)
      (i8x16.swizzle
        (v128.load (i32.add (local.get $blk_ptr) (i32.const 16)))
        (v128.const i8x16 3 2 1 0 7 6 5 4 11 10 9 8 15 14 13 12)
      )
    )

    (v128.store offset=32
      (local.get $msg_blk_ptr)
      (i8x16.swizzle
        (v128.load (i32.add (local.get $blk_ptr) (i32.const 32)))
        (v128.const i8x16 3 2 1 0 7 6 5 4 11 10 9 8 15 14 13 12)
      )
    )

    (v128.store offset=48
      (local.get $msg_blk_ptr)
      (i8x16.swizzle
        (v128.load (i32.add (local.get $blk_ptr) (i32.const 48)))
        (v128.const i8x16 3 2 1 0 7 6 5 4 11 10 9 8 15 14 13 12)
      )
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
      (local.set $h (local.get $g))                                   ;; $h <- $g
      (local.set $g (local.get $f))                                   ;; $g <- $f
      (local.set $f (local.get $e))                                   ;; $f <- $e
      (local.set $e (i32.add (local.get $d) (local.get $temp1)))      ;; $e <- $d + $temp1
      (local.set $d (local.get $c))                                   ;; $d <- $c
      (local.set $c (local.get $b))                                   ;; $c <- $b
      (local.set $b (local.get $a))                                   ;; $b <- $a
      (local.set $a (i32.add (local.get $temp1) (local.get $temp2)))  ;; $a <- $temp1 + $temp2

      ;; Update index and counter
      (local.set $idx (i32.add (local.get $idx) (i32.const 1)))
      (local.set $n   (i32.sub (local.get $n)   (i32.const 1)))

      (br_if $next_update (i32.gt_u (local.get $n) (i32.const 0)))
    )

    ;; Add working variables to hash values and store back in memory
    ;; We ignore the fact that these addition operations might overflow
    (i32.store           (global.get $HASH_VALS_PTR) (i32.add (local.get $h0) (local.get $a)))
    (i32.store offset=4  (global.get $HASH_VALS_PTR) (i32.add (local.get $h1) (local.get $b)))
    (i32.store offset=8  (global.get $HASH_VALS_PTR) (i32.add (local.get $h2) (local.get $c)))
    (i32.store offset=12 (global.get $HASH_VALS_PTR) (i32.add (local.get $h3) (local.get $d)))
    (i32.store offset=16 (global.get $HASH_VALS_PTR) (i32.add (local.get $h4) (local.get $e)))
    (i32.store offset=20 (global.get $HASH_VALS_PTR) (i32.add (local.get $h5) (local.get $f)))
    (i32.store offset=24 (global.get $HASH_VALS_PTR) (i32.add (local.get $h6) (local.get $g)))
    (i32.store offset=28 (global.get $HASH_VALS_PTR) (i32.add (local.get $h7) (local.get $h)))
  )

;; *********************************************************************************************************************
;; PUBLIC API
;; *********************************************************************************************************************

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Calculate the SHA256 of the supplied file name then write that value to standard out
  ;;
  ;; Returns: None
  (func $sha256sum
        (param $msg_blk_count i32)

    (local $blk_count     i32)
    (local $blk_ptr       i32)
    (local $word_offset   i32)
    (local $step          i32)
    (local $return_code   i32)

    ;; Initialise hash values
    ;; Argument order for memory.copy is non-intuitive: dest_ptr, src_ptr, length
    (memory.copy (global.get $HASH_VALS_PTR) (global.get $INIT_HASH_VALS_PTR) (i32.const 32))

    ;; Process the file as a sequence of 64-byte blocks
    (local.set $blk_ptr (global.get $IOVEC_BUF_ADDR))
    (loop $next_msg_blk
      (call $phase_1 (i32.const 48) (local.get $blk_ptr) (global.get $MSG_DIGEST_PTR))
      (call $phase_2 (i32.const 64))

      (local.set $blk_ptr       (i32.add (local.get $blk_ptr)       (i32.const 64)))
      (local.set $msg_blk_count (i32.sub (local.get $msg_blk_count) (i32.const 1)))

      (br_if $next_msg_blk (i32.gt_u (local.get $msg_blk_count) (i32.const 0)))
    )

    ;; Convert SHA256 value to ASCII
    (loop $next
      (call $i32_ptr_to_hex_str
        (i32.add (global.get $HASH_VALS_PTR)  (i32.shl (local.get $word_offset) (i32.const 2)))
        (i32.add (global.get $ASCII_HASH_PTR) (i32.shl (local.get $word_offset) (i32.const 3)))
      )
      ;; Increment $word_offset
      (local.set $word_offset (i32.add (local.get $word_offset) (i32.const 1)))

      ;; Are we done yet?
      (br_if $next (i32.lt_u (local.get $word_offset) (i32.const 8)))
    )

    ;; Write ASCII representation of the SHA256 value followed by the file name to stdout
    (call $write_to_fd (i32.const 1) (global.get $ASCII_HASH_PTR) (i32.const 64))
    (call $write_to_fd (i32.const 1) (global.get $ASCII_SPACES)   (i32.const 2))
    (call $writeln_to_fd
      (i32.const 1)
      (i32.load (global.get $FILE_PATH_PTR))
      (i32.load (global.get $FILE_PATH_LEN_PTR))
    )
  )
)
