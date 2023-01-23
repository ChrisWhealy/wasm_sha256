const fs = require("fs")
const {
  stringToAsciiArray,
  u8AsHexStr
} = require("./utils/binary_utils.js")
const { hostEnv } = require("./hostEnvironment.js")

const wasmFilePath = "./bin/sha256.wasm"
const TEST_DATA_TXT = "./tests/testdata_abcd.txt"

let wasmMemory = new WebAssembly.Memory({ initial: 2 })

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Async function to run WASM module/instance
const startWasm =
  async pathToWasmFile => {
    let wasmMod = await WebAssembly.instantiate(
      new Uint8Array(fs.readFileSync(pathToWasmFile)),
      hostEnv(wasmMemory),
    )

    return wasmMod.instance.exports
  }

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Everything starts here
startWasm(wasmFilePath)
  .then(wasmExports => {
    let wasmMem8 = new Uint8Array(wasmMemory.buffer)

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

    // Returns the byte index to the 32 byte digest
    let digest_idx = wasmExports.digest()
    let digest = ""

    for (let idx = 0; idx < 32; idx++) {
      digest += u8AsHexStr(wasmMem8[digest_idx + idx])
    }

    console.log(digest)
  })
