import { i32AsFmtHexStr } from "../utils/binary_utils.mjs"

class TestResult {
  constructor(success, errMsg) {
    this.success = success
    this.errMsg = errMsg
  }
}

const testResultIcon = success => success ? "✅" : "❌"
const comparisonErrMsg = (gotI32, expectedI32) => `     Got ${i32AsFmtHexStr(gotI32)}\nExpected ${i32AsFmtHexStr(expectedI32)}`

const simpleComparison = (gotI32, expectedI32) => {
  // All i32 values coming out of WASM are treated by JavaScript as signed, but all the test results we're checking for
  // must be treated raw binary.  Therefore, if the "got" value is negative and the "expected" value is positive, then
  // convert "got" to positive
  if (gotI32 < 0 && expectedI32 > 0) {
    gotI32 = gotI32 + 0xFFFFFFFF + 1
  }

  return (gotI32 === expectedI32)
    ? new TestResult(true, "")
    : new TestResult(false, `${comparisonErrMsg(gotI32, expectedI32)}`)
}

const compareMemoryBlocks = (gotOffset, expectedOffset, wasmMem32) => {
  // Compare the 8 i32s starting at expectedOffset with the 8 i32s starting at offset gotOffset
  // Important: the received offsets are byte offsets, not 32-bit word offsets!
  let offset0 = gotOffset >>> 2
  let offset1 = expectedOffset >>> 2
  let result = 0x00

  // Each test switches on a bit flag if it passes
  for (let idx = 0; idx < 8; idx++) {
    result = (result << 1) | (wasmMem32[offset0 + idx] === wasmMem32[offset1 + idx])
  }

  return (result === 0xFF)
    ? new TestResult(true, "")
    : new TestResult(false, (() => {
      let msg = ""
      for (let idx = 0; idx < 8; idx++) {
        if (idx > 0) msg += "\n"
        msg += `Index ${idx}: ${comparisonErrMsg(wasmMem32[offset1 + idx], wasmMem32[offset0 + idx])}`
      }
      return msg
    })())
}

