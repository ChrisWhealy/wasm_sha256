const binToHexStr = len => val => val.toString(16).padStart(len >>> 2, "0")

const swapEndianness = i32 =>
  (i32 & 0x000000FF) << 24 |
  (i32 & 0x0000FF00) << 8 |
  (i32 & 0x00FF0000) >>> 8 |
  (i32 & 0xFF000000) >>> 24

export const chunksOf = bytesPerChunk => size => Math.floor(size / bytesPerChunk) + (size % bytesPerChunk > 0)

const u8AsChar = u8 => String.fromCharCode(u8)
const u8AsHexStr = binToHexStr(8)
const i32AsHexStr = binToHexStr(32)
const i32AsFmtHexStr = i32 => `0x${i32AsHexStr(i32)}`
const i64AsHexStr = binToHexStr(64)

const encoder = new TextEncoder()

const writeStringToArrayBuffer = memory =>
  (str, byteOffset) =>
    encoder.encodeInto(
      str,
      new Uint8Array(
        memory.buffer,
        byteOffset === undefined ? 0 : byteOffset,
        str.length
      )
    )

const i32FromArrayBuffer = memory => {
  let wasmMem8 = new Uint8Array(memory.buffer)
  return byteOffset => swapEndianness(wasmMem8[byteOffset])
}

export {
  swapEndianness,
  u8AsChar,
  u8AsHexStr,
  i32AsHexStr,
  i32AsFmtHexStr,
  i64AsHexStr,
  writeStringToArrayBuffer,
  i32FromArrayBuffer,
}
