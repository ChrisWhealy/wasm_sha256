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
