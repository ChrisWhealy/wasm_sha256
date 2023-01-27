# SHA256 Implementation in WebAssembly Text

I've recently had some time on my hands, so as a learing exercise, I decided to implement the SHA256 algorithm in raw WebAssembly text just to see how small I could make the compiled binary.
I'm pretty pleased with the result because the WASM binary is just over 1Kb in size!

```bash
$ ls -al ./bin/sha256.wasm
-rw-r--r--  1 chris  staff  1259 27 Jan 17:54 ./bin/sha256.wasm
```

Unfortunately, even after running this program through `wasm-opt` set to the highest optimization level, it can only shave 100 or so bytes off the size.
So I think it will be pretty tricky to squeeze the binary into less than 1Kb... 😖

By way of contrast, on my MacBook running macOS Ventura 13.1, the `gsha256sum` binary delivered with the GNU `coreutils` package is 107Kb.

```bash
$ ls -al /usr/local/Cellar/coreutils/9.1/bin/gsha256sum
-rwxr-xr-x  1 chris  admin  109584 15 Apr  2022 /usr/local/Cellar/coreutils/9.1/bin/gsha256sum
```

My implementation is 87 times smaller!  😎

## Implementation Details

The implementation details have been obtained from the excellent [SHA256 Algorithm](https://sha256algorithm.com/) website.
Thanks [@manceraio](https://twitter.com/manceraio)!

## Local Execution

Currently, this program calculates the SHA256 digest of any file less than 65472 bytes in size (64Kb - 64 bytes).

```bash
$ node main.js src/sha256.wat
c5b4ed7bc6e397aa107850ede24dd1c7bf680bd7bb0800cc67260fa6f9c97560  ./src/sha256.wat
```

If you try to process a file that is too large, you'll see an error message

```bash
$ node main.js ./img/uh.gif
Sorry, this program can only handle files smaller than 65472 bytes (64Kb - 64 bytes)
```

## Test Cases

The program can also be run against 4, hardcoded test cases based on the test case number passed as a command line argument.

| Test Case | Test String
|---|---
| `0` | `"ABCD"`
| `1` | `"What's the digest Mr SHA?"`
| `2` | `"What's the digest Mr SHA for a message that spans two chunks?"`
| `3` | `"What's the digest Mr SHA for a message that spans three chunks? Need to add more text here to spill over into a third chunk"`

If the computation is correct, the digest will be printed to the console in the same format as the `sha256sum` command:

```bash
$ sha256sum ./tests/testdata_abcd.txt
e12e115acf4552b2568b55e93cbd39394c4ef81c82447fafc997882a02d23677  ./tests/testdata_abcd.txt
$ node main.js -test 0
e12e115acf4552b2568b55e93cbd39394c4ef81c82447fafc997882a02d23677  ./tests/testdata_abcd.txt
```

If the computation fails (as it has done for me, countless times), you will see something like

```bash
$ node main.js -test 2
SHA256 Error: ./tests/test_2_msg_blocks.txt
     Got 6c457d28c2bab9b82040d364c525fa07f7705fddcf8db119f5111443054e02bc
Expected 7949cc09b06ac4ba747423f50183840f6527be25c4aa36cc6314b200b4db3a55
```

## Development Challenges

Two challenges had to be overcome during develpment:

1. The fact that WebAssembly only has numeric data types, but we actually need a `raw` data type.
See the discussion on [endianness](endianness.md)
1. [Unit testing](./tests/README.md) in general, but specifically, performing unit tests on private WASM functions

## Architecture

The architecture of this program is laid out in this [block diagram](./img/sha256.pdf).

This diagram borrows from Jackson Structured Programming where the pale yellow boxes represent a sequence and the blue boxes represent an interation.
The instructions in the child boxes underneath each blue box will be repeated multiple times.

## WARNING

If you open any of the text files in the `tests/` folder using an editor that has been configured to automatically add a blank line to the end of the file, then the SHA256 digest will change, and the tests will fail.
On Windows this will probably be a CRLF pair of characters (`0x0D0A`), and on macOS or a *NIX machine, just a line feed character (`0x0A`).

Either way, this will break the tests since they all assume that the text files ***DO NOT*** contain a terminating blank line!

## TODO

Implement the `memory.grow` command in the WASM module to allow files larger than 64Kb (1 WebAssembly memory page) to be processed.
