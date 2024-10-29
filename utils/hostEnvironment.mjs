import {
  wasmLogI32,
  wasmLogI32Pair,
  wasmShowMsgSchedule,
  wasmShowMsgBlock,
  wasmLogMemCopyArgs,
  wasmShowHashVals
} from "./log_utils.mjs"
import { wasmLogCheckTestResult } from "../tests/test_utils.mjs"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Host environment objects shared with WASM module
export const hostEnv = {
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
