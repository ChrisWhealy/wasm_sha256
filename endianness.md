# WebAssembly Does Not Have A `raw` Data Type

This program needs to account for a fundamental collision of concepts:

1. The basic unit of data processed by the SHA256 algorithm is an uninterpreted sequence of 32 bits (I.E. raw binary)
1. WebAssembly only has numeric data types; therefore, like it or not, when you read data from memory, it will be interpreted as an integer whose byte order is determined by the endianness of the CPU on which you're running.
(Almost all processors nowadays are little-endian)

For example, if you call `(i32.load (local.get $some_offset))`, WebAssembly uses the following train of thought:

* I need to take the 32-bit ***integer*** found in memory at `$some_offset` and place it on the stack
* Since this value is an integer and I'm running on a little-endian processor, it is safe to assume that the data in memory has been stored in little-endian byte order &mdash; well, not in this case...
* So, before placing the value on the stack, I must reverse the byte order otherwise there will be a nonsense value on the stack...

So the raw binary value `0x0A0B0C0D` in memory appears on the stack as `0x0D0C0B0A`...

![Uh...](./img/uh.gif)

Go directly to jail, do not pass Go, do not collect £200

> This problem *might* be fixed when the [Garbage Collection proposal](https://github.com/WebAssembly/gc/blob/master/proposals/gc/MVP.md) is implemented, but it probably won't involve the arrival of a new datatype called `raw32`.
>
> If such a data type were created, then a naïve solution might look like this:
>
> ```wast
> (local $raw_bin raw32)
> (local.set $raw_bin (raw32.load $some_offset))
> ```
>
> This would be great, but I doubt it will be implemented that way...

So the problem is simply this: before the SHA256 algorithm can start, we must swap the endianness of the data so that when it is loaded onto the stack, the bytes appear in the expected network order.


## Workaround

Fortunately in our case, there is a simple workaround.

The host environment reads the file and writes the data to shared memory ***in network order***.
The file is then processed in 64-byte chunks, where each chunk is copied to the start of a 256-byte area known as the message schedule.

All we need to do is swap the endianness of the data each time we copy a 64-byte chunk to the message schedule.
After that, we won't have to care about endianness because the data will always appear on the stack in the correct byte order.

Finally, after the SHA256 digest has been generated, we need to generate a character string that swaps the bytes back into network order.

We could reverse the byte-order of each `i32` individually, but fortunately, WebAssembly makes a large selection of SIMD (***S***ingle ***I***nstruction, ***M***ultiple ***D***ata) instructions available to us.
These instructions are designed to peform the same operation in parallel to multiple data values.
This not only simplifies the coding, but greatly improves performance.

In the loop where the raw binary file data is copied from the message block into the start of the message schedule, instead of using the `memory.copy` instruction, we can use the SIMD instruction `i8x16.swizzle`.

"Swizzle" is just a goofy name for rearranging a set of things into a new order.

```wast
  ;; Transfer the next 64 bytes from the message block to words 0-15 of the message schedule as raw binary
  ;; Can't use memory.copy here because the endianness needs to be swapped, so use v128.swizzle instead
  (loop $next_msg_sched_vec
    (v128.store
      (i32.add (global.get $MSG_SCHED_OFFSET) (local.get $offset))
      (i8x16.swizzle
        (v128.load (i32.add (local.get $blk_offset) (local.get $offset)))  ;; The data being reordered
        (v128.const i8x16 3 2 1 0 7 6 5 4 11 10 9 8 15 14 13 12)           ;; Rearrange bytes into this order
      )
    )

    (local.set $offset (i32.add (local.get $offset) (i32.const 16)))
    (br_if $next_msg_sched_vec (i32.lt_u (local.get $offset) (i32.const 64)))
  )
```

Notice that we are now using instructions belonging to a different dataype: `v128`, not `i32`.

Since we know that 4, `i32` values occupy a contiguous block of memory, we can pick them up as if they were a single block of 128 bits (a `v128` vector).
Then, in order to swap the endiannes, we use the instruction `i8x16.swizzle` which looks at this value as if it were a vector of 16, 8-bit bytes, then rearranges (or swizzles) the byte order according to the supplied list of indicies.

![Swap Endianness using i8x16.shuffle](./img/i8x16.swizzle.png)
