const {
  i32AsBinStr,
  i32AsHexStr,
} = require("./binary_utils.js")

const logI32 = (msg, gotI32) => console.log(`${msg}  ${i32AsBinStr(gotI32)} ${i32AsHexStr(gotI32)}`)
const comparisonErrMsg = (gotI32, expectedI32) => `  Got ${i32AsHexStr(gotI32)}\nExpected ${i32AsHexStr(expectedI32)}`

const simpleComparison = (testName, gotI32, expectedI32) => {
  console.group(`Running ${testName}`)

  // All i32 values coming out of WASM are treated by JavaScript as being signed, but all the test results we're
  // checking for must be treated as unsigned.  If only the got value is negative, then convert it to positive
  if (gotI32 < 0 && expectedI32 > 0) {
    gotI32 = gotI32 + 0xFFFFFFFF + 1
  }

  if (gotI32 === expectedI32) {
    console.log("✅ Success")
  } else {
    console.log(`❌ ${comparisonErrMsg(gotI32, expectedI32)}`)
  }

  console.groupEnd()
}

const compareMemoryBlocks = (testName, gotOffset, expectedOffset, wasmMem32) => {
  console.group(`Running ${testName}`)

  // Read 8 i32s starting at expectedOffset
  // Read 8 i32s starting at offset gotOffset
  // Important: the received offsets are byte offsets, not 32-bit word offsets!
  let offset0 = gotOffset >>> 2
  let offset1 = expectedOffset >>> 2
  let result = 0x00

  for (let idx = 0; idx < 8; idx++) {
    result = (result << 1) | (wasmMem32[offset0 + idx] === wasmMem32[offset1 + idx])
  }

  if (result === 0xFF) {
    console.log("✅ Success")
  } else {
    for (let idx = 0; idx < 8; idx++) {
      console.log(`❌ Index ${idx}: ${comparisonErrMsg(wasmMem32[offset1 + idx], wasmMem32[offset0 + idx])}`)
    }
  }

  console.groupEnd()
}

// Compare the 8 i32 values found in memory at byte offset gotI32
// against the 8 i32 values found in expected_working_values[expectedI32]
const checkWorkingVariables = (testName, byteOffset, expectedIndex, wasmMem32) => {
  console.group(`Running ${testName}`)

  let expected_vals = expected_working_values[expectedIndex]
  let wordIdx = byteOffset >>> 2
  let result = 0x00
  let got = 0
  let expected = 0

  for (let n = 0; n < 8; n++) {
    got = wasmMem32[wordIdx++]
    expected = expected_vals[n]
    result = (result << 1) | got === expected
  }

  if (result === 0xFF) {
    console.log(`✅ Success`)
  } else {
    let varName = ""
    wordIdx = byteOffset >>> 2

    for (n = 0; n < 8; n++) {
      varName = String.fromCharCode(97 + n)
      got = wasmMem32[wordIdx++]
      expected = expected_vals[n]

      if (got === expected) {
        console.log(`✅ $${varName} = ${i32AsHexStr(got)}`)
      } else {
        console.log(`❌ $${varName} Got ${i32AsHexStr(got)}`)
        console.log(` Expected ${i32AsHexStr(expected)}`)
      }
    }
  }

  console.groupEnd()
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// Handle log message from WASM to report an i32 value identified by the msgId
const wasmLogI32 = (msgId, i32) => {
  switch (true) {
    case msgId >= 0 && msgId < 8:
      logI32(`Working variable $${String.fromCharCode(97 + msgId)}`, i32)
      break

    case msgId == 8: logI32("     big_sigma0($a)", i32); break
    case msgId == 9: logI32("     big_sigma1($e)", i32); break
    case msgId == 10: logI32(" choice($e, $f, $g)", i32); break
    case msgId == 11: logI32("           majority", i32); break
    case msgId == 12: logI32("           constant", i32); break
    case msgId == 13: logI32("     msg sched word", i32); break
    case msgId == 14: logI32("temp1", i32); break
    case msgId == 15: logI32("temp2", i32); break

    case msgId >= 400 && msgId < 500:
      logI32(`       fetch constant k(${msgId - 400})`, i32)
      break

    case msgId >= 500 && msgId < 600:
      logI32(`message schedule word w(${msgId - 500})`, i32)
      break


    default: console.error(`Unknown log message id ${msgId}`)
  }
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// Check the result after a WASM function has been tested
const wasmLogCheckTest = wasmMem32 =>
  (testId, gotI32, expectedI32) => {
    switch (true) {
      case testId == 0:
        compareMemoryBlocks("test_initialise_hash_values", gotI32, expectedI32, wasmMem32)
        break

      case testId == 1:
        compareMemoryBlocks("test_initialise_working_variables", gotI32, expectedI32, wasmMem32)
        break

      case testId == 2:
        simpleComparison("test_fetch_working_value", gotI32, expectedI32)
        break

      case testId == 3:
        simpleComparison("test_set_working_value", gotI32, expectedI32)
        break

      case testId == 4:
        simpleComparison("test_swap_endianness", gotI32, expectedI32)
        break

      case testId == 5:
        simpleComparison("test_sigma0", gotI32, expectedI32)
        break

      case testId == 6:
        simpleComparison("test_sigma1", gotI32, expectedI32)
        break

      case testId == 7:
        simpleComparison("test_big_sigma0", gotI32, expectedI32)
        break

      case testId == 8:
        simpleComparison("test_big_sigma1", gotI32, expectedI32)
        break

      case testId > 100 && testId < 200:
        simpleComparison(
          `${testId - 100} pass${testId > 101 ? "es" : ""} of message schedule generation`,
          gotI32,
          expected_msg_sched_values[expectedI32],
        )
        break

      case testId == 200:
        simpleComparison("test_choice", gotI32, expectedI32)
        break

      case testId == 201:
        simpleComparison("test_gen_temp1", gotI32, expectedI32)
        break

      case testId == 202:
        simpleComparison("test_majority", gotI32, expectedI32)
        break

      case testId == 203:
        simpleComparison("test_gen_temp2", gotI32, expectedI32)
        break

      case testId > 300 && testId < 400:
        checkWorkingVariables(
          `${testId - 300} pass${testId > 301 ? "es" : ""} of working variables update`,
          gotI32,
          expectedI32,
          wasmMem32,
        )
        break

      default: console.error(`Unknown test id ${testId}`); break
    }
  }

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
const hostEnv = wasmMemory => {
  let wasmMem32 = new Uint32Array(wasmMemory.buffer)

  return {
    "memory": {
      "pages": wasmMemory,
    },
    "log": {
      "i32": wasmLogI32,
      "checkTest": wasmLogCheckTest(wasmMem32),
    }
  }
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// Expected constant values
const expected_constant_values = [
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
const expected_msg_sched_values = [
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

// Expected working values when processing "ABCD" - words 16 to 63
const expected_working_values = [
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
  ]
]

module.exports = {
  hostEnv
}
