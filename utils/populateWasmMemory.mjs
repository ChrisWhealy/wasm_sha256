import { readFileSync } from "fs"
import { TEST_DATA } from "../tests/testData.mjs"
import {
  memPages,
  msgBlocks,
} from "./binary_utils.mjs"

const WASM_MEM_PAGE_SIZE = 64 * 1024
const MSG_BLOCK_OFFSET = 0x010000
const END_OF_DATA = 0x80

/** * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * Read target file supplied either by the user or by the testCase number
 * Grow WASM memory if necessary
 * Write file contents to the expected location in WASM memory
**/
export const populateWasmMemory =
  (wasmMemory, fileName, testCase, perfTracker) => {
    perfTracker.addMark('Read target file')
    const fileData = readFileSync(testCase === -1 ? fileName : TEST_DATA[testCase].fileName)

    // If the file length plus the extra end-of-data marker (1 byte) plus the 64-bit, unsigned integer holding the
    // file's bit length (8 bytes) won't fit into one memory page, then grow WASM memory
    if (fileData.length + 9 > WASM_MEM_PAGE_SIZE) {
      let memPageSize = memPages(fileData.length + 9)
      wasmMemory.grow(memPageSize)
    }

    perfTracker.addMark('Populate WASM memory')
    let wasmMem8 = new Uint8Array(wasmMemory.buffer)
    let wasmMem64 = new DataView(wasmMemory.buffer)

    // Write file data to memory plus end-of-data marker
    wasmMem8.set(fileData, MSG_BLOCK_OFFSET)
    wasmMem8.set([END_OF_DATA], MSG_BLOCK_OFFSET + fileData.length)

    // Write the message bit length as an unsigned, big-endian i64 as the last 64 bytes of the last message block
    let msgBlockCount = msgBlocks(fileData.length + 9)
    wasmMem64.setBigUint64(
      MSG_BLOCK_OFFSET + (msgBlockCount * 64) - 8,  // Byte offset
      BigInt(fileData.length * 8),                  // i64 value
      false                                         // isLittleEndian?
    )

    return msgBlockCount
  }
