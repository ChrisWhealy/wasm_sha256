const chunksOf = bytesPerChunk => size => Math.floor(size / bytesPerChunk) + (size % bytesPerChunk > 0)

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Display a raw binary value of bit length `len` as a binary string
// Additional ASCII text formatting can also be displayed
const binToStr =
  (len, showAscii) =>
    val => {
      let result = ""

      // Generate binary string
      for (let shift = (len - 1); shift >= 0; shift--) {
        result += ((val >>> shift) & 0x0001) ? "1" : "0"
        if (shift % 8 === 0 && shift !== 0) result += " "  // Add a space every 8 bits
      }

      if (!!showAscii) {
        result += " "

        // Generate ASCII string substituting any control characters for spaces
        // Here we assume the data will be supplied in network (or big-endian) byte order
        // If the data is in little-endian byte order, the string will be printed backwards
        for (let shift = len / 8; shift > 0; shift--) {
          let c = (val >>> (shift - 1) * 8) & 0x00FF
          result += String.fromCharCode(c < 32 ? 32 : c)
        }
      }

      return result
    }

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Display a raw binary value of bit length `len` as a hexadecimal string
const hexDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f']
const binToHexStr =
  (len, prefix) =>
    val => {
      let result = prefix ? "0x" : ""

      // Generate hexadecimal string
      for (let shift = ((len / 4) - 1); shift >= 0; shift--) {
        result += hexDigits[val >>> (shift * 4) & 0x000F]
      }

      return result
    }

module.exports = {
  swapEndianness: i32 =>
    (i32 & 0x000000FF) << 24 |
    (i32 & 0x0000FF00) << 8 |
    (i32 & 0x00FF0000) >>> 8 |
    (i32 & 0xFF000000) >>> 24,

  stringToAsciiArray: str => [...str].map(c => c.charCodeAt()),
  asciiArrayToString: ascArray => String.fromCharCode(...ascArray),

  u8AsHexStr: binToHexStr(8, false),

  i32AsFmtBinStr: binToStr(32, true),
  i32AsBinStr: binToStr(32),
  i32AsHexStr: binToHexStr(32, true),

  memPages: chunksOf(64 * 1024),  // 64K memory pages
  msgBlocks: chunksOf(64),        // 64 byte message blocks
}