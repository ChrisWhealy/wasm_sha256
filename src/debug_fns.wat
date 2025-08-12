    ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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
            (call $byte_to_ascii_pair (local.get $this_byte) (local.get $buf_ptr))
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
              ;; If the current character is not printable, substitute a dot
              (select (local.get $this_byte) (i32.const 0x2E)
                (i32.ge_u (local.get $this_byte) (i32.const 0x20))
              )
            )

            (local.set $buf_ptr    (i32.add (local.get $buf_ptr)    (i32.const 1)))
            (local.set $buf_len    (i32.add (local.get $buf_len)    (i32.const 1)))
            (local.set $byte_count (i32.add (local.get $byte_count) (i32.const 1)))
            (local.set $blk_ptr    (i32.add (local.get $blk_ptr)    (i32.const 1)))

            (br_if $ascii_chars (i32.lt_u (local.get $byte_count) (i32.const 16)))
          )

          ;; Write "|\n"
          (i32.store16 (local.get $buf_ptr) (i32.const 0x0A7C)) ;; space + LF (little endian)
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
      (call $writeln (i32.const 2) (local.get $arg_ptr) (local.get $arg_len))

      ;; Bump argc_count then repeat as long as argc_count <= argc
      (local.set $argc_count (i32.add (local.get $argc_count) (i32.const 1)))
      (br_if $arg_loop (i32.le_u (local.get $argc_count) (local.get $argc)))
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

        (call $write
          (local.get $fd)
          (global.get $STR_WRITE_BUF_PTR)
          (i32.sub (local.get $buf_ptr) (global.get $STR_WRITE_BUF_PTR)) ;; length = end address - start address
        )
      )
    )
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
      (call $writeln (i32.const 2) (local.get $arg_ptr) (local.get $arg_len))

      ;; Bump argc_count then repeat as long as argc_count <= argc
      (local.set $argc_count (i32.add (local.get $argc_count) (i32.const 1)))
      (br_if $arg_loop (i32.le_u (local.get $argc_count) (local.get $argc)))
    )
  )
