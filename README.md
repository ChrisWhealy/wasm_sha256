# SHA256 Implementation in WebAssembly Text

I've recently had some time on my hands, so as a learing exercise, I decided to implement the SHA256 algorithm in raw WebAssembly text just to see how small I could make the compiled binary.

I'm pretty pleased with the result because after optimisation, the WASM binary is smaller than 1Kb!

😎

```bash
12:44 $ ls -al ./bin/sha256*
-rw-r--r--   1 chris  staff  1059 13 Feb 11:28 sha256.wasm
-rw-r--r--   1 chris  staff   951 13 Feb 12:44 sha256_opt.wasm
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

115 times larger!

## Local Execution

This program calculates the SHA256 digest of the file supplied as a command line argument:

```bash
$ node index.js src/sha256.wat
a4404e9d405e97236d96e95235bc7cf1e38dd2077b0f90d0fad4cb598f5d9c8f  ./src/sha256.wat
```

You can optionally add a second argument of `"true"` or `"yes"` for switching on performance tracking.

```bash
$ node index.mjs ./src/sha256.wat yes
a4404e9d405e97236d96e95235bc7cf1e38dd2077b0f90d0fad4cb598f5d9c8f  ./src/sha256.wat
Start up                :  0.045 ms
Instantiate WASM module :  2.117 ms
Populate WASM memory    :  0.068 ms
Read target file        :  0.285 ms
Populate WASM memory    :  0.968 ms
Calculate SHA256 digest :  0.287 ms
Report result           :  6.825 ms
Done
```

## Testing

Run the `npm` script `tests` followed by an optional argument `"true"` or `"yes"` for switching on performance tracking.

```bash
$ npm run tests

> wasm_sha256@1.1.0 tests
> node ./tests/index.mjs --

Running test case 0 for file ./tests/test_empty.txt
✅ Success

Running test case 1 for file ./tests/test_abcd.txt
✅ Success

Running test case 2 for file ./tests/test_1_msg_block.txt
✅ Success

Running test case 3 for file ./tests/test_2_msg_blocks.txt
✅ Success

Running test case 4 for file ./tests/test_3_msg_blocks.txt
✅ Success
```

If a test fails (as it has done for me, countless times), you will see something like

```bash
Running test case 3 for file ./tests/test_3_msg_blocks.txt
❌ Error: Got 9e228280d257ec3bb35482998bda0294187f4e122c74b4186e822f171abbfda9
❌   Expected f68acfe2568e43127f6f1de7f74889560d21af0dc89f1a583956f569f6d43a38
```

## Implementation Details

The implementation details have been obtained from the excellent [SHA256 Algorithm](https://sha256algorithm.com/) website.
Thanks [@manceraio](https://twitter.com/manceraio)!

## Development Challenges

Two challenges had to be overcome during develpment:

1. This program needs to handle data in network byte order, but WebAssembly only has numeric data types that automatically rearrange a value's byte order according to the CPU's endianness.
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
