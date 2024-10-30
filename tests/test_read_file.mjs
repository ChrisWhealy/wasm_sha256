import { dumpWasmMemBuffer } from "../utils/log_utils.mjs"
import { writeStringToArrayBuffer, i32FromArrayBuffer } from "../utils/binary_utils.mjs"
import { readFileSync } from "fs"
import { WASI } from "wasi"

const wasmFilePath = "./bin/read_file.wasm"

/** * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * Create list of directories that WASI will preopen
**/
const wasi = new WASI({
  preopens: {
    "./tests": `${process.cwd()}/tests`    // Appears as fd 3 when using WASI path_open
  },
})

/** * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * Debug messages output from WASM
**/
const stepNames = new Map()
stepNames.set(0, "WASM: path_open   ")
stepNames.set(1, "WASM: fd_seek     ")
stepNames.set(2, "WASM: memory.grow ")
stepNames.set(3, "WASM: fd_read     ")
stepNames.set(4, "WASM: msg_blocks  ")
stepNames.set(5, "WASM: fd_close    ")

const stepDetails = new Map()
stepDetails.set(0, "   return code  = ")
stepDetails.set(1, "            fd  = ")
stepDetails.set(2, "     file size  = ")
stepDetails.set(3, "   memory.size  = ")
stepDetails.set(4, "    bytes read  = ")
stepDetails.set(5, "iovec.buf_addr  = ")
stepDetails.set(6, " iovec.buf_len  = ")
stepDetails.set(7, "     memory OK  = ")
stepDetails.set(8, "end-of-data ptr = ")

const readMap = (mapNameTxt, mapName) => mapKey =>
  (val => val === undefined ? `Map ${mapNameTxt} has no key "${mapKey}" ` : val)(mapName["get"](mapKey))

const getStepName = readMap("stepNames", stepNames)
const getStepDetail = readMap("stepDetails", stepDetails)
const logWasmMsg = (step, msg_id, some_val) => console.log(`${getStepName(step)}${getStepDetail(msg_id)}${some_val}`)

export const startWasm =
  async pathToWasmFile => {
    let hostEnv = {
      wasi_snapshot_preview1: wasi.wasiImport,
      log: {
        "msg_id": logWasmMsg,
      },
    }

    let { instance } = await WebAssembly.instantiate(
      new Uint8Array(readFileSync(pathToWasmFile)),
      hostEnv
    )

    wasi.start(instance)

    return { instance }
  }

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
await startWasm(wasmFilePath)
  .then(({ instance }) => {
    // let filename = "test_empty.txt"
    let filename = "test_1_msg_block.txt"
    // let filename = "test_2_msg_blocks.txt"
    // let filename = "test_3_msg_blocks.txt"
    // let filename = "war_and_peace.txt"
    let writeStringToWasmMem = writeStringToArrayBuffer(instance.exports.memory)

    // Write file name to memory at offset 32
    let filename_ptr = 64
    writeStringToWasmMem(filename, filename_ptr)

    let step = -1
    let return_code = -1
    let iovec_ptr = -1
    let file_size = 0n;

    [step, return_code, iovec_ptr, file_size] = instance.exports.read_file(3, filename_ptr, filename.length)
    let i32FromUint8Array = i32FromArrayBuffer(instance.exports.memory)
    let wasmMemDump = dumpWasmMemBuffer(instance.exports.memory)

    console.log(wasmMemDump(0, 128));
    console.log(wasmMemDump(i32FromUint8Array(iovec_ptr), 128));
  })
