# SHA256 Implementation in WebAssembly Text

As a learing exercise, this is an implementation of the SHA256 algorithm written in raw WebAssembly text.

The details of the algorithm have been obtained from [SHA256 Algorithm](https://sha256algorithm.com/)

This is a work in progress!

## Local Execution

Currently, this program calculates the SHA256 digest of 4, hardcoded test cases based on the test case number passed as a command line argument.

| Test Case | Test String
|---|---
| `0` | `"ABCD"`
| `1` | `"What's the digest Mr SHA?"`
| `2` | `"What's the digest Mr SHA for a message that spans two chunks?"`
| `3` | `"What's the digest Mr SHA for a message that spans three chunks? Need to add more text here to spill over into a third chunk"`

If the computation is correct, the digest will be printed to the console in the same format as the `sha256sum` command:

```bash
$ node main.js 0
e12e115acf4552b2568b55e93cbd39394c4ef81c82447fafc997882a02d23677  ./tests/testdata_abcd.txt
```

If the computation fails (as it has done for me, countless times), you will see something like

```bash
$ node main.js 2
SHA256 Error: ./tests/test_2_msg_blocks.txt
     Got 6c457d28c2bab9b82040d364c525fa07f7705fddcf8db119f5111443054e02bc
Expected 7949cc09b06ac4ba747423f50183840f6527be25c4aa36cc6314b200b4db3a55
```

## Development Challenges

Two challenges had to be overcome during develpment:

1. The fact that WebAssembly only has numeric data types, but we actually need a `raw` data type.
See the discussion on [endianness](endianness.md)
1. [Unit testing](./tests/README.md) in general, but specifically, performing unit tests on private WASM functions

### WARNING

If you open any of the text files in the `tests/` folder using an editor that has been configured to automatically add a blank line to the end of the file, then the SHA256 digest will change, and the tests will fail.
On Windows this will probably be a CRLF pair of characters (`0x0D0A`), and on macOS or a *NIX machine, just a line feed character (`0x0A`).

Either way, this will break the tests since they all assume that the text files ***DO NOT*** contain a terminating blank line!

## TODO

Implement the `memory.grow` command if passed a file larger than 64Kb (1 WebAssembly memory page)
