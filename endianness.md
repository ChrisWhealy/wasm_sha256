# WebAssembly Does Not Have A `raw` Data Type

The biggest challenge encountered whilst developing this program has been the fact that we need to account for a fundamental collision of concepts:

1. WebAssembly only has numeric data types.
1. The basic unit of processing in the SHA256 algorithm is a 32-bit word of raw binary data

This problem *might* be fixed when the [Garbage Collection proposal](https://github.com/WebAssembly/gc/blob/master/proposals/gc/MVP.md) is implemented, but it probably won't involve the arrival of a new datatype called `raw32` that would permit a nice-and-easy declaration such as `(local $raw_bin raw32)`.
Such a naïve solution would be great, but I doubt it will be implemented that way...

So the problem to be overcome is simply this:

The SHA256 algorithm needs to process the data in what's called *network order*; that is, the data in the file must be processed in exactly the order the bytes would be transmitted over a network (or occur on disk).
Ok, fair enough.

However, when you call the WebAssembly instruction `i32.load` to transfer a 32-bit word from memory onto the stack, WebAssembly helpfully follows this train of thought:

* `i32.load` means you'd like to work with the 32-bit ***integer*** found in memory at offset such-and-such
* I'm running on a little-endian processor (almost all processors nowadays are little-endian)
* This means that the data present in memory must occur in little-endian byte order
* Before placing the value on the stack, the byte order must be reversed otherwise we'll just be writing gibberish onto the stack.


So `i32.load` will take `0x0A0B0C0D` in memory and place it on the stack as `0x0D0C0B0A` &mdash; which, in this particular situation, is not even slightly helpful...

![Uh...](./img/uh.gif)

## Workaround

This means that in all situations where the data in memory needs to be treated as raw binary, we cannot directly use the `i32.load` instruction.
Instead, this instruction must be wrapped by a function that loads the data, but swaps the endianness before putting it onto the stack.

Similarly, if data needs to be written back to memory in raw (or big-endian) format, the `i32.store` instruct must also be wrapped.

```wast
;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;; Reverse the byte order of $val
(func $swap_endianness
      (param $val i32)
      (result i32)
  (i32.or
    (i32.or
      (i32.shl (i32.and (local.get $val) (i32.const 0x000000FF)) (i32.const 24))
      (i32.shl (i32.and (local.get $val) (i32.const 0x0000FF00)) (i32.const 8))
    )
    (i32.or
      (i32.shr_u (i32.and (local.get $val) (i32.const 0x00FF0000)) (i32.const 8))
      (i32.shr_u (i32.and (local.get $val) (i32.const 0xFF000000)) (i32.const 24))
    )
  )
)

;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;; Return the raw binary 32-bit word at byte offset $offset
(func $i32_load_raw
      (param $offset i32)
      (result i32)
  (call $swap_endianness (i32.load (local.get $offset)))
)

;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;; Store the i32 $val at byte offset $offset as raw binary
(func $i32_store_raw
      (param $offset i32)
      (param $val i32)
  (i32.store (local.get $offset) (call $swap_endianness (local.get $val)))
)
```