// Compare the 8 i32 values found in memory at byte offset gotI32
// against the 8 i32 values found in the supplied array at offset expectedI32
// expectedArray must be an array of arrays
const checkVariables = expectedArray =>
  (byteOffset, expectedIndex, wasmMem32) => {
    let expected_vals = expectedArray[expectedIndex]
    let wordIdx = byteOffset >>> 2
    let result = 0x00

    // Each test switches on a bit flag if it passes
    for (let n = 0; n < 8; n++) {
      result = (result << 1) | wasmMem32[wordIdx++] === expected_vals[n]
    }

    return (result === 0xFF)
      ? new TestResult(true, "")
      : new TestResult(false, (() => {
        let got = 0
        let gotStr = ""
        let varName = ""
        let msg = ""
        wordIdx = byteOffset >>> 2

        for (n = 0; n < 8; n++) {
          varName = String.fromCharCode(97 + n)
          got = wasmMem32[wordIdx++]
          gotStr = i32AsFmtHexStr(got)

          if (n > 0) msg += "\n"

          if (got === expected_vals[n]) {
            msg += `✅ $${varName} = ${gotStr}`
          } else {
            msg += `❌ $${varName}\n${comparisonErrMsg(gotStr, i32AsFmtHexStr(expected_vals[n]))}`
          }
        }
        return msg
      })())
  }

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// Check the result returned by a WASM function test
const wasmLogCheckTestResult = wasmMem32 =>
  (testId, gotI32, expectedI32) => {
    let errorFlag = false
    let testFn = simpleComparison
    let testName = ""

    switch (true) {
      case testId == 0:
        testFn = compareMemoryBlocks
        testName = "should_initialise_hash_values"
        break

      case testId == 1:
        testFn = compareMemoryBlocks
        testName = "should_initialise_working_variables"
        break

      case testId == 2:
        testName = "should_fetch_working_value"
        break

      case testId == 3:
        testName = "should_set_working_value"
        break

      case testId == 4:
        testName = "should_swap_endianness"
        break

      case testId == 5:
        testName = "should_return_sigma0"
        break

      case testId == 6:
        testName = "should_return_sigma1"
        break

      case testId == 7:
        testName = "should_return_big_sigma0"
        break

      case testId == 8:
        testName = "should_return_big_sigma1"
        break

      case testId == 10:
        testFn = checkVariables(expectedHashValues)
        testName = "should_update_hash_vals"
        break

      case testId > 100 && testId < 200:
        testName = `${testId - 100} pass${testId > 101 ? "es" : ""} of message schedule generation`
        expectedI32 = expectedMsgSchedValues[expectedI32]
        break

      case testId == 200:
        testName = "should_return_choice"
        break

      case testId == 201:
        testName = "should_gen_temp1"
        break

      case testId == 202:
        testName = "should_return_majority"
        break

      case testId == 203:
        testName = "should_gen_temp2"
        break

      case testId >= 300 && testId < 400:
        testFn = checkVariables(expectedWorkingVariables)
        testName = `${testId - 300} pass${testId - 300 > 1 ? "es" : ""} updating working variables`
        break

      case testId >= 400 && testId < 500:
        testName = `fetch constant $k${testId - 400}`
        expectedI32 = expectedConstantValues[expectedI32]
        break

      default:
        errorFlag = true
    }

    if (errorFlag) {
      console.error(`Unknown test id ${testId}`)
    } else {
      let result = testFn(gotI32, expectedI32, wasmMem32)

      console.group(`${testResultIcon(result.success)} Test id ${testId.toString().padStart(3, " ")}: ${testName}`)
      if (result.errMsg.length > 0) console.log(result.errMsg)
      console.groupEnd()
    }
  }

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// Expected constant values
const expectedConstantValues = [
  0b01000010100010100010111110011000,
  0b01110001001101110100010010010001,
  0b10110101110000001111101111001111,
  0b11101001101101011101101110100101,
  0b00111001010101101100001001011011,
  0b01011001111100010001000111110001,
  0b10010010001111111000001010100100,
  0b10101011000111000101111011010101,
  0b11011000000001111010101010011000,
  0b00010010100000110101101100000001,
  0b00100100001100011000010110111110,
  0b01010101000011000111110111000011,
  0b01110010101111100101110101110100,
  0b10000000110111101011000111111110,
  0b10011011110111000000011010100111,
  0b11000001100110111111000101110100,
  0b11100100100110110110100111000001,
  0b11101111101111100100011110000110,
  0b00001111110000011001110111000110,
  0b00100100000011001010000111001100,
  0b00101101111010010010110001101111,
  0b01001010011101001000010010101010,
  0b01011100101100001010100111011100,
  0b01110110111110011000100011011010,
  0b10011000001111100101000101010010,
  0b10101000001100011100011001101101,
  0b10110000000000110010011111001000,
  0b10111111010110010111111111000111,
  0b11000110111000000000101111110011,
  0b11010101101001111001000101000111,
  0b00000110110010100110001101010001,
  0b00010100001010010010100101100111,
  0b00100111101101110000101010000101,
  0b00101110000110110010000100111000,
  0b01001101001011000110110111111100,
  0b01010011001110000000110100010011,
  0b01100101000010100111001101010100,
  0b01110110011010100000101010111011,
  0b10000001110000101100100100101110,
  0b10010010011100100010110010000101,
  0b10100010101111111110100010100001,
  0b10101000000110100110011001001011,
  0b11000010010010111000101101110000,
  0b11000111011011000101000110100011,
  0b11010001100100101110100000011001,
  0b11010110100110010000011000100100,
  0b11110100000011100011010110000101,
  0b00010000011010101010000001110000,
  0b00011001101001001100000100010110,
  0b00011110001101110110110000001000,
  0b00100111010010000111011101001100,
  0b00110100101100001011110010110101,
  0b00111001000111000000110010110011,
  0b01001110110110001010101001001010,
  0b01011011100111001100101001001111,
  0b01101000001011100110111111110011,
  0b01110100100011111000001011101110,
  0b01111000101001010110001101101111,
  0b10000100110010000111100000010100,
  0b10001100110001110000001000001000,
  0b10010000101111101111111111111010,
  0b10100100010100000110110011101011,
  0b10111110111110011010001111110111,
  0b11000110011100010111100011110010,
]

