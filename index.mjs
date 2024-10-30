import { existsSync, readFileSync } from "fs"
import { populateWasmMemory } from "./utils/populateWasmMemory.mjs"
import { doTrackPerformance } from "./utils/performance.mjs"
import { i32AsHexStr } from "./utils/binary_utils.mjs"
import { TEST_DATA } from "./tests/testData.mjs"

const wasmFilePath = "./bin/sha256.wasm"

const abortWithErrMsg = errMsg => {
  console.error(errMsg)
  process.exit(1)
}

const abortWithUsage = () => abortWithErrMsg("Usage: node index.mjs <filename>\n   or: node index.mjs -test <test_case_num>")
const abortWithFileNotFound = fileName => abortWithErrMsg(`Error: File "${fileName}" does not exist`)
const abortWithTestCaseMissing = () => abortWithErrMsg("Error: Test case number missing")
const abortWithTestCaseNotFound = testCase => abortWithErrMsg(`Error: Test case "${testCase}" does not exist\n       Enter a test case number between 0 and ${TEST_DATA.length - 1}`)

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instantiate the WASM module
export const startWasm =
  async pathToWasmFile => {
    let { instance } = await WebAssembly.instantiate(new Uint8Array(readFileSync(pathToWasmFile)))
    return { instance }
  }

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// I can haz command line arguments?
if (process.argv.length < 3) {
  abortWithUsage()
}

let fileName = process.argv[2]

// Check for running test cases
if (fileName === "-test") {
  // Check for valid test case number
  if (process.argv.length > 3) {
    if (isNaN(parseInt(process.argv[3])) || process.argv[3] >= TEST_DATA.length) {
      abortWithTestCaseNotFound(process.argv[3])
    }

    fileName = TEST_DATA[process.argv[3]].fileName
  } else {
    abortWithTestCaseMissing()
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Handle file not found gracefully
if (!existsSync(fileName)) {
  abortWithFileNotFound(fileName)
}

// Switch on performance tracking?
let perfTracker = doTrackPerformance(process.argv.length > 3 && process.argv[3] === "true" || process.argv[3] === "yes")
perfTracker.addMark("Instantiate WASM module")

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
startWasm(wasmFilePath)
  .then(({ instance }) => {
    let msgBlockCount = populateWasmMemory(instance.exports.memory, fileName, perfTracker)

    // Calculate hash then convert returned byte offset to i32 index
    perfTracker.addMark('Calculate SHA256 hash')
    let hashIdx32 = instance.exports.sha256_hash(msgBlockCount) >>> 2

    // Convert binary hash to character string
    perfTracker.addMark('Report result')
    let wasmMem32 = new Uint32Array(instance.exports.memory.buffer)
    let hash = wasmMem32.slice(hashIdx32, hashIdx32 + 8).reduce((acc, i32) => acc += i32AsHexStr(i32), "")

    console.log(`${hash}  ${fileName}`)

    // Output performance tracking marks
    perfTracker.listMarks()
  })
