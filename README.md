# SHA256 Implementation in WebAssembly Text

As a learing excerise, this is an implementation of the SHA256 algorithm written in raw WebAssembly text.

The details of the algorithm have been obtained from [SHA256 Algorithm](https://sha256algorithm.com/)

## Local Execution

Currently, the SHA256 digest of 3, hardcoded test cases can calculated based on the test case number passed as a command line argument.

| Test Case | Test String
|---|---
| `0` | `"ABCD"`
| `1` | `"What's the digest Mr SHA?"`
| `2` | `"What's the digest Mr SHA for a message that spans two chunks?"`

```bash
$ node main.js 0
e12e115acf4552b2568b55e93cbd39394c4ef81c82447fafc997882a02d23677
```

## TODO

Currently, the program is hardcoded to calculate the SHA256 digest of the test string `"ABCD"` and handle files up to 512 bytes in size.

The program needs to read a file, divide it into 512-byte chunks, then perform the above digest calculation for each chunk.
