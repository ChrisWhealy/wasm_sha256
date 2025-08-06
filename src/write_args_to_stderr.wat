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
