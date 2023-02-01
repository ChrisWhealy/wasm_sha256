# SHA256 Implementation in WebAssembly Text

I've recently had some time on my hands, so as a learing exercise, I decided to implement the SHA256 algorithm in raw WebAssembly text just to see how small I could make the compiled binary.

I'm pretty pleased with the result because after optimisation, the WASM binary is smaller than 1Kb!

😎

```bash
16:00 $ ls -al ./bin/sha256*
-rw-r--r--   1 chris  staff  1085  1 Feb 16:39 sha256.wasm
-rw-r--r--   1 chris  staff   977  1 Feb 16:44 sha256_opt.wasm
```

The optimized version was created using `wasm-opt`

```bash
wasm-opt ./bin/sha256.wasm --enable-simd --enable-bulk-memory -O4 -o ./bin/sha256_opt.wasm
```

By way of contrast, on my MacBook running macOS Ventura 13.1, the `gsha256sum` binary delivered with the GNU `coreutils` package is 107Kb.

```bash
$ ls -al /usr/local/Cellar/coreutils/9.1/bin/gsha256sum
-rwxr-xr-x  1 chris  admin  109584 15 Apr  2022 /usr/local/Cellar/coreutils/9.1/bin/gsha256sum
```

112 times larger!

## Local Execution

This program calculates the SHA256 digest of the file supplied as a command line argument:

```bash
$ node main.js src/sha256.wat
c5b4ed7bc6e397aa107850ede24dd1c7bf680bd7bb0800cc67260fa6f9c97560  ./src/sha256.wat
```

## Test Cases

The program can also be run against 5, hardcoded test cases based on the test case number passed as a command line argument.

| Test Case | Test String
|---|---
| `0` | `<empty file>`
| `1` | `"ABCD"`
| `2` | `"What's the digest Mr SHA?"`
| `3` | `"What's the digest Mr SHA for a message that spans two chunks?"`
| `4` | `"What's the digest Mr SHA for a message that spans three chunks? Need to add more text here to spill over into a third chunk"`

If the computation is correct, the digest will be printed to the console in the same format as the `sha256sum` command:

```bash
$ sha256sum ./tests/test_abcd.txt
e12e115acf4552b2568b55e93cbd39394c4ef81c82447fafc997882a02d23677  ./tests/test_abcd.txt
$ node main.js -test 1
e12e115acf4552b2568b55e93cbd39394c4ef81c82447fafc997882a02d23677  ./tests/test_abcd.txt
```

If the computation fails (as it has done for me, countless times), you will see something like

```bash
$ node main.js -test 3
SHA256 Error: ./tests/test_2_msg_blocks.txt
     Got 6c457d28c2bab9b82040d364c525fa07f7705fddcf8db119f5111443054e02bc
Expected 7949cc09b06ac4ba747423f50183840f6527be25c4aa36cc6314b200b4db3a55
```

## Implementation Details

The implementation details have been obtained from the excellent [SHA256 Algorithm](https://sha256algorithm.com/) website.
Thanks [@manceraio](https://twitter.com/manceraio)!

## Development Challenges

Two challenges had to be overcome during develpment:

1. The fact that WebAssembly only has numeric data types, but we actually need a `raw` data type.<br>
See the discussion on [endianness](endianness.md)
1. [Unit testing](./tests/README.md) in general, but specifically, performing unit tests on private WASM functions

## Architecture

The architecture of this program is laid out in this [block diagram](./img/sha256.pdf).

This diagram borrows from Jackson Structured Programming where the pale yellow boxes represent a sequence and the blue boxes represent an interation.
The instructions in the child boxes underneath each blue box will be repeated multiple times.

## WARNING

The expected SHA256 digest value for each test case in the `tests/` directory has been calculated on the assumption that these files do not have a terminating blank line.
Therefore, if any of these files are opened using an editor configured to automatically add a blank line to the end of the file, then the SHA256 digest will change, and the tests will fail.
On Windows this will probably be a CRLF pair of characters (`0x0D0A`), and on macOS or a *NIX machine, just a line feed character (`0x0A`).

Either way, this will break the tests since they all assume that the text files ***DO NOT*** contain a terminating blank line!
