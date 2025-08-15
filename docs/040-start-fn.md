# Step 4: The `_start` Function

For the sake of simplicity, we are going to put all the hash calculation functionality into the `_start` function.

This particular design decision has the consequence that after the WASM module has been instantiated, the host environment will immediately call the `_start` function and the hash of the supplied file will be calculated.
After that processing has completed, no further interaction with the WASM module is possible.

If you wish to calculate the hash of another file, you will need to create a new WASM instance.

It is certainly possible to adapt the functionality such that the same WASM instance can be used multiple times.
But given that we intend to run this WASM module from the command line, this is the simplest approach.

## General Steps Performed in the `_start` Function

In high level terms, the `_start` function performs the following processing:

1. Fetch the command line arguments
   1. Call `$wasi.args_sizes_get` to get the count (`argc`) and length (`argv_buf_len`) of the command line arguments.
   2. Check that the total length of these arguments will fit inside our allocated memory location (I.E. protect against a buffer overrun)
   3. Check that we have at least two arguments
   4. Call `$wasi.args_get` to get a table containing `argc` pointers to the individual command line argument values - where each value is null terminated (`0x00`).
   5. Extract the file name from the last argument
2. Attempt to open the file
3. Determine the file size
   1. If the file size >= 4Gb, then pack up and go home because WASM can't process a file that big
   2. Store the file size
4. Read the file in 2Mb chunks
   1. Store the number of bytes read and calculate the number of bytes remaining
   2. Is the 2Mb buffer full?
      - Yes
        * `$msg_blk_count = $READ_BUFFER_SIZE / 64`
        * Are there still bytes remaining to be read?
          - Yes - It's not EOF so continue
          - No - It is EOF and the file happens to be an exact integer multiple of the read buffer size
            * `$msg_blk_count += 1`
            * Initialise the extra message block then write the end-of-data marker (`0x80`) at the start and the file size in bits to the last 8 bytes as an unsigned, 64-bit integer in big endian byte order.
      - No - We've hit EOF and have a partially filled buffer
        * Calculate the number of message blocks
        * Write the end-of-data marker immediately after the last data byte
        * Initialise the zero or more remaining bytes in the last message block
        * Is there enough space in the last message block to hold the 8-byte file size?
          - Yes - Write file size to the last 8 bytes of the last message block
          - No
            * `$msg_blk_count += 1`
            * Initialised the extra message block
            * Write the file size to the last 8 bytes of the extra message block
   3. Perform (or continue performing) the SHA256 hash calculation on `$msg_blk_count` message blocks
   4. Keep reading the file until `&NREAD_PTR` says we've just read zero bytes
5. Close the file
6. Convert the 8 working hash values to ASCII, concatenate them together and write them to `stdout` as the final result