// Expected message schedule values when processing "ABCD" - words 16 to 63
const expectedMsgSchedValues = [
  0b01010010010000100110001101000100,
  0b10000000000101000000000000000000,
  0b01111101110111100011001111110001,
  0b10000000001000000101010100001000,
  0b11011111100110011110011011011000,
  0b00100000000001010101100000000001,
  0b11001111100000001001001001100110,
  0b01011001010010110001100010011000,
  0b11011011011000000101111000010100,
  0b01101101001001111010100100111011,
  0b10100101000111101000001111010011,
  0b00000001001110110111100110110101,
  0b10110001110000000011100110001101,
  0b10100011011011010000000011001010,
  0b10110101001011100011011101110010,
  0b00010101111100110001100100001101,
  0b10101101111001101101110001000011,
  0b01110110100100001111110111000010,
  0b01001000111000101111001010100001,
  0b01100111000111111001100100101010,
  0b11111010010111101000011100100100,
  0b00000101110100111110100010000101,
  0b01110110011110100000010010101000,
  0b10110101111001010100100100101010,
  0b00100101111111100110100010000101,
  0b11010110110001010001010100110010,
  0b10111001111000011100000001100010,
  0b00100110110111010110110100001010,
  0b01010000110000010110100010010001,
  0b10110011001010000001111000101011,
  0b11100011001110001111001100101101,
  0b01101110111001011110010011010001,
  0b10100001110001110001100100100011,
  0b01110110100000011010101110000100,
  0b10011101110001011000101010011000,
  0b10010000000001100110101100110010,
  0b00010010010011110110110100111100,
  0b11000000111100011010000001001101,
  0b01010010001110101101000011111100,
  0b11010000101000010011111100011001,
  0b00001001001011101101111100110100,
  0b11001111001111011110111111001001,
  0b01001010001110111001100001100101,
  0b11110101111110001110011100111011,
  0b00010111011010010100101011001101,
  0b11110000000101010000000011101110,
  0b00010110010010100101001000111011,
  0b00101101100111101110110010110100,
]

// Expected working variables when processing "ABCD" - words 16 to 63
const expectedWorkingVariables = [
  [
    0b00111101010010101100101110010001,
    0b01101010000010011110011001100111,
    0b10111011011001111010111010000101,
    0b00111100011011101111001101110010,
    0b11011010000010100010010111100110,
    0b01010001000011100101001001111111,
    0b10011011000001010110100010001100,
    0b00011111100000111101100110101011,
  ],

  [
    0b11111000101011010000110000110100,
    0b00111101010010101100101110010001,
    0b01101010000010011110011001100111,
    0b10111011011001111010111010000101,
    0b11000000110110101111010011011010,
    0b11011010000010100010010111100110,
    0b01010001000011100101001001111111,
    0b10011011000001010110100010001100,
  ],
  [
    0b00100010101110111100110011101011,
    0b11111000101011010000110000110100,
    0b00111101010010101100101110010001,
    0b01101010000010011110011001100111,
    0b01111010010111010101011110110100,
    0b11000000110110101111010011011010,
    0b11011010000010100010010111100110,
    0b01010001000011100101001001111111,
  ],
  [
    0b01111110010111001001111011011110,
    0b00100010101110111100110011101011,
    0b11111000101011010000110000110100,
    0b00111101010010101100101110010001,
    0b01101110111101100110111000100110,
    0b01111010010111010101011110110100,
    0b11000000110110101111010011011010,
    0b11011010000010100010010111100110,
  ],
  [], [], [], [],
  [], [], [], [],
  [], [], [], [],
  [], [], [], [],
  [], [], [], [],
  [], [], [], [],
  [], [], [], [],
  [
    0b11000100010001010100110001111101,
    0b11110110000000011101110111001101,
    0b10111011001111001101110011100011,
    0b00101001000100011000000001100001,
    0b10010000110101101101110001001011,
    0b10000001011100010101000101010101,
    0b00110110000011100101100001001111,
    0b11100011001110111001001010101101,
  ],
  [], [], [], [],
  [], [], [], [],
  [], [], [], [],
  [], [], [], [],
  [], [], [], [],
  [], [], [], [],
  [], [], [], [],
  [],
  [
    0b00010011110111011010010000101101,
    0b00011010000111000110001001110111,
    0b10010111011011010100001111111111,
    0b10101010100010010010000011010010,
    0b11100111001111110001011100100011,
    0b10101010000100111010111001111111,
    0b10100110111100010110100101011110,
    0b11000101011010000010011001011001,
  ],
  [
    0b01110111001001000010101011110011,
    0b00010011110111011010010000101101,
    0b00011010000111000110001001110111,
    0b10010111011011010100001111111111,
    0b11111011010000001010010110011101,
    0b11100111001111110001011100100011,
    0b10101010000100111010111001111111,
    0b10100110111100010110100101011110,
  ]
]

// Expected hash values after processing "ABCD"
const expectedHashValues = [
  // Expected values given as i32s in little-endian byte order!
  [
    0b01011010000100010010111011100001,
    0b10110010010100100100010111001111,
    0b11101001010101011000101101010110,
    0b00111001001110011011110100111100,
    0b00011100111110000100111001001100,
    0b10101111011111110100010010000010,
    0b00101010100010001001011111001001,
    0b01110111001101101101001000000010,
  ]
]

export {
  expectedConstantValues,
  expectedHashValues,
  expectedMsgSchedValues,
  expectedWorkingVariables,
  wasmLogCheckTestResult,
}
