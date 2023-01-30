import {
  wasmLogI32,
  wasmLogI32Pair,
  wasmShowMsgSchedule,
  wasmShowMsgBlock,
  wasmLogMemCopyArgs,
  wasmShowHashVals
} from "./utils/log_utils.js"
import { wasmLogCheckTestResult } from "./utils/test_utils.js"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Host environment objects shared with WASM module
export const hostEnv = (wasmMemory, msgBlockCount) => {
  let wasmMem32 = new Uint32Array(wasmMemory.buffer)

  return {
    "memory": {
      "pages": wasmMemory,
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
      "showHashVals": wasmShowHashVals(wasmMem32),
      "memCopyArgs": wasmLogMemCopyArgs,
    }
  }
}
