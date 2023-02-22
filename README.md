# SHA256 Implementation in WebAssembly Text

I've recently had some time on my hands, so as a learing exercise, I decided to implement the SHA256 hash algorithm in raw WebAssembly text just to see how small I could make the compiled binary.

I'm pretty pleased with the result because after optimisation, the WASM binary is smaller than 1Kb!

😎

```bash
12:44 $ ls -al ./bin/sha256*
-rw-r--r--   1 chris  staff  1036 21 Feb 14:10 sha256.wasm
-rw-r--r--   1 chris  staff   934 21 Feb 14:10 sha256_opt.wasm
```

The optimized version was created using `wasm-opt`

```bash
wasm-opt ./bin/sha256.wasm --enable-simd --enable-bulk-memory -O4 -o ./bin/sha256_opt.wasm
```

By way of contrast, on my MacBook running macOS Ventura 13.1, the `sha256sum` binary delivered with the GNU `coreutils` package is 107Kb.

```bash
$ ls -al /usr/local/Cellar/coreutils/9.1/bin/gsha256sum
-rwxr-xr-x  1 chris  admin  109584 15 Apr  2022 /usr/local/Cellar/coreutils/9.1/bin/gsha256sum
```

117 times larger!

## Local Execution

This program calculates the SHA256 hash of the file supplied as a command line argument:

```bash
$ node index.js src/sha256.wat
a4404e9d405e97236d96e95235bc7cf1e38dd2077b0f90d0fad4cb598f5d9c8f  ./src/sha256.wat
```

Optionally, you can add a second argument of `true` or `yes` to switch on performance tracking.

```bash
$ node index.mjs ./src/sha256.wat true
78d1580e6621a1e4227fa8d91dc3687298520ccb0e5bb645fb3eeabfb155e083  ./src/sha256.wat
Start up                :  0.028 ms
Instantiate WASM module :  2.188 ms
Read target file        :  0.082 ms
Populate WASM memory    :  0.062 ms
Calculate SHA256 hash   :  0.279 ms
Report result           :  6.160 ms

Done in  8.799 ms
```

## Testing

Run the `npm` script `tests` followed by an optional argument `true` or `yes` for switching on performance tracking.

```bash
$ npm run tests

> wasm_sha256@1.1.0 tests
> node ./tests/index.mjs --

Running test case 0 for file ./tests/test_empty.txt        ✅ Success
Running test case 1 for file ./tests/test_abcd.txt         ✅ Success
Running test case 2 for file ./tests/test_1_msg_block.txt  ✅ Success
Running test case 3 for file ./tests/test_2_msg_blocks.txt ✅ Success
Running test case 4 for file ./tests/test_3_msg_blocks.txt ✅ Success
```

If a test fails (as it has done for me, countless times), you will see something like

```bash
Running test case 3 for file ./tests/test_3_msg_blocks.txt
❌        Got 9e228280d257ec3bb35482998bda0294187f4e122c74b4186e822f171abbfda9
❌   Expected f68acfe2568e43127f6f1de7f74889560d21af0dc89f1a583956f569f6d43a38
```

## Implementation Details

A detailed discussion of this implementation can be found in [this blog](https://awesome.red-badger.com/chriswhealy/sha256-webassembly)

The inner workings of the SHA256 have been obtained from the excellent [SHA256 Algorithm](https://sha256algorithm.com/) website.
Thanks [@manceraio](https://twitter.com/manceraio)!

## WARNING

The expected SHA256 hash value for each test case in the `tests/` directory has been calculated on the assumption that these files do not have a terminating blank line.
Therefore, if you open any of these files using an editor configured to automatically add a blank line to the end of the file, then the SHA256 hash will change, and the tests will fail!

On Windows this will probably be a CRLF pair of characters (`0x0D0A`), and on macOS or a *NIX machine, just a line feed character (`0x0A`).

Either way, this will break the tests since they all assume that the text files ***DO NOT*** contain a terminating blank line!
