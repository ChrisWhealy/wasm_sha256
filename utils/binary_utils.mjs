// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Display a raw binary value of bit length `len` as a binary string
// Additional ASCII text formatting can also be displayed
const binToStr =
  (len, showAscii) =>
    val => {
      let result = val.toString(2).padStart(len >>> 3, "0")

      if (!!showAscii) {
        result += " "

        // Generate ASCII string substituting any control characters for spaces
        // Here we assume the data will be supplied in network (or big-endian) byte order
        // If the data is in little-endian byte order, the string will be printed backwards!
        for (let shift = len / 8; shift > 0; shift--) {
          let c = (val >>> (shift - 1) * 8) & 0x00FF
          result += String.fromCharCode(c < 32 ? 32 : c)
        }
      }

      return result
    }

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Display a raw binary value of bit length `len` as a hexadecimal string
const binToHexStr =
  (len, addPrefix) =>
    !!addPrefix
      ? (val => `0x${val.toString(16).padStart(len >>> 2, "0")}`)
      : (val => val.toString(16).padStart(len >>> 2, "0"))

export const swapEndianness = i32 =>
  (i32 & 0x000000FF) << 24 |
  (i32 & 0x0000FF00) << 8 |
  (i32 & 0x00FF0000) >>> 8 |
  (i32 & 0xFF000000) >>> 24

export const chunksOf = bytesPerChunk => size => Math.floor(size / bytesPerChunk) + (size % bytesPerChunk > 0)

export const u8AsHexStr = binToHexStr(8, false)
export const i32AsFmtBinStr = binToStr(32, true)
export const i32AsBinStr = binToStr(32)
export const i32AsFmtHexStr = binToHexStr(32, true)
export const i32AsHexStr = binToHexStr(32, false)
