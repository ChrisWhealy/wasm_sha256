/**
 * A unit test framework for testing WASM functions internal to the module.
 **/
import { readFileSync } from "fs"
import { hostEnv } from "../utils/hostEnvironment.mjs"

const wasmFilePath = "./bin/sha256_debug.wasm"
const TEST_DATA_TXT = "./tests/test_abcd.txt"

let wasmMemory = new WebAssembly.Memory({ initial: 2 })

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Async function to instantiate WASM module/instance
const startWasm =
  async pathToWasmFile => {
    let wasmMod = await WebAssembly.instantiate(
      new Uint8Array(readFileSync(pathToWasmFile)),
      hostEnv(wasmMemory),
    )

    return wasmMod.instance.exports
  }

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Run all unit tests against the test string "ABCD"
// After development and testing has been completed, the WASM test functions should be commented out in the .wat file
startWasm(wasmFilePath)
  .then(wasmExports => {
    let wasmMem8 = new Uint8Array(wasmMemory.buffer)

    const testData = readFileSync(TEST_DATA_TXT)

    wasmMem8.set(testData)
    wasmMem8.set([0x80], testData.length)
    wasmMem8.set([testData.length * 8], 63)

    wasmExports.should_initialise_hash_values()
    wasmExports.should_initialise_working_variables()
    wasmExports.should_fetch_working_variable()
    wasmExports.should_set_working_variable()
    wasmExports.should_fetch_constant_value(0)
    wasmExports.should_fetch_constant_value(63)
    wasmExports.should_swap_endianness()
    wasmExports.should_return_sigma0()
    wasmExports.should_return_sigma1()
    wasmExports.should_return_choice()
    wasmExports.should_return_majority()
    wasmExports.should_return_big_sigma0()
    wasmExports.should_return_big_sigma1()
    wasmExports.should_gen_msg_sched(1)
    wasmExports.should_gen_msg_sched(48)
    wasmExports.should_update_working_vars(1)
    wasmExports.should_update_working_vars(64)
    wasmExports.should_update_hash_vals()
  })
