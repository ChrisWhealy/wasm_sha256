# Step 3: Plan the Layout of Linear Memory

Planning how you want to layout linear memory is both very import, and not something you can get right on your first (or second, or third...) attempt.

In reality, memory layout is something that evolves during development.
That said, there are some tips and tricks I've learned that can make life a lot easier:

1. Don't worry about a few empty bytes here and there &mdash; or to say that the other way around, don't tightly pack values into memory: leave some space between values, beacuse wherever possible, you should
2. Align values to word boundaries
3. Leave a reasonable amount of space between values whose length you will not know until runtime (E.G. the command line arguments)
4. Never hardcode pointer addresses!

   The reason for this is simple: as you are developing your application, you are ***going*** to need to rearrange the memory layout.
   Therefore, if a pointer is always stored as a global value and you need to change it, you only need to change the code in one place.
5. Define one region of memory for pointers and lengths and a separate reqion for string values (E.G. error or debug/trace messages).
   How you choose to divide up memory is entirely arbitrary, but you need to formulate a plan, and then stick to it.

For instance, the first 1.5Kb or so of memory page 1 has been arranged like this:

```wat
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
```

Based on this map, the following global declarations are then made:

```wat
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
```

Almost all of these values store pointer locations.

So for example, after `$wasi.fd_read` has been called to read some data from a file, the pointer `$NREAD_PTR` points to the memory location where there is an `i32` holding the number of bytes that have just been read.
