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

        (call $write_to_fd (local.get $fd) (global.get $STR_WRITE_BUF_PTR) (local.get $buf_len))
      )
    )
  )
