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
  ;; Memory page  34     1 extra memory page for files whose last 2Mb chunk + 9 bytes goes over 2Mb
  (memory $memory (export "memory") 34)

  (global $DEBUG_ACTIVE i32 (i32.const 0))

  ;; Swizzle orders for transforming a little endian i64 to big endian, and 4 little endian i32s to big endian
  (global $SWIZZLE_I64        v128 (v128.const i8x16 7 6 5 4 3 2 1 0 15 14 13 12 11 10 9 8))
  (global $SWIZZLE_I32X4      v128 (v128.const i8x16 3 2 1 0 7 6 5 4 11 10 9 8 15 14 13 12))

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Memory Map
  ;;             Offset  Length   Type    Description
  ;; Page 1: 0x00000000       4   i32     file_fd
  ;;         0x00000008       8   i64     fd_seek file size + 9
  ;;         0x00000010       8   i32x2   Pointer to read iovec buffer address + size
  ;;         0x00000018       8   i32x2   Pointer to write iovec buffer address + size
  ;;         0x00000020       8   i64     Bytes transferred by the last io operation
  ;;         0x00000030       8   i64     File size (Little endian)
  ;;         0x00000040       8   i64     File size (Big endian)
  ;;         0x00000050       4   i32     Pointer to file path name
  ;;         0x00000054       4   i32     Pointer to file path length
  ;; Unused
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;;         0x00000100      32   i32x8   Constants - fractional part of square root of first 8 primes
  ;;         0x00000120     256   i32x64  Constants - fractional part of cube root of first 64 primes
  ;;         0x00000220      64   i32x8   Hash values
  ;;         0x00000260     512   data    Message digest
  ;;         0x00000470      64   data    ASCII representation of SHA value
  ;;         0x000004B0       2   data    Two ASCII spaces
  ;;         0x000004B8       5   data    Error message prefix "Err: "
  ;;         0x000004C0       4   i32     Number of command line arguments
  ;;         0x000004C4       4   i32     Command line buffer size
  ;;         0x000004C8       4   i32     Pointer to array of pointers to arguments (needs double dereferencing!)
  ;;         0x00000500     256   data    Command line args buffer
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;;         0x00000600      26           Error message "File name argument missing"
  ;;         0x00000620      25           Error message "No such file or directory"
  ;;         0x00000640      24           Error message "Unable to read file size"
  ;;         0x00000660      21           Error message "File too large (>4Gb)"
  ;;         0x00000680      18           Error message "Error reading file"
  ;;         0x000006A0      48           Error message "Neither a directory nor a symlink to a directory"
  ;;         0x000006D0      19           Error message "Bad file descriptor"
  ;;         0x000006F0      26           Error message "Memory allocation failed: "
  ;;         0x00000710      23           Error message "Operation not permitted"
  ;;         0x00000730      25           Error message "Filename too long (<=256)"
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;;         0x00000750       6           Debug message "argc: "
  ;;         0x00000760      14           Debug message "argv_buf_len: "
  ;;         0x00000770      15           Debug message "msg_blk_count: "
  ;;         0x00000780       6           Debug message "Step: "
  ;;         0x00000790      13           Debug message "Return code: "
  ;;         0x000007A0      19           Debug message "File size (bytes): "
  ;;         0x000007C0      28           Debug message "Bytes read by wasi.fd_read: "
  ;;         0x000007E0      20           Debug message "wasi.fd_read count: "
  ;;         0x00000800      18           Debug message "Copy to new addr: "
  ;;         0x00000820      18           Debug message "Copy length     : "
  ;;         0x00000850      30           Debug message "Allocated extra memory pages: "
  ;;         0x00000880      27           Debug message "No memory allocation needed"
  ;;         0x000008A0      32           Debug message "Current memory page allocation: "
  ;;         0x000008C0      25           Debug message "wasi.fd_read chunk size: "
  ;;         0x000008E0      22           Debug message "Processing full buffer"
  ;;         0x00000900      17           Debug message "Hit EOF (Partial)"
  ;;         0x00000930      14           Debug message "Hit EOF (Zero)"
  ;;         0x00000940      22           Debug message "Building empty msg blk"
  ;;         0x00000950      18           Debug message "File size (bits): "
  ;;         0x00000970      17           Debug message "Distance to EOB: "
  ;;         0x00000990      12           Debug message "EOD offset: "
  ;; Unused
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

  (global $INIT_HASH_VALS_PTR  i32 (i32.const 0x00000100))
  (global $CONSTANTS_PTR       i32 (i32.const 0x00000120))
  (global $HASH_VALS_PTR       i32 (i32.const 0x00000220))
  (global $MSG_DIGEST_PTR      i32 (i32.const 0x00000260))
  (global $ASCII_HASH_PTR      i32 (i32.const 0x00000470))
  (global $ASCII_SPACES        i32 (i32.const 0x000004B0))
  (global $ERR_MSG_PREFIX      i32 (i32.const 0x000004B8))
  (global $ARGS_COUNT_PTR      i32 (i32.const 0x000004C0))
  (global $ARGV_BUF_LEN_PTR    i32 (i32.const 0x000004C4))
  (global $ARGV_PTRS_PTR       i32 (i32.const 0x000004C8))
  (global $ARGV_BUF_PTR        i32 (i32.const 0x00000500))

  (global $ERR_MSG_NOARG       i32 (i32.const 0x00000600))
  (global $ERR_MSG_NOENT       i32 (i32.const 0x00000620))
  (global $ERR_FILE_SIZE_READ  i32 (i32.const 0x00000640))
  (global $ERR_FILE_TOO_LARGE  i32 (i32.const 0x00000660))
  (global $ERR_READING_FILE    i32 (i32.const 0x00000680))
  (global $ERR_NOT_DIR_SYMLINK i32 (i32.const 0x000006A0))
  (global $ERR_BAD_FD          i32 (i32.const 0x000006D0))
  (global $ERR_MEM_ALLOC       i32 (i32.const 0x000006F0))
  (global $ERR_NOT_PERMITTED   i32 (i32.const 0x00000710))
  (global $ERR_ARGV_TOO_LONG   i32 (i32.const 0x00000730))

  (global $DBG_MSG_ARGC        i32 (i32.const 0x00000750))
  (global $DBG_MSG_ARGV_LEN    i32 (i32.const 0x00000760))
  (global $DBG_MSG_BLK_COUNT   i32 (i32.const 0x00000770))
  (global $DBG_STEP            i32 (i32.const 0x00000780))
  (global $DBG_RETURN_CODE     i32 (i32.const 0x00000790))
  (global $DBG_FILE_SIZE       i32 (i32.const 0x000007A0))
  (global $DBG_BYTES_READ      i32 (i32.const 0x000007C0))
  (global $DBG_READ_COUNT      i32 (i32.const 0x000007E0))
  (global $DBG_COPY_MEM_TO     i32 (i32.const 0x00000800))
  (global $DBG_COPY_MEM_LEN    i32 (i32.const 0x00000820))
  (global $DBG_MEM_GROWN       i32 (i32.const 0x00000850))
  (global $DBG_NO_MEM_ALLOC    i32 (i32.const 0x00000880))
  (global $DBG_MEM_SIZE        i32 (i32.const 0x000008A0))
  (global $DBG_CHUNK_SIZE      i32 (i32.const 0x000008C0))
  (global $DBG_FULL_BUFFER     i32 (i32.const 0x000008E0))
  (global $DBG_EOF_PARTIAL     i32 (i32.const 0x00000900))
  (global $DBG_EOF_ZERO        i32 (i32.const 0x00000930))
  (global $DBG_EMPTY_MSG_BLK   i32 (i32.const 0x00000940))
  (global $DBG_FILE_SIZE_BITS  i32 (i32.const 0x00000950))
  (global $DBG_EOB_DISTANCE    i32 (i32.const 0x00000970))
  (global $DBG_EOD_OFFSET      i32 (i32.const 0x00000990))

  (global $STR_WRITE_BUF_PTR   i32 (i32.const 0x00001000))

  ;; Memory map: Pages 2-34: 2112Kb IO buffer = (2Mb + 64Kb)
  (global $READ_BUFFER_PTR     i32 (i32.const 0x00010000))  ;; Start of memory page 2
  (global $READ_BUFFER_SIZE    i32 (i32.const 0x00200000))  ;; fd_read buffer size = 2Mb

  ;; If you change the value of $READ_BUFFER_SIZE, you must manually update $MSG_BLKS_PER_BUFFER!
  (global $MSG_BLKS_PER_BUFFER i32 (i32.const 0x00008000))  ;; $READ_BUFFER_SIZE / 64

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; The first 32 bits of the fractional part of the square roots of the first 8 primes 2..19
  ;; Used to initialise the hash values
  ;; The byte order of the raw values defined below is little-endian!
  (data (i32.const 0x00000100)                                   ;; $INIT_HASH_VALS_PTR
    "\67\E6\09\6A" "\85\AE\67\BB" "\72\F3\6E\3C" "\3A\F5\4F\A5"  ;; 0x00000100
    "\7F\52\0E\51" "\8C\68\05\9B" "\AB\D9\83\1F" "\19\CD\E0\5B"  ;; 0x00000110
  )

  ;; The first 32 bits of the fractional part of the cube roots of the first 64 primes 2..311
  ;; Used in phase 2 (hash value calculation)
  ;; The byte order of the raw values defined below is little-endian!
  (data (i32.const 0x00000120)                                   ;; $CONSTANTS_PTR
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
  (data (i32.const 0x000004B0) "  ")     ;; Two ASCII spaces
  (data (i32.const 0x000004B8) "Err: ")  ;; Error message prefix

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Debug and error messages
  (data (i32.const 0x00000600) "File name argument missing")
  (data (i32.const 0x00000620) "No such file or directory")
  (data (i32.const 0x00000640) "Unable to read file size")
  (data (i32.const 0x00000660) "File too large (>4Gb)")
  (data (i32.const 0x00000680) "Error reading file")
  (data (i32.const 0x000006A0) "Neither a directory nor a symlink to a directory")
  (data (i32.const 0x000006D0) "Bad file descriptor")
  (data (i32.const 0x000006F0) "Memory allocation failed: ")
  (data (i32.const 0x00000710) "Operation not permitted")
  (data (i32.const 0x00000730) "Filename too long (<=256)")

  (data (i32.const 0x00000750) "argc: ")
  (data (i32.const 0x00000760) "argv_buf_len: ")
  (data (i32.const 0x00000770) "msg_blk_count: ")
  (data (i32.const 0x00000780) "Step: ")
  (data (i32.const 0x00000790) "Return code: ")
  (data (i32.const 0x000007A0) "File size (bytes): ")
  (data (i32.const 0x000007C0) "Bytes read by wasi.fd_read: ")
  (data (i32.const 0x000007E0) "wasi.fd_read count: ")
  (data (i32.const 0x00000800) "Copy to new addr: ")
  (data (i32.const 0x00000820) "Copy length     : ")
  (data (i32.const 0x00000850) "Allocated extra memory pages: ")
  (data (i32.const 0x00000880) "No memory allocation needed")
  (data (i32.const 0x000008A0) "Current memory page allocation: ")
  (data (i32.const 0x000008C0) "wasi.fd_read chunk size: ")
  (data (i32.const 0x000008E0) "Processing full buffer")
  (data (i32.const 0x00000900) "Hit EOF (Partial): ")
  (data (i32.const 0x00000930) "Hit EOF (Zero): ")
  (data (i32.const 0x00000940) "Building empty msg blk")
  (data (i32.const 0x00000950) "File size (bits): ")
  (data (i32.const 0x00000970) "Distance to EOB: ")
  (data (i32.const 0x00000990) "EOD offset: ")

  ;; *******************************************************************************************************************
  ;; PUBLIC API
  ;; *******************************************************************************************************************

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; The "_start" function is called automatically by the host environment
  ;;
  ;; * Count and extract the command line arguments
  ;; * Attempt to open the file
  ;; * Read file size
  ;; * Repeatedly call wasi.fd_read processing each 2Mb chunk
  ;; * When we hit the last chunk, terminate the data with an end-of-data marker (0x80) and write the file length in
  ;;   bits as a 64-bit big endian integer to the last 8 bytes of the last message block
  ;; * Convert the SHA256 hash value to ASCII and write it to stdout
  ;;
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func (export "_start")
    (local $argc            i32) ;; Argument count
    (local $argv_buf_len    i32) ;; Total argument length.  Each argument value is null terminated
    (local $filename_ptr    i32)
    (local $filename_len    i32)
    (local $file_fd         i32) ;; File descriptor of target file
    (local $bytes_read      i32) ;; How many bytes fd_read has returned
    (local $copy_to_addr    i32) ;; Where should the next file chunk be written
    (local $msg_blk_count   i32) ;; File contains this many 64-byte message blocks
    (local $eod_offset      i32) ;; Offset down the read buffer for the EOD marker
    (local $distance_to_eob i32) ;; Distance from EOD marker to end of current message block
    (local $return_code     i32)
    (local $step            i32)
    (local $blk_ptr         i32)
    (local $word_offset     i32)
    (local $file_size_bytes i32)
    (local $bytes_remaining i32) ;; Counts down to zero after calls to wasi.fd_read

    ;; Initialise hash values
    (memory.copy (global.get $HASH_VALS_PTR) (global.get $INIT_HASH_VALS_PTR) (i32.const 32))

    (block $exit
      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 0: Fetch command line arguments
      ;;
      ;; NodeJS supplies 3 arguments, but other environments such as wasmer and wasmtime supply only 2
      ;; Either way, we expect the file name to be the last argument
      (call $wasi.args_sizes_get (global.get $ARGS_COUNT_PTR) (global.get $ARGV_BUF_LEN_PTR))
      drop  ;; This is always 0, so ignore it

      ;; Remember the argument count and the total length of arguments
      (local.set $argc (i32.load (global.get $ARGS_COUNT_PTR)))

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

      (if ;; less than 2 arguments have been supplied
        (i32.lt_u (local.get $argc) (i32.const 2))
        (then
          ;; (call $write_step (i32.const 2) (local.get $step) (i32.const 4))
          (call $writeln (i32.const 2) (global.get $ERR_MSG_NOARG) (i32.const 26))
          (br $exit)
        )
      )

      ;; $ARGV_PTRS_PTR points to an array of size [$argc; i32] containing pointers to each command line arg
      (call $wasi.args_get (global.get $ARGV_PTRS_PTR) (global.get $ARGV_BUF_PTR))
      drop  ;; This is always 0, so ignore it

      ;; (call $write_args)

      ;; Fetch pointer to the filename (last pointer in the list)
      (local.set $filename_ptr (call $fetch_arg_n (local.get $argc)))
      (local.set $filename_len)

      (i32.store (global.get $FILE_PATH_PTR)     (local.get $filename_ptr))
      (i32.store (global.get $FILE_PATH_LEN_PTR) (local.get $filename_len))

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
      (call $file_size_get
        (local.tee $step (i32.add (local.get $step) (i32.const 1)))
        (local.get $file_fd)
      )

      ;; If the file size >= 4Gb, then pack up and go home because WASM cannot process a file that big...
      (if
        (i64.ge_u (i64.load (global.get $FILE_SIZE_PTR)) (i64.const 4294967296))
        (then
          ;; (call $write_step (i32.const 2) (local.get $step) (i32.const 0x16)) ;; Return code 22 means file too large
          (call $writeln (i32.const 2) (global.get $ERR_FILE_TOO_LARGE) (i32.const 21))
          (br $exit)
        )
      )

      (local.set $file_size_bytes (i32.wrap_i64 (i64.load (global.get $FILE_SIZE_PTR)))) ;; We know the size < 4Gb
      ;; (call $write_msg_with_value (i32.const 1) (global.get $DBG_FILE_SIZE) (i32.const 19) (local.get $file_size_bytes))

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 3: Read file contents in chunks defined by $READ_BUFFER_SIZE
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.set $bytes_remaining (local.get $file_size_bytes)) ;; Nothing has been read from the file yet
      ;; (call $write_msg_with_value (i32.const 1) (global.get $DBG_CHUNK_SIZE) (i32.const 25) (global.get $READ_BUFFER_SIZE))

      (i32.store          (global.get $IOVEC_READ_BUF_PTR) (global.get $READ_BUFFER_PTR))
      (i32.store offset=4 (global.get $IOVEC_READ_BUF_PTR) (global.get $READ_BUFFER_SIZE))

      (block $process_file
        ;; Keep reading file until $wasi.fd_read returns 0 bytes
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
              ;; (call $write_step (i32.const 2) (local.get $step) (local.get $return_code))
              (call $writeln (i32.const 2) (global.get $ERR_READING_FILE) (i32.const 18))
              (br $exit)
            )
          )

          (local.set $bytes_remaining
            (i32.sub
              (local.get $bytes_remaining)
              (local.tee $bytes_read (i32.load (global.get $NREAD_PTR)))
            )
          )

          ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
          ;; How many message blocks does the read buffer contain?
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
              (if ;; we've read more than zero bytes
                (local.get $bytes_read) ;; > 0
                (then ;; we're about to process the last chunk
                  ;; (call $write_msg (i32.const 1) (global.get $DBG_EOF_PARTIAL) (i32.const 17))
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
                      ;; (call $write_msg_with_value
                      ;;   (i32.const 1)
                      ;;   (global.get $DBG_EOB_DISTANCE) (i32.const 17)
                      ;;   (local.get $distance_to_eob)
                      ;; )
                      (memory.fill
                        ;; Don't overwrite the EOD marker!
                        (i32.add (global.get $READ_BUFFER_PTR) (i32.add (local.get $eod_offset) (i32.const 1)))
                        (i32.const 0)
                        (local.get $distance_to_eob)
                      )
                    )
                  )

                  ;; (call $write_msg_with_value
                  ;;   (i32.const 1)
                  ;;   (global.get $DBG_MSG_BLK_COUNT) (i32.const 15)
                  ;;   (local.get $msg_blk_count)
                  ;; )

                  (call $write_file_size (local.get $msg_blk_count))
                )
                ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                (else ;; fd_read returned 0 bytes, so we're done
                  ;; (call $write_msg (i32.const 1) (global.get $DBG_EOF_ZERO) (i32.const 14))
                  (br $process_file)
                )
              )
            )
          )

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
        )
      )

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 4: Close file
      (local.set $step (i32.add (local.get $step) (i32.const 1)))
      (local.set $return_code (call $wasi.fd_close (local.get $file_fd)))
      ;; (call $write_step (i32.const 1) (local.get $step) (local.get $return_code))

      ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ;; Step 5: Print SHA256 value
      ;; Convert SHA256 value to ASCII
      (local.set $step (i32.add (local.get $step) (i32.const 1)))

      (loop $next
        (call $i32_ptr_to_hex_str
          (i32.add (global.get $HASH_VALS_PTR)  (i32.shl (local.get $word_offset) (i32.const 2)))
          (i32.add (global.get $ASCII_HASH_PTR) (i32.shl (local.get $word_offset) (i32.const 3)))
        )

        ;; Have we converted all 8 words to ASCII?
        (br_if $next
          (i32.lt_u
            (local.tee $word_offset (i32.add (local.get $word_offset) (i32.const 1)))
            (i32.const 8)
          )
        )
      )

      ;; Write ASCII representation of the SHA256 hash followed by the file name to stdout
      (call $write (i32.const 1) (global.get $ASCII_HASH_PTR) (i32.const 64))
      (call $write (i32.const 1) (global.get $ASCII_SPACES)   (i32.const 2))
      (call $writeln
        (i32.const 1)
        (i32.load (global.get $FILE_PATH_PTR))
        (i32.load (global.get $FILE_PATH_LEN_PTR))
      )
      ;; (call $write_step (i32.const 1) (local.get $step) (i32.const 0))
    )
  )

  ;; *******************************************************************************************************************
  ;; PRIVATE API
  ;; *******************************************************************************************************************

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; For debugging purposes only.
  ;; Write a 64-byte message block in hexdump -C format
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $hexdump
        (param $fd      i32) ;; Write to this file descriptor
        (param $blk_ptr i32) ;; Pointer to 64 byte block

    (local $buf_ptr    i32)
    (local $buf_len    i32)
    (local $byte_count i32)
    (local $line_count i32)
    (local $this_byte  i32)

    (if (global.get $DEBUG_ACTIVE)
      (then
        (local.set $buf_ptr (global.get $STR_WRITE_BUF_PTR))

        (loop $lines
          ;; Write memory address
          (call $i32_to_hex_str (local.get $blk_ptr) (local.get $buf_ptr))
          (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 8)))
          (local.set $buf_len (i32.add (local.get $buf_len) (i32.const 8)))

          ;; Two ASCI spaces
          (i32.store16 (local.get $buf_ptr) (i32.load16_u (global.get $ASCII_SPACES)))
          (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 2)))
          (local.set $buf_len (i32.add (local.get $buf_len) (i32.const 2)))

          ;; Write the next 16 bytes as space delimited hex character pairs
          (local.set $byte_count (i32.const 0))
          (loop $hex_chars
            ;; Fetch the next character
            (local.set $this_byte (i32.load8_u (local.get $blk_ptr)))

            ;; Write the current byte as two ASCII characters
            (call $to_asc_pair (local.get $this_byte) (local.get $buf_ptr))
            (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 2)))
            (local.set $buf_len (i32.add (local.get $buf_len) (i32.const 2)))

            ;; Write a space delimiter
            (i32.store8 (local.get $buf_ptr) (i32.const 0x20))
            (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 1)))
            (local.set $buf_len (i32.add (local.get $buf_len) (i32.const 1)))

            (if ;; we've just written the 8th byte
              (i32.eq (local.get $byte_count) (i32.const 7))
              (then
                ;; Write an extra space
                (i32.store8 (local.get $buf_ptr) (i32.const 0x20))
                (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 1)))
                (local.set $buf_len (i32.add (local.get $buf_len) (i32.const 1)))
              )
            )

            (local.set $byte_count (i32.add (local.get $byte_count) (i32.const 1)))
            (local.set $blk_ptr    (i32.add (local.get $blk_ptr)    (i32.const 1)))

            (br_if $hex_chars (i32.lt_u (local.get $byte_count) (i32.const 16)))
          )

          ;; Write " |"
          (i32.store16 (local.get $buf_ptr) (i32.const 0x7C20)) ;; space + pipe (little endian)
          (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 2)))
          (local.set $buf_len (i32.add (local.get $buf_len) (i32.const 2)))

          ;; Move $blk_ptr back 16 characters and output the same 16 bytes as ASCII characters
          (local.set $blk_ptr (i32.sub (local.get $blk_ptr) (i32.const 16)))
          (local.set $byte_count (i32.const 0))
          (loop $ascii_chars
            ;; Fetch the next character
            (local.set $this_byte (i32.load8_u (local.get $blk_ptr)))

            (i32.store8
              (local.get $buf_ptr)
              ;; Only print bytes in the 7-bit ASCII range (32 <= &this_byte < 128)
              (select
                (i32.const 0x2E)       ;; Substitute a '.'
                (local.get $this_byte) ;; Character is printable
                (i32.or
                  (i32.lt_u (local.get $this_byte) (i32.const 0x20))
                  (i32.ge_u (local.get $this_byte) (i32.const 0x80))
                )
              )
            )

            ;; Bump all the counters etc
            (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 1)))
            (local.set $buf_len (i32.add (local.get $buf_len) (i32.const 1)))
            (local.set $blk_ptr (i32.add (local.get $blk_ptr) (i32.const 1)))

            (br_if $ascii_chars
              (i32.lt_u
                (local.tee $byte_count (i32.add (local.get $byte_count) (i32.const 1)))
                (i32.const 16)
              )
            )
          )

          ;; Write "|\n"
          (i32.store16 (local.get $buf_ptr) (i32.const 0x0A7C)) ;; pipe + LF (little endian)
          (local.set $buf_ptr    (i32.add (local.get $buf_ptr)    (i32.const 2)))
          (local.set $buf_len    (i32.add (local.get $buf_len)    (i32.const 2)))
          (local.set $line_count (i32.add (local.get $line_count) (i32.const 1)))

          (br_if $lines (i32.lt_u (local.get $line_count) (i32.const 4)))
        )

        (call $write (local.get $fd) (global.get $STR_WRITE_BUF_PTR) (local.get $buf_len))
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; For debugging purposes only.
  ;; This function does nothing unless either $DEBUG_ACTIVE is true or we're writing to stderr
  ;; Write a debug/trace message to the specified fd
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $write_msg
        (param $fd      i32)  ;; Write to this file descriptor
        (param $msg_ptr i32)  ;; Pointer to error message text
        (param $msg_len i32)  ;; Length of error message

    (local $buf_ptr i32)

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

        ;; Write LF
        (i32.store8 (local.get $buf_ptr) (i32.const 0x0A))
        (local.set $buf_ptr (i32.add (local.get $buf_ptr) (i32.const 1)))

        (call $write
          (local.get $fd)
          (global.get $STR_WRITE_BUF_PTR)
          (i32.sub (local.get $buf_ptr) (global.get $STR_WRITE_BUF_PTR)) ;; length = end address - start address
        )
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; For debugging purposes only.
  ;; This function does nothing unless either $DEBUG_ACTIVE is true or we're writing to stderr
  ;; Write a debug/trace message plus a value to the specified fd
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $write_msg_with_value
      (param $fd      i32)  ;; Write to this file descriptor
      (param $msg_ptr i32)  ;; Pointer to error message text
      (param $msg_len i32)  ;; Length of error message
      (param $msg_val i32)  ;; Some i32 value to be prefixed with "0x" then printed after the message text

    (local $buf_ptr i32)

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

        (call $write
          (local.get $fd)
          (global.get $STR_WRITE_BUF_PTR)
          (i32.sub (local.get $buf_ptr) (global.get $STR_WRITE_BUF_PTR)) ;; length = end address - start address
        )
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; For debugging purposes only.
  ;; Write the return code of the current processing step to the specified fd
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $write_step
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

        (call $write
          (local.get $fd)
          (global.get $STR_WRITE_BUF_PTR)
          (i32.sub (local.get $buf_ptr) (global.get $STR_WRITE_BUF_PTR)) ;; length = end address - start address
        )
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; For debugging purposes only.
  ;; Write argc and argv list to stdout
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $write_args
    (local $argc         i32)  ;; Argument count
    (local $argc_count   i32)  ;; Loop counter
    (local $argv_buf_len i32)  ;; Total length of argument string
    (local $arg_ptr      i32)  ;; Pointer to current cmd line argument
    (local $arg_len      i32)  ;; Length of current cmd line argument

    (local.set $argc         (i32.load (global.get $ARGS_COUNT_PTR)))
    (local.set $argv_buf_len (i32.load (global.get $ARGV_BUF_LEN_PTR)))

    ;; Write "argc: 0x" to output buffer followed by value of $argc
    (call $write_msg_with_value (i32.const 1) (global.get $DBG_MSG_ARGC) (i32.const 6) (local.get $argc))

    ;; Print "argv_buf_len: 0x" line followed by the value of argv_buf_len
    (call $write_msg_with_value (i32.const 1) (global.get $DBG_MSG_ARGV_LEN) (i32.const 14) (local.get $argv_buf_len))

    (local.set $argc_count (i32.const 1))

    ;; Write command lines args to output buffer
    (loop $arg_loop
      (local.set $arg_ptr (call $fetch_arg_n (local.get $argc_count)))
      (local.set $arg_len)

      (call $writeln (i32.const 1) (local.get $arg_ptr) (local.get $arg_len))

      ;; Repeat while argc_count <= argc
      (br_if $arg_loop
        (i32.le_u
          (local.tee $argc_count (i32.add (local.get $argc_count) (i32.const 1)))
          (local.get $argc)
        )
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Write end-of-data marker (0x80) to specified location in the read buffer
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $write_eod_marker
        (param $eod_offset i32)  ;; The offset down the read buffer at which the EOD marker should be written

    ;; (call $write_msg_with_value (i32.const 1) (global.get $DBG_EOD_OFFSET) (i32.const 12) (local.get $eod))
    (i32.store8 (i32.add (global.get $READ_BUFFER_PTR) (local.get $eod_offset)) (i32.const 0x80))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Write the file size in bits as an 64-bit, big endian integer to the last 8 bytes of the last message block
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $write_file_size
        (param $msg_blk_count i32)  ;; Must be >= 1
    (i64.store (global.get $FILE_SIZE_LE_PTR) (i64.shl (i64.load (global.get $FILE_SIZE_PTR)) (i64.const 3)))
    (v128.store
      (global.get $FILE_SIZE_BE_PTR)
      (i8x16.swizzle (v128.load (global.get $FILE_SIZE_LE_PTR)) (global.get $SWIZZLE_I64))
    )

    ;; (call $write_msg_with_value
    ;;   (i32.const 1)
    ;;   (global.get $DBG_FILE_SIZE) (i32.const 19)
    ;;   (i32.wrap_i64 (i64.load (global.get $FILE_SIZE_PTR)))
    ;; )

    ;; (call $write_msg_with_value
    ;;   (i32.const 1)
    ;;   (global.get $DBG_FILE_SIZE_BITS) (i32.const 18)
    ;;   (i32.wrap_i64 (i64.load (global.get $FILE_SIZE_LE_PTR)))
    ;; )

    ;; Write big endian file size to the last 8 bytes of the last message block
    ;; offset = $READ_BUF_PTR + ($msg_blk_count * 64) - 8
    (i64.store
      (i32.sub
        (i32.add
          (global.get $READ_BUFFER_PTR)
          (i32.shl (local.get $msg_blk_count) (i32.const 6))
        )
        (i32.const 8)
      )
      (i64.load (global.get $FILE_SIZE_BE_PTR))
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
          ;; (call $write_step (i32.const 2) (local.get $step) (local.get $return_code))

          ;; Bad file descriptor (Did the target directory suddenly disappear since starting the program?)
          (if (i32.eq (local.get $return_code) (i32.const 0x08))
            (then (call $writeln (i32.const 2) (global.get $ERR_BAD_FD) (i32.const 19)))
          )

          ;; File not found
          (if (i32.eq (local.get $return_code) (i32.const 0x2c))
            (then (call $writeln (i32.const 2) (global.get $ERR_MSG_NOENT) (i32.const 25)))
          )

          ;; Not a directory or a symlink to a directory (probably bad values passed to --mapdir)
          (if (i32.eq (local.get $return_code) (i32.const 0x36))
            (then (call $writeln (i32.const 2) (global.get $ERR_NOT_DIR_SYMLINK) (i32.const 48)))
          )

          ;; Operation not permitted
          (if (i32.eq (local.get $return_code) (i32.const 0x3F))
            (then (call $writeln (i32.const 2) (global.get $ERR_NOT_PERMITTED) (i32.const 23)))
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
  ;; Discover the size of an open file descriptor
  ;;
  ;; If calling fd_seek fails for any reason, then the target file has probably been moved or deleted since the program
  ;; started.  This makes it impossible to continue, so we immediately throw our toys out of pram.  Consequently, this
  ;; function will either succeed or fail catastrophically - hence no need for a return code
  ;;
  ;; Return:
  ;;   Indirect -> File size is written to location held in the global pointer $FILE_SIZE_PTR
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $file_size_get
        (param $step    i32) ;; Arbitrary processing step number (only used for error tracing)
        (param $file_fd i32) ;; File fd (must point to a file that has already been opened with seek capability)

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
        ;; (call $write_step (i32.const 2) (local.get $step) (local.get $return_code))
        (call $writeln (i32.const 2) (global.get $ERR_FILE_SIZE_READ) (i32.const 24))
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
        (call $writeln (i32.const 2) (global.get $ERR_FILE_SIZE_READ) (i32.const 24))
        unreachable
      )
    )

    ;; After seek pointer reset, write file size back to the expected location
    (i64.store (global.get $FILE_SIZE_PTR) (local.get $file_size_bytes))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Write data to the console on either stdout or stderr
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $write
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
  ;; Write data to the console on either stdout or stderr followed by a line feed
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $writeln
        (param $fd      i32)  ;; File descriptor
        (param $str_ptr i32)  ;; Pointer to string
        (param $str_len i32)  ;; String length

    (local $write_buf_ptr i32)
    (local.set $write_buf_ptr (global.get $STR_WRITE_BUF_PTR))

    (if ;; we're writing to stderr
      (i32.eq (local.get $fd) (i32.const 2))
      (then ;; prefix the message with "Err: "
        (memory.copy (local.get $write_buf_ptr) (global.get $ERR_MSG_PREFIX) (i32.const 5))
        (local.set $write_buf_ptr (i32.add (local.get $write_buf_ptr) (i32.const 5)))
      )
    )

    (memory.copy (local.get $write_buf_ptr) (local.get $str_ptr) (local.get $str_len))
    (local.set $write_buf_ptr (i32.add (local.get $write_buf_ptr) (local.get $str_len)))

    (i32.store (local.get $write_buf_ptr) (i32.const 0x0A))
    (call $write
      (local.get $fd)
      (global.get $STR_WRITE_BUF_PTR)
      ;; Length = end address - start address
      (i32.sub (i32.add (local.get $write_buf_ptr) (i32.const 1)) (global.get $STR_WRITE_BUF_PTR))
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
          (i32.shl (i32.sub (local.get $arg_num) (i32.const 1)) (i32.const 2))
        )
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
  ;; Convert a nybble to its corresponding ASCII value
  ;; Returns: i32
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $nybble_to_asc
        (param $nybble i32)
        (result i32)

    (i32.add
      (local.get $nybble)
      ;; If nybble < 10 add 0x30 -> ASCII "0" to "9", else add 0x57 -> ASCII "a" to "f"
      (select (i32.const 0x30) (i32.const 0x57)
        (i32.lt_u (local.get $nybble) (i32.const 0x0A))
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Convert a single byte to a pair of hexadecimal ASCII characters
  ;; Returns: None
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $to_asc_pair
        (param $byte    i32)  ;; Convert this byte
        (param $out_ptr i32)  ;; Write ASCII character pair here
    (i32.store8          (local.get $out_ptr) (call $nybble_to_asc (i32.shr_u (local.get $byte) (i32.const 4))))
    (i32.store8 offset=1 (local.get $out_ptr) (call $nybble_to_asc (i32.and   (local.get $byte) (i32.const 0x0F))))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Convert the i32 pointed to by arg1 into an 8 character ASCII hex string in network byte order
  ;; Returns:
  ;;   Indirect -> Writes output to specified location
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $i32_ptr_to_hex_str
        (param $i32_ptr i32)  ;; Pointer to the i32 to be converted
        (param $str_ptr i32)  ;; Write the ASCII characters here

    (call $i32_to_hex_str (i32.load (local.get $i32_ptr)) (local.get $str_ptr))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Convert an i32 into an 8 character ASCII hex string in network byte order
  ;; Returns:
  ;;   Indirect -> Writes output to specified location
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  (func $i32_to_hex_str
        (param $i32_val i32)  ;; i32 to be converted
        (param $str_ptr i32)  ;; Write the ASCII characters here

    (call $to_asc_pair (i32.shr_u (local.get $i32_val) (i32.const 24)) (local.get $str_ptr))
    (call $to_asc_pair
      (i32.and (i32.shr_u (local.get $i32_val) (i32.const 16)) (i32.const 0xFF))
      (i32.add (local.get $str_ptr) (i32.const 2))
    )
    (call $to_asc_pair
      (i32.and (i32.shr_u (local.get $i32_val) (i32.const 8)) (i32.const 0xFF))
      (i32.add (local.get $str_ptr) (i32.const 4))
    )
    (call $to_asc_pair (i32.and (local.get $i32_val) (i32.const 0xFF)) (i32.add (local.get $str_ptr) (i32.const 6)))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Functionality common to both $sigma() and $big_sigma() functions
  ;;
  ;; Returns:
  ;;   i32 -> rotr($val, $rotr1) XOR rotr($val, $rotr2)
  (func $inner_sigma
        (param $val   i32)  ;; Raw binary value
        (param $rotr1 i32)  ;; ROTR twiddle factor 1
        (param $rotr2 i32)  ;; ROTR twiddle factor 2
        (result i32)

    (i32.xor
      (i32.rotr (local.get $val) (local.get $rotr1))
      (i32.rotr (local.get $val) (local.get $rotr2))
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
      (call $inner_sigma (local.get $val) (local.get $rotr1) (local.get $rotr2))
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
      (call $inner_sigma (local.get $val) (local.get $rotr1) (local.get $rotr2))
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
  ;; Phase 1: Create a 256-byte message digest using the contents of the supplied 64-byte message block
  ;;
  ;; 1) Transfer the current message block into words 0..15 of the message digest
  ;; 2) Populate words 16..63 of the message digest based on words 0..15
  ;;
  ;; For debugging purposes, the number of loop iterations was parameterized instead of hardcoding it to 48
  ;;
  ;; Returns: None
  (func $sha_phase_1
    (param $n           i32) ;; In normal operation, $n is always 48
    (param $blk_ptr     i32) ;; Pointer to the 256-byte message digest
    (param $msg_blk_ptr i32) ;; Pointer to the 64-byte message block

    (local $ptr i32)

    ;; Transfer the current message block to words 0..15 of the message digest transforming the data into network (big endian) byte order.
    (v128.store           (local.get $msg_blk_ptr) (i8x16.swizzle (v128.load           (local.get $blk_ptr)) (global.get $SWIZZLE_I32X4)))
    (v128.store offset=16 (local.get $msg_blk_ptr) (i8x16.swizzle (v128.load offset=16 (local.get $blk_ptr)) (global.get $SWIZZLE_I32X4)))
    (v128.store offset=32 (local.get $msg_blk_ptr) (i8x16.swizzle (v128.load offset=32 (local.get $blk_ptr)) (global.get $SWIZZLE_I32X4)))
    (v128.store offset=48 (local.get $msg_blk_ptr) (i8x16.swizzle (v128.load offset=48 (local.get $blk_ptr)) (global.get $SWIZZLE_I32X4)))

    ;; Starting at word 16, populate the next $n words of the message digest
    (local.set $ptr (i32.add (global.get $MSG_DIGEST_PTR) (i32.const 64)))

    (loop $next_word
      (i32.store (local.get $ptr) (call $gen_msg_digest_word (local.get $ptr)))
      (local.set $ptr (i32.add (local.get $ptr) (i32.const 4)))

      (br_if $next_word
        (i32.gt_u
          (local.tee $n (i32.sub (local.get $n) (i32.const 1)))
          (i32.const 0)
        )
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Phase 2: Process message digest to obtain new hash values
  ;;
  ;; 1) Set working variables to current hash values
  ;; 2) For each of the 64 words in the message digest
  ;;    a) Calculate the two temporary values
  ;;    b) Shunt working variables
  ;; 3) Add working variable values to corresponding hash values
  ;;
  ;; For debugging purposes, the number of loop iterations was parameterized instead of hardcoding it to 64
  ;;
  ;; Returns: None
  (func $sha_phase_2
        (param $n i32)

    (local $idx i32)

    ;; Current hash values and their corresponding internal working variables
    (local $h0 i32) (local $h1 i32) (local $h2 i32) (local $h3 i32) (local $h4 i32) (local $h5 i32) (local $h6 i32) (local $h7 i32)
    (local $a  i32) (local $b  i32) (local $c  i32) (local $d  i32) (local $e  i32) (local $f  i32) (local $g  i32) (local $h  i32)

    (local $temp1 i32)
    (local $temp2 i32)

    ;; Remember the current hash values then store them as the new working variables
    (local.set $a (local.tee $h0 (i32.load           (global.get $HASH_VALS_PTR))))
    (local.set $b (local.tee $h1 (i32.load offset=4  (global.get $HASH_VALS_PTR))))
    (local.set $c (local.tee $h2 (i32.load offset=8  (global.get $HASH_VALS_PTR))))
    (local.set $d (local.tee $h3 (i32.load offset=12 (global.get $HASH_VALS_PTR))))
    (local.set $e (local.tee $h4 (i32.load offset=16 (global.get $HASH_VALS_PTR))))
    (local.set $f (local.tee $h5 (i32.load offset=20 (global.get $HASH_VALS_PTR))))
    (local.set $g (local.tee $h6 (i32.load offset=24 (global.get $HASH_VALS_PTR))))
    (local.set $h (local.tee $h7 (i32.load offset=28 (global.get $HASH_VALS_PTR))))

    (loop $next_word
      ;; temp1 = $h + $big_sigma1($e) + constant($idx) + msg_digest_word($idx) + $choice($e, $f, $g)
      (local.set $temp1
        (i32.add
          (i32.add
            (i32.add
              (local.get $h)
              (call $big_sigma (local.get $e) (i32.const 6) (i32.const 11) (i32.const 25))
            )
            (i32.add
              ;; Fetch constant and message digest word at word offset $idx
              (i32.load (i32.add (global.get $CONSTANTS_PTR)  (i32.shl (local.get $idx) (i32.const 2))))
              (i32.load (i32.add (global.get $MSG_DIGEST_PTR) (i32.shl (local.get $idx) (i32.const 2))))
            )
          )
          ;; choice($e, $f, $g) = ($e AND $f) XOR (NOT($e) AND $G)
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
          ;; $majority($a, $b, $c) = ($a AND $b) XOR ($a AND $c) XOR ($b AND $c)
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

      (br_if $next_word (local.tee $n (i32.sub (local.get $n) (i32.const 1))))
    )

    ;; Add working variables to hash values and store back in memory
    ;; We purposefully ignore the fact that these additions might overflow
    (i32.store           (global.get $HASH_VALS_PTR) (i32.add (local.get $h0) (local.get $a)))
    (i32.store offset=4  (global.get $HASH_VALS_PTR) (i32.add (local.get $h1) (local.get $b)))
    (i32.store offset=8  (global.get $HASH_VALS_PTR) (i32.add (local.get $h2) (local.get $c)))
    (i32.store offset=12 (global.get $HASH_VALS_PTR) (i32.add (local.get $h3) (local.get $d)))
    (i32.store offset=16 (global.get $HASH_VALS_PTR) (i32.add (local.get $h4) (local.get $e)))
    (i32.store offset=20 (global.get $HASH_VALS_PTR) (i32.add (local.get $h5) (local.get $f)))
    (i32.store offset=24 (global.get $HASH_VALS_PTR) (i32.add (local.get $h6) (local.get $g)))
    (i32.store offset=28 (global.get $HASH_VALS_PTR) (i32.add (local.get $h7) (local.get $h)))
  )
)
