# SHA256 Implementation in WebAssembly Text

As a learing excerise, this is an implementation of the SHA256 algorithm written in raw WebAssembly text.

The details of the algorithm have been obtained from [SHA256 Algorithm](https://sha256algorithm.com/)

## Local Execution

Currently, the SHA256 digest of the test string `"ABCD"` is calculated

```bash
$ node main.js
e12e115acf4552b2568b55e93cbd39394c4ef81c82447fafc997882a02d23677
```

## TODO

Currently, the program is hardcoded to calculate the SHA256 digest of the test string `"ABCD"` and handle files up to 512 bytes in size.

The current digest calculation needs to be wrapped in a loop that repeatedly performs the above step for all 512 byte chunks of the file.
