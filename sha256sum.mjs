import { dumpWasmMemBuffer, logWasmMsg, logWasmMsgChar, logWasmMsgI32Hex, logWasmMsgU8Hex } from "./utils/log_utils.mjs"
import { readFileSync } from "fs"
import { WASI } from "wasi"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instantiate the WASM module
const startWasm =
  async pathToWasmMod => {
    //  Define WASI environment

    const wasi = new WASI({
      args: process.argv,
      version: "unstable",
      preopens: { ".": process.cwd() },    // This directory is available as fd 3 when calling WASI path_open
    })

    let { instance } = await WebAssembly.instantiate(
      new Uint8Array(readFileSync(pathToWasmMod)),
      {
        wasi_snapshot_preview1: wasi.wasiImport,
        log: {
          msg: logWasmMsg,
          msg_hex_u8: logWasmMsgU8Hex,
          msg_hex_i32: logWasmMsgI32Hex,
          msg_char: logWasmMsgChar,
        },
      },
    )

    wasi.start(instance)
  }

await startWasm("./bin/sha256_opt.wasm")
