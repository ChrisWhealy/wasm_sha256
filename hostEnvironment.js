const {
  wasmLogI32,
  wasmLogI32Pair,
} = require("./utils/log_utils.js")

const {
  wasmLogCheckTestResult,
} = require("./utils/test_utils.js")

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Host environment objects shared with WASM module
const hostEnv = wasmMemory => {
  let wasmMem32 = new Uint32Array(wasmMemory.buffer)

  return {
    "memory": {
      "pages": wasmMemory,
    },
    "log": {
      "i32": wasmLogI32,
      "i32Pair": wasmLogI32Pair,
      "checkTestResult": wasmLogCheckTestResult(wasmMem32),
    }
  }
}

module.exports = {
  hostEnv
}
