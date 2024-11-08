# WebAssembly Text Programming Tips and Tricks

Whenever I write a program directly in WebAssembly Text, I have found that the following tips and tricks make life a lot easier.

1. Always plan memory usage and then write out a memory map!

   If you do not keep very careful track of what value lives at what memory location and how long it is, you might easily find your coding has trampled all over its own data!

   In this example, I have mapped out the start of the memory in page 1 as follows

   ```wat
   ;; Memory Map
   ;;             Offset  Length   Type    Description
   ;; Page 1: 0x00000000       4   i32     file_fd
   ;;         0x00000004       4           Unused
   ;;         0x00000008       8   i64     fd_seek file size + 9
   ;;         0x00000010       8   i32x2   Pointer to iovec buffer, iovec buffer size
   ;;         0x00000018       8   i64     Bytes transferred by the last io operation
   ```

1. Never hard code address values within the coding itself because this will rapidly become unmanageble if (when!) you decide to rearrange the memory layout.

   So the locations shown in the memory map above have the following corresponding global declarations:

   ```wat
   (global $FD_FILE_PTR        i32 (i32.const 0x00000000))
   (global $FILE_SIZE_PTR      i32 (i32.const 0x00000008))
   (global $IOVEC_BUF_PTR      i32 (i32.const 0x00000010))
   (global $IO_BYTES_PTR       i32 (i32.const 0x00000018))
   ```

   Now, whenever you want to access a value in memory, you can address it via a global pointer whose value is defined once.

1. There is no bounds checking for reading from or writing to WebAssembly variables!

   Although a WebAssembly module is completely sandboxed and it is impossible to write to a memory location outside the module's scope, you have unlimited access to any and all locations within your own memory.

   Therefore, if you don't keep careful checks on the length of data you read or write, you could easily "buffer overrun" your own data.

   In other words, there is the potential to make a big mess very quickly.

1. During development, it is very useful to create one or more log functions in JavaScript that can be called from various locations in your WebAssembly program.

   I have created a logging function that is imported into WebAssembly using the name `$log_msg`.
   This function tales 3 `i32` arguments:

   1. A step number
   2. A message id number
   3. The `i32` value to be displayed (as a decimal integer)

   Both the step number and the message id are arbitrary numbers used to identify which processing step has been reached, and which value is being displayed.

   The JavaScript coding can be found in [`/utils/log_utils.mjs`](https://github.com/ChrisWhealy/wasm_sha256/blob/main/utils/log_utils.mjs).
   The coding here is a little cluttered &mdash; the more relevant stuff happens after line 100.
