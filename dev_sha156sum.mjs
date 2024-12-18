import { dumpWasmMemBuffer, logWasmMsg, logWasmMsgChar, logWasmMsgI32Hex, logWasmMsgU8Hex } from "./utils/log_utils.mjs"
import { writeStringToArrayBuffer } from "./utils/binary_utils.mjs"
import { handleCmdLine } from "./utils/command_line.mjs"
import { doTrackPerformance } from "./utils/performance.mjs"
import { readFileSync } from "fs"
import { WASI } from "wasi"

const wasmSha256Path = "./bin/sha256_opt.wasm"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//  Create list of directories that WASI will preopen
const wasi = new WASI({
  args: process.argv,
  version: "unstable",
  preopens: { ".": `${process.cwd()}` },    // Appears as fd 3 when using WASI path_open
})

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instantiate the sha256 WASM module
const startSha256Wasm =
  async pathToWasmFile => {
    let { instance } = await WebAssembly.instantiate(
      new Uint8Array(readFileSync(pathToWasmFile)),
      {
        wasi_snapshot_preview1: wasi.wasiImport,
        log: {
          "msg": logWasmMsg,
          "msg_hex_u8": logWasmMsgU8Hex,
          "msg_hex_i32": logWasmMsgI32Hex,
          "msg_char": logWasmMsgChar,
        },
      },
    )

    if (wasi.start(instance) > 0) {
      console.error("Pathname argument missing")
    }

    console.log(dumpWasmMemBuffer(instance.exports.memory)(0x500, 256))
    return { instance }
  }

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const main = async () => {
  // let filename = handleCmdLine(process.argv)

  perfTracker.addMark("Instantiate WASM module")
  let { instance } = await startSha256Wasm(wasmSha256Path)
  // let writeStringToWasmMem = writeStringToArrayBuffer(instance.exports.memory)
  // let filename_ptr = 64
  // writeStringToWasmMem(filename, filename_ptr)

  perfTracker.addMark('Calculate SHA256 hash')
  // instance.exports.sha256sum(3, filename_ptr, filename.length)
  instance.exports.sha256sum(3)

  perfTracker.listMarks()
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Switch on performance tracking?
const perfTracker = doTrackPerformance(process.argv.length > 3 && process.argv[3] === "true" || process.argv[3] === "yes")

await main()
