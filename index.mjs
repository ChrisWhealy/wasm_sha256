import { existsSync } from "fs"
import { startWasm } from "./utils/startWasm.mjs"
import { populateWasmMemory } from "./utils/populateWasmMemory.mjs"
import { doTrackPerformance } from "./utils/performance.mjs"
import { i32AsHexStr } from "./utils/binary_utils.mjs"

const wasmFilePath = "./bin/sha256.wasm"

const abortWithErrMsg = errMsg => {
  console.error(errMsg)
  process.exit(1)
}

const abortWithUsage = () => abortWithErrMsg("Usage: node main.js <filename>")
const abortWithFileNotFound = fileName => abortWithErrMsg(`Error: File "${fileName}" does not exist`)

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// I can haz command line arguments?
if (process.argv.length < 3) {
  abortWithUsage()
}

let fileName = process.argv[2]

// Handle file not found gracefully
if (!existsSync(fileName)) {
  abortWithFileNotFound(fileName)
}

// Switch on performance tracking?
let perfTracker = doTrackPerformance(process.argv.length > 3 && process.argv[3] === "true" || process.argv[3] === "yes")
perfTracker.addMark("Instantiate WASM module")

startWasm(wasmFilePath)
  .then(({ wasmExports, wasmMemory }) => {
    // Start with testCase switched off (-1)
    let msgBlockCount = populateWasmMemory(wasmMemory, fileName, -1, perfTracker)

    // Calculate hash then convert byte offset to i32 index
    perfTracker.addMark('Calculate SHA256 hash')
    let hashIdx32 = wasmExports.sha256_hash(msgBlockCount) >>> 2

    // Convert binary hash to character string
    perfTracker.addMark('Report result')
    let wasmMem32 = new Uint32Array(wasmMemory.buffer)
    let hash = wasmMem32.slice(hashIdx32, hashIdx32 + 8).reduce((acc, i32) => acc += i32AsHexStr(i32), "")

    console.log(`${hash}  ${fileName}`)

    // Output performance tracking marks
    perfTracker.listMarks()
  })
