import { readFileSync } from "fs"
import { hostEnv } from "./hostEnvironment.mjs"

const MIN_WASM_MEM_PAGES = 2

/** * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * Instantiate the WASM module with default memory allocation
**/
export const startWasm =
  async pathToWasmFile => {
    let wasmMemory = new WebAssembly.Memory({ initial: MIN_WASM_MEM_PAGES })

    let { instance } = await WebAssembly.instantiate(
      new Uint8Array(readFileSync(pathToWasmFile)),
      hostEnv(wasmMemory)
    )

    return {
      wasmExports: instance.exports,
      wasmMemory,
    }
  }
