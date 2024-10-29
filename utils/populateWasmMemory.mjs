import { readFileSync } from "fs"
import { chunksOf } from "./binary_utils.mjs"

const MSG_BLOCK_OFFSET = 0x010000
const END_OF_DATA = 0x80
const WASM_MEM_PAGE_SIZE = 64 * 1024

const memPages = chunksOf(WASM_MEM_PAGE_SIZE)
const msgBlocks = chunksOf(64)

/** * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * Read target file supplied either by the user or by the testCase number
 * Grow WASM memory if necessary
 * Write file contents to the expected location in WASM memory
**/
export const populateWasmMemory =
  (wasmMemory, fileName, perfTracker) => {
    perfTracker.addMark('Read target file')
    const fileData = readFileSync(fileName)

    // Data length = data.length + 1 (end-of-data marker) + 8 (data length as an 64-bit, unsigned integer)
    // Memory available for file data = Current memory allocation - 1 page allocated for SHA256 message digest etc
    let neededBytes = fileData.length + 9
    let availableBytes = wasmMemory.buffer.byteLength - WASM_MEM_PAGE_SIZE

    if (neededBytes > availableBytes) {
      wasmMemory.grow(memPages(neededBytes - availableBytes))
    }

    perfTracker.addMark('Populate WASM memory')
    let wasmMem8 = new Uint8Array(wasmMemory.buffer)
    let wasmMem64 = new DataView(wasmMemory.buffer)

    // Write file data to memory plus end-of-data marker
    wasmMem8.set(fileData, MSG_BLOCK_OFFSET)
    wasmMem8.set([END_OF_DATA], MSG_BLOCK_OFFSET + fileData.length)

    // Write the message bit length as an unsigned, big-endian i64 as the last 64 bytes of the last message block
    let msgBlockCount = msgBlocks(neededBytes)
    wasmMem64.setBigUint64(
      MSG_BLOCK_OFFSET + (msgBlockCount * 64) - 8,  // Byte offset
      BigInt(fileData.length * 8),                  // i64 value
      false                                         // isLittleEndian?
    )

    return msgBlockCount
  }
