# WebAssembly Does Not Have A `raw` Data Type

This program needs to account for a fundamental collision of concepts:

1. The basic unit of data processed by the SHA256 algorithm is an uninterpreted sequence of 32 bits (I.E. raw binary)
1. WebAssembly only has numeric data types; therefore, like it or not, when you read data from memory, it will be interpreted as an integer whose byte order is determined by the endianness of the CPU on which you're running.
(Almost all processors nowadays are little-endian)

Therefore, when you call `i32.load`, WebAssembly helpfully follows this train of thought:

* Invoking `i32.load` means you'd like to work with the 32-bit ***integer*** found in memory at offset such-and-such
* I'm running on a little-endian processor, so the data in memory must have been stored in little-endian byte order (uh, no it hasn't!)
* So, before placing the value on the stack, the byte order must be reversed otherwise the integer value will be gibberish...

So if a memory location contains the raw binary value `0x0A0B0C0D`, calling `i32.load` will place `0x0D0C0B0A` onto the stack &mdash; which, in our particular situation, is not even slightly helpful...

![Uh...](./img/uh.gif)

This problem *might* be fixed when the [Garbage Collection proposal](https://github.com/WebAssembly/gc/blob/master/proposals/gc/MVP.md) is implemented, but it probably won't involve the arrival of a new datatype called `raw32`.

If such a data type were created, then a naïve solution might look like this:

```wast
(local $raw_bin raw32)
(local.set $raw_bin (raw32.load $some_offset))
```

This would be great, but I doubt it will be implemented that way...

So the problem is simply this: before the SHA256 algorithm can start, we must swap the endianness of the data so that when it is loaded onto the stack, the bytes appear in network order.


## Workaround

Fortunately in our case, there is a simple workaround.

The host environment reads the file and writes the data to shared memory ***in network order***.
The file is then processed in 64-byte chunks, where each chunk is copied to the start of a 256-byte area known as the message schedule.

All we need to do is swap the endianness of the data each time we copy a 64-byte chunk to the message schedule.
After that, we won't have to care about endianness because the data will always appear on the stack in the correct byte order.

Finally, after the SHA256 digest has been generated, we need to generate a character string that swaps the bytes back into network order.

All we need is a function to reverse the byte-order of an `i32`:

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
```
