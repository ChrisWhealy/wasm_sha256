const {
  wasmLogI32,
  wasmLogI32Pair,
  wasmShowMsgSchedule,
  wasmShowMsgBlock,
  wasmLogMemCopyArgs,
} = require("./utils/log_utils.js")

const {
  wasmLogCheckTestResult,
} = require("./utils/test_utils.js")

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Host environment objects shared with WASM module
const hostEnv = (wasmMemory, growBy, msgBlockCount) => {
  let wasmMem32 = new Uint32Array(wasmMemory.buffer)

  return {
    "memory": {
      "pages": wasmMemory,
      "growBy": growBy,
    },
    "message": {
      "blockCount": msgBlockCount,
    },
    "log": {
      "i32": wasmLogI32,
      "i32Pair": wasmLogI32Pair,
      "checkTestResult": wasmLogCheckTestResult(wasmMem32),
      "showMsgSchedule": wasmShowMsgSchedule(wasmMem32),
      "showMsgBlock": wasmShowMsgBlock(wasmMem32),
      "memCopyArgs": wasmLogMemCopyArgs,
    }
  }
}

module.exports = {
  hostEnv
}
