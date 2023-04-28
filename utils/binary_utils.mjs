const binToHexStr = len => val => val.toString(16).padStart(len >>> 2, "0")

export const swapEndianness = i32 =>
  (i32 & 0x000000FF) << 24 |
  (i32 & 0x0000FF00) << 8 |
  (i32 & 0x00FF0000) >>> 8 |
  (i32 & 0xFF000000) >>> 24

export const chunksOf = bytesPerChunk => size => Math.floor(size / bytesPerChunk) + (size % bytesPerChunk > 0)

export const u8AsHexStr = binToHexStr(8)
export const i32AsHexStr = binToHexStr(32)
export const i32AsFmtHexStr = i32 => `0x${i32AsHexStr(i32)}`
