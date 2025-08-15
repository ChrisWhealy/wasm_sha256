# Step 10: Write the Hash Value to `stdout`

Once we've processed all the message blocks, final final steps are:
* Convert the 8 internal hash values to ASCII
* Concatenate them together
* Write the output to `stdout`

This is done by the following code:

```wat
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
```
