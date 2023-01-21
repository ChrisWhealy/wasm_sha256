const fs = require("fs")
const {
  stringToAsciiArray,
  swapEndianness,
  i32AsFmtBinStr,
  i32AsBinStr,
  i32AsHexStr
} = require("./binary_utils.js")
const { hostEnv } = require("./hostEnvironment.js")

const wasmFilePath = "./bin/sha256.wasm"
const TEST_DATA_TXT = "./testdata_abcd.txt"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Async function to run WASM module/instance
const startWasm =
  async pathToWasmFile => {
    let wasmMod = await WebAssembly.instantiate(
      new Uint8Array(fs.readFileSync(pathToWasmFile)),
      hostEnv,
    )

    return wasmMod.instance.exports
  }

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Everything starts here
startWasm(wasmFilePath)
  .then(wasmExports => {
    let wasmMem8 = new Uint8Array(wasmExports.memory.buffer)
    let wasmMem32 = new Uint32Array(wasmExports.memory.buffer)

    const testData = fs.readFileSync(TEST_DATA_TXT, { encoding: "binary" })

    // SHA256 requires that the message buffer is never empty, so a binary 1 must always be appended as the last bit
    // after the data
    wasmMem8.set(stringToAsciiArray(testData))
    wasmMem8.set([0x80], testData.length)
    wasmMem8.set([testData.length * 8], 63)

    // // How many 512-bit chunks are needed?
    // // Also need to account for the bit length value stored as a 64-bit big int in big endian format
    // let msgBitLength = testData.length * 8
    // let chunks = Math.floor((msgBitLength + 64) / 512) + (msgBitLength + 64 % 512 > 0)

    // // Write the original bit length as a big int (in big endian format!) to the last 16 byes of the message block
    // wasmMem32.set([msgBitLength], (chunks * 64) - 16)

    let digest_idx = wasmExports.digest() / 4

    // Dump 32-bit view of memory
    // for (idx = 0; idx < 64; idx++) {
    //   console.log(`wasmMem32[${idx}] = ${i32AsBinStr(swapEndianness(wasmMem32[idx]))}`)
    // }

    let digest = ""

    for (let idx = 0; idx < 8; idx++) {
      digest += i32AsHexStr(swapEndianness(wasmMem32[digest_idx + idx]))
    }

    console.log(`Digest = ${digest}`)
  })
