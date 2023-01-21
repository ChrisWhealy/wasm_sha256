// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Test functions that are normally internal to the WebAssembly module
// After successful testing, these functions' export statements have been commented out amd must be reinstated if these
// tests need to be rerun
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const fs = require("fs")
const {
  stringToAsciiArray,
} = require("./binary_utils.js")
const { hostEnv } = require("./hostEnvironment.js")

const wasmFilePath = "./bin/sha256.wasm"
const TEST_DATA_TXT = "./testdata_abcd.txt"

let wasmMemory = new WebAssembly.Memory({ initial: 2 })

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Async function to instantiate WASM module/instance
const startWasm =
  async pathToWasmFile => {
    let wasmMod = await WebAssembly.instantiate(
      new Uint8Array(fs.readFileSync(pathToWasmFile)),
      hostEnv(wasmMemory),
    )

    return wasmMod.instance.exports
  }

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Run all the tests
// After development and testing has been completed, the WASM test functions should be commented out in the .wat file
startWasm(wasmFilePath)
  .then(wasmExports => {
    let wasmMem8 = new Uint8Array(wasmMemory.buffer)

    const testData = fs.readFileSync(TEST_DATA_TXT, { encoding: "binary" })

    wasmMem8.set(stringToAsciiArray(testData))
    wasmMem8.set([0x80], testData.length)
    wasmMem8.set([testData.length * 8], 63)

    wasmExports.test_initialise_hash_values()
    wasmExports.test_initialise_working_variables()
    wasmExports.test_fetch_working_variable()
    wasmExports.test_set_working_variable()
    wasmExports.test_fetch_constant_value(0)
    wasmExports.test_fetch_constant_value(63)
    wasmExports.test_swap_endianness()
    wasmExports.test_sigma0()
    wasmExports.test_sigma1()
    wasmExports.test_choice()
    wasmExports.test_majority()
    wasmExports.test_big_sigma0()
    wasmExports.test_big_sigma1()
    wasmExports.test_gen_msg_sched(1)
    wasmExports.test_gen_msg_sched(48)
    wasmExports.test_update_working_vars(1)
  })
