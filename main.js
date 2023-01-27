const fs = require("fs")
const {
  stringToAsciiArray,
  asciiArrayToString,
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
    "fileName": "./tests/test_1_msg_block.txt",
    expectedDigest: "241c4a60aed45b6ba132db40a6beaa97238fbbc6937738b4c098d4cad3096916"
  },
  {
    "fileName": "./tests/test_2_msg_blocks.txt",
    expectedDigest: "7949cc09b06ac4ba747423f50183840f6527be25c4aa36cc6314b200b4db3a55"
  },
  {
    "fileName": "./tests/test_3_msg_blocks.txt",
    expectedDigest: "f68acfe2568e43127f6f1de7f74889560d21af0dc89f1a583956f569f6d43a38"
  },
]

/** - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 * Read target file
 * Write it to the expected location in shared memory
 * Create host environment object
 * Instantiate the WASM module passing in the host environment object
**/
const startWasm =
  async (pathToWasmFile, fileName, testCase) => {
    const MIN_WASM_MEM_PAGES = 2
    const MSG_BLOCK_OFFSET = 0x010000
    const END_OF_DATA = 0x80
    const fileData = (testCase === -1)
      ? fs.readFileSync(fileName, { encoding: "binary" })
      : fs.readFileSync(TEST_DATA[testCase].fileName, { encoding: "binary" })

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

const usage = () =>
  console.error(`Usage: node main.js <filename> or\n       node main.js -test <test case number in the range 0..${TEST_DATA.length - 1}>`)

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Tally ho!
let fileName = process.argv[2]
let testCase = -1

// Are we running a test case?
if (fileName === "-test") {
  let maybeTestCase = parseInt(process.argv[3])

  // Check that the fourth argument is not...
  if (process.argv.length < 4 ||       // Missing
    isNaN(maybeTestCase) ||            // Non-numeric
    maybeTestCase < 0 ||               // Too small
    maybeTestCase >= TEST_DATA.length  // Too big
  ) {
    usage()
    process.exit(1)
  } else {
    testCase = maybeTestCase
  }
} else {
  // Check file is smaller than 64Kb - 64 bytes
  // TODO Implemenyt memory.grow in WASM module to account for larger files
  if (fs.statSync(fileName).size > (64 * 1024) - 64) {
    console.error("Sorry, this program can only handle files smaller than 65472 bytes (64Kb - 64 bytes)")
    process.exit(1)
  }
}

startWasm(wasmFilePath, fileName, testCase)
  .then(({ wasmExports, wasmMem8, testCase }) => {
    // Calculate message digest
    let digest_idx = wasmExports.digest()
    let digest = asciiArrayToString(wasmMem8.slice(digest_idx, digest_idx + 64))

    if (testCase === -1) {
      console.log(`${digest}  ${fileName}`)
    } else {
      if (digest === TEST_DATA[testCase].expectedDigest) {
        console.log(`${digest}  ${TEST_DATA[testCase].fileName}`)
      } else {
        console.error(`SHA256 Error: ${TEST_DATA[testCase].fileName}`)
        console.error(`     Got ${digest}`)
        console.error(`Expected ${TEST_DATA[testCase].expectedDigest}`)
      }
    }
  })
