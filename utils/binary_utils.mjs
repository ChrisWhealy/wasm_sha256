const binToHexStr = len => val => val.toString(16).padStart(len >>> 2, "0")

const swapEndianness = i32 =>
  (i32 & 0x000000FF) << 24 |
  (i32 & 0x0000FF00) << 8 |
  (i32 & 0x00FF0000) >>> 8 |
  (i32 & 0xFF000000) >>> 24

export const chunksOf = bytesPerChunk => size => Math.floor(size / bytesPerChunk) + (size % bytesPerChunk > 0)

const u8AsHexStr = binToHexStr(8)
const i32AsHexStr = binToHexStr(32)
const i32AsFmtHexStr = i32 => `0x${i32AsHexStr(i32)}`
const i64AsHexStr = binToHexStr(64)

const encoder = new TextEncoder()

const writeStringToArrayBuffer = memory =>
  (str, offset) =>
    encoder.encodeInto(
      str,
      new Uint8Array(
        memory.buffer,
        offset === undefined ? 0 : offset,
        str.length
      )
    )

const i32FromArrayBuffer = memory => {
  let wasmMem8 = new Uint8Array(memory.buffer)
  return offset => wasmMem8[offset] || wasmMem8[offset + 1] << 8 || wasmMem8[offset + 2] << 16 || wasmMem8[offset + 3] << 32
}

export {
  swapEndianness,
  u8AsHexStr,
  i32AsHexStr,
  i32AsFmtHexStr,
  i64AsHexStr,
  writeStringToArrayBuffer,
  i32FromArrayBuffer,
}
