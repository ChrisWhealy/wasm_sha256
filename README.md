# SHA256 Implementation in WebAssembly Text

As a learing exercise, this is an implementation of the SHA256 algorithm written in raw WebAssembly text.

The details of the algorithm have been obtained from [SHA256 Algorithm](https://sha256algorithm.com/)

This is a work in progress!

When run through `wasm-opt`, the binary is just under 1kB

```bash
$ wasm-opt ./bin/sha256.wasm --enable-bulk-memory -O4 -o ./bin/sha256_opt.wasm
$ ls -al ./bin
total 16
drwxr-xr-x   4 chris  staff   128 25 Jan 18:00 .
drwxr-xr-x  12 chris  staff   384 23 Jan 13:54 ..
-rw-r--r--   1 chris  staff  1086 25 Jan 17:44 sha256.wasm
-rw-r--r--   1 chris  staff  1008 25 Jan 18:00 sha256_opt.wasm
```

😎

## Local Execution

Currently, this program calculates the SHA256 digest of 4, hardcoded test cases based on the test case number passed as a command line argument.

| Test Case | Test String
|---|---
| `0` | `"ABCD"`
| `1` | `"What's the digest Mr SHA?"`
| `2` | `"What's the digest Mr SHA for a message that spans two chunks?"`
| `3` | `"What's the digest Mr SHA for a message that spans three chunks? Need to add more text here to spill over into a third chunk"`

If the computation is correct, the digest will be printed to the console:

```bash
$ node main.js 0
e12e115acf4552b2568b55e93cbd39394c4ef81c82447fafc997882a02d23677
```

If the computation fails (as it has done for me, countless times), you will see something like

```bash
$ node main.js 2
Error: Got 6c457d28c2bab9b82040d364c525fa07f7705fddcf8db119f5111443054e02bc
  Expected 7949cc09b06ac4ba747423f50183840f6527be25c4aa36cc6314b200b4db3a55
```

### IMPORTANT

If you open any of the text files in the `tests/` folder using an editor that automatically adds a carriage return (`0x0A`) to the end of the file, then the SHA256 digest will change, and the tests will fail.

All of these tests assume that the text file ***DOES NOT*** contain a terminating carriage return character!

## TODO

Implement the `memory.grow` command if passed a file larger than 64Kb (1 WebAssembly memory page)
