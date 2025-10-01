#!/usr/bin/env node

// Suppress ExperimentalWarning message when importing WASI
process.removeAllListeners('warning')
process.on(
  'warning',
  w => w.name === 'ExperimentalWarning' ? {} : console.warn(w.name, w.message)
)

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
      preopens: { ".": process.cwd() }, // Available as fd 3
    })
    const importObj = {
      wasi_snapshot_preview2: wasi.wasiImport,
    }

    let { instance } = await WebAssembly.instantiate(
      new Uint8Array(readFileSync(pathToWasmMod)),
      importObj,
    )

    wasi.start(instance)
  }

await startWasm("./bin/sha256.opt.wasm")
