import { doTrackPerformance } from "../utils/performance.mjs"
import { startWasm } from "../utils/startWasm.mjs"
import { i32AsHexStr } from "../utils/binary_utils.mjs"
import { populateWasmMemory } from "../utils/populateWasmMemory.mjs"
import { TEST_DATA } from "./testData.mjs"

const wasmFilePath = "./bin/sha256.wasm"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Tally ho!
let perfTracker = doTrackPerformance(process.argv.length > 3 && process.argv[3] === "true" || process.argv[3] === "yes")

for (let testCase = 0; testCase < TEST_DATA.length; testCase++) {
  console.log(`Running test case ${testCase} for file ${TEST_DATA[testCase].fileName}`)

  // Create a new WASM instance per test
  perfTracker.addMark("Instantiate WASM module")
  await startWasm(wasmFilePath)
    .then(({ wasmExports, wasmMemory }) => {
      perfTracker.addMark('Populate WASM memory')
      let msgBlockCount = populateWasmMemory(wasmMemory, "", testCase, perfTracker)

      // Calculate message digest then convert byte offset to i32 index
      perfTracker.addMark('Calculate SHA256 digest')
      let digestIdx32 = wasmExports.digest(msgBlockCount) >>> 2

      // Convert binary digest to character string
      perfTracker.addMark('Report result')
      let wasmMem32 = new Uint32Array(wasmMemory.buffer)
      let digest = ""

      for (let idx = 0; idx < 8; idx++) {
        digest += i32AsHexStr(wasmMem32[digestIdx32 + idx])
      }

      perfTracker.listMarks()

      if (digest === TEST_DATA[testCase].expectedDigest) {
        console.log("✅ Success\n")
      } else {
        console.error(`❌      Got ${digest}`)
        console.error(`❌ Expected ${TEST_DATA[testCase].expectedDigest}\n`)
      }

      perfTracker.reset()
    })
}
