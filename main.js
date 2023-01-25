const fs = require("fs")
const {
  stringToAsciiArray,
  u8AsHexStr,
  memPages,
  msgBlocks,
} = require("./utils/binary_utils.js")
const { hostEnv } = require("./hostEnvironment.js")

const wasmFilePath = "./bin/sha256.wasm"

const TEST_DATA = [
  {
    "fileName": "./tests/testdata_abcd.txt",
    expectedDigest: "e12e115acf4552b2568b55e93cbd39394c4ef81c82447fafc997882a02d23677"
  },
  {
    "fileName": "./tests/testdata.txt",
    expectedDigest: "7949cc09b06ac4ba747423f50183840f6527be25c4aa36cc6314b200b4db3a55"
  }
]
const TEST_CASE = 1

/** - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 * Read target file
 * Write it to shared memory
 * Create host environment object
 * Instantiate the WASM module passing in host environment object
**/
const startWasm =
  async (pathToWasmFile, testCase) => {
    const MIN_WASM_MEM_PAGES = 2
    const MSG_BLOCK_OFFSET = 0x010000
    const END_OF_DATA = 0x80
    const fileData = fs.readFileSync(TEST_DATA[testCase].fileName, { encoding: "binary" })

    let maxMemoryPages = fileData.length > 0 ? memPages(fileData.length) + 1 : MIN_WASM_MEM_PAGES

    let wasmMemory = new WebAssembly.Memory({
      initial: MIN_WASM_MEM_PAGES,
      maximum: maxMemoryPages,
      shared: false
    })

    let wasmMem8 = new Uint8Array(wasmMemory.buffer)
    // let wasmMem32 = new Uint32Array(wasmMemory.buffer)
    let wasmMem64 = new DataView(wasmMemory.buffer)
    let msgBlockCount = msgBlocks(fileData.length + 8)

    // The SHA256 algorithm requires that the message block is never empty, so a binary 1 must always be appended as
    // the last bit after the file data.  In other words, if you attempt to calculate the SHA256 digest of nothing, the
    // algorithm will operate against a message block containing only 0x80
    wasmMem8.set(stringToAsciiArray(fileData), MSG_BLOCK_OFFSET)
    wasmMem8.set([END_OF_DATA], MSG_BLOCK_OFFSET + fileData.length)

    // Write the message bit length as a big-endian i64 to the end of the last message block
    wasmMem64.setBigUint64(
      MSG_BLOCK_OFFSET + (msgBlockCount * 64) - 8,  // Byte offset
      BigInt(fileData.length * 8),                  // i64 value
      false                                         // isLittleEndian?
    )

    // Show message block
    // let wordOffset32 = MSG_BLOCK_OFFSET >>> 2
    // for (let idx32 = 0; idx32 < msgBlockCount * 16; idx32++) {
    //   console.log(i32AsBinStr(swapEndianness(wasmMem32[wordOffset32 + idx32])))
    // }

    let wasmMod = await WebAssembly.instantiate(
      new Uint8Array(fs.readFileSync(pathToWasmFile)),
      hostEnv(wasmMemory, maxMemoryPages - MIN_WASM_MEM_PAGES, msgBlockCount),
    )

    return {
      wasmExports: wasmMod.instance.exports,
      wasmMem8,
      testCase,
    }
  }

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Everything starts here
startWasm(wasmFilePath, TEST_CASE)
  .then(({ wasmExports, wasmMem8, testCase }) => {
    // Calculate message digest
    let digest_idx = wasmExports.digest()
    let digest = ""

    for (let idx = 0; idx < 32; idx++) {
      digest += u8AsHexStr(wasmMem8[digest_idx + idx])
    }

    if (digest === TEST_DATA[testCase].expectedDigest) {
      console.log(digest)
    } else {
      console.error(`Error: Got ${digest}`)
      console.error(`  Expected ${TEST_DATA[testCase].expectedDigest}`)
    }
  })
