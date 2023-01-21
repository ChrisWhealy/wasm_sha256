const swapEndianness = i32 =>
  (i32 & 0x000000FF) << 24 |
  (i32 & 0x0000FF00) << 8 |
  (i32 & 0x00FF0000) >>> 8 |
  (i32 & 0xFF000000) >>> 24

const stringToAsciiArray = str => [...str].map(c => c.charCodeAt())
const asciiArrayToString = ascArray => String.fromCharCode(...ascArray)

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Display a raw binary value of bit length `len` as a binary string
// Additional ASCII text formatting can also be displayed
const binToStr =
  (len, withFormat) =>
    val => {
      let result = ""

      // Generate binary string
      for (let shift = (len - 1); shift >= 0; shift--) {
        result += ((val >>> shift) & 0x0001) ? "1" : "0"
        if (shift % 8 === 0 && shift !== 0) result += " "
      }

      if (!!withFormat) {
        result += " "

        // Generate ASCII string but exclude control characters
        // If the data being displayed is in little-endian byte order, the string will be printed backwards
        for (let shift = len / 8; shift > 0; shift--) {
          let c = (val >>> (shift - 1) * 8) & 0x00FF
          result += String.fromCharCode(c < 32 ? 32 : c)
        }
      }

      return result
    }

const i32AsFmtBinStr = binToStr(32, true)
const i32AsBinStr = binToStr(32)

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Display a raw binary value of bit length `len` as a hexadecimal string
const hexDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f']
const binToHexStr =
  len =>
    val => {
      let result = "0x"

      // Generate hexadecimal string
      for (let shift = ((len / 4) - 1); shift >= 0; shift--) {
        result += hexDigits[val >>> (shift * 4) & 0x000F]
      }

      result += " "
      return result
    }

const i32AsHexStr = binToHexStr(32)

module.exports = {
  swapEndianness,
  i32AsFmtBinStr,
  i32AsBinStr,
  i32AsHexStr,

  stringToAsciiArray,
  asciiArrayToString,
}
