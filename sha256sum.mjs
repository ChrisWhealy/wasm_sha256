import { readFileSync } from "fs"
import { WASI } from "wasi"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//  Define WASI environment
const wasi = new WASI({
  args: process.argv,
  version: "unstable",
  preopens: { ".": process.cwd() },    // Appears as fd 3 when using WASI path_open
})

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instantiate the WASM module
const startSha256Wasm =
  async pathToWasmFile => {
    let { instance } = await WebAssembly.instantiate(
      new Uint8Array(readFileSync(pathToWasmFile)),
      {
        wasi_snapshot_preview1: wasi.wasiImport,
      },
    )

    wasi.start(instance)
  }

await startSha256Wasm("./bin/sha256_opt.wasm")
