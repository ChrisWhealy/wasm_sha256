import { logWasmMsg } from "./utils/log_utils.mjs"
import { writeStringToArrayBuffer, i32AsHexStr } from "./utils/binary_utils.mjs"
import { handleCmdLine } from "./utils/command_line.mjs"
import { doTrackPerformance } from "./utils/performance.mjs"
import { readFileSync } from "fs"
import { WASI } from "wasi"

const wasmSha256Path = "./bin/sha256_opt.wasm"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//  Create list of directories that WASI will preopen
const wasi = new WASI({
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
        log: { "msg": logWasmMsg },
      },
    )

    wasi.start(instance)
    return { instance }
  }

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const main = async filename => {
  perfTracker.addMark("Instantiate WASM module")
  let { instance } = await startSha256Wasm(wasmSha256Path)
  let writeStringToWasmMem = writeStringToArrayBuffer(instance.exports.memory)
  let filename_ptr = 64
  writeStringToWasmMem(filename, filename_ptr)

  perfTracker.addMark('Calculate SHA256 hash')
  let sha256Ptr = instance.exports.sha256sum(3, filename_ptr, filename.length)

  perfTracker.addMark('Report result')
  let wasmMem32 = new Uint32Array(instance.exports.memory.buffer)
  let hashIdx32 = sha256Ptr >>> 2
  let hash = wasmMem32.slice(hashIdx32, hashIdx32 + 8).reduce((acc, i32) => acc += i32AsHexStr(i32), "")

  console.log(`${hash}  ${filename}`)
  perfTracker.listMarks()
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Switch on performance tracking?
const perfTracker = doTrackPerformance(process.argv.length > 3 && process.argv[3] === "true" || process.argv[3] === "yes")

await main(handleCmdLine(process.argv))
