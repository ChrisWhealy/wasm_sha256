import {
  i32AsBinStr,
  i32AsHexStr,
  swapEndianness
} from "./binary_utils.js"

const formatI32 = i32 => `${i32AsBinStr(i32)} ${i32AsHexStr(i32)}`

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// WASM log message reporting an i32 value identified by msgId
const wasmLogI32 = (msgId, arg0) => {
  let logMsg = ""

  switch (true) {
    case msgId >= 0 && msgId < 8:
      logMsg = `Working variable $${String.fromCharCode(97 + msgId)} ${formatI32(arg0)}`
      break

    case msgId == 8: logMsg = `     big_sigma0($a) ${formatI32(arg0)}`; break
    case msgId == 9: logMsg = `     big_sigma1($e) ${formatI32(arg0)}`; break
    case msgId == 10: logMsg = ` choice($e, $f, $g) ${formatI32(arg0)}`; break
    case msgId == 11: logMsg = `           majority ${formatI32(arg0)}`; break
    case msgId == 12: logMsg = `           constant ${formatI32(arg0)}`; break
    case msgId == 13: logMsg = `     msg sched word ${formatI32(arg0)}`; break
    case msgId == 14: logMsg = `temp1 ${formatI32(arg0)}`; break
    case msgId == 15: logMsg = `temp2 ${formatI32(arg0)}`; break

    case msgId == 16: logMsg = `MEM_BLK_OFFSET ${formatI32(arg0)}`; break
    case msgId == 17: logMsg = `Memory size = ${i32AsHexStr(arg0)} 64Kb pages`; break

    case msgId == 20: logMsg = `    $d + $temp1 ${formatI32(arg0)}`; break
    case msgId == 21: logMsg = `$temp1 + $temp2 ${formatI32(arg0)}`; break

    case msgId >= 400 && msgId < 500:
      logMsg = `       fetch constant k(${msgId - 400}) ${formatI32(arg0)}`
      break

    case msgId >= 500 && msgId < 600:
      logMsg = `message schedule word w(${msgId - 500} ${formatI32(arg0)}`
      break

    default: logMsg = `Unknown log message id ${msgId}`
  }

  console.log(`WASM Log: ${logMsg}`)
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// WASM log message reporting a pair of i32 values identified by msgId
const wasmLogI32Pair = (msgId, arg0, arg1) => {
  logMsg = ""

  switch (true) {
    case msgId == 0: logMsg = `Working variable $${String.fromCharCode(97 + arg1)}: ${formatI32(arg0)}`; break
    case msgId == 1: logMsg = `     Hash value $h${arg1}: ${formatI32(arg0)}`; break
    case msgId == 2: logMsg = `           $${String.fromCharCode(97 + arg1)} + $h${arg1}: ${formatI32(arg0)}`; break

    default: logMsg = `Unknown log message id ${msgId}`
  }

  console.log(`WASM Log: ${logMsg}`)
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// Display contents of message schedule
const wasmShowMsgSchedule = wasmMem32 => () => {
  let msgSchedIdx = 128

  for (let idx = 0; idx < 64; idx++) {
    let i32 = wasmMem32[msgSchedIdx + idx]
    console.log(`WASM Msg Schedule: w${idx}${idx < 10 ? " " : ""} ${i32AsBinStr(i32)} ${i32AsHexStr(i32)}`)
  }
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// Display hash values after a message schedule chunk has been processed
const wasmShowHashVals = wasmMem32 => chunkNum => {
  let hashValsIdx = 72

  for (let idx = 0; idx < 8; idx++) {
    let i32 = swapEndianness(wasmMem32[hashValsIdx + idx])
    console.log(`WASM Hash Values for block ${chunkNum}: h${idx}${idx < 10 ? " " : ""} ${i32AsBinStr(i32)} ${i32AsHexStr(i32)}`)
  }
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// Display current message block
const wasmShowMsgBlock = wasmMem32 => blockNum => {
  let msgBlockIdx = 16384 + (blockNum - 1) * 16

  for (let idx = 0; idx < 16; idx++) {
    let bigEndianVal = swapEndianness(wasmMem32[msgBlockIdx + idx])
    console.log(`${idx == 0 ? "\nWASM" : "WASM"} Msg Block ${blockNum}: ${i32AsBinStr(bigEndianVal)} ${i32AsHexStr(bigEndianVal)}`)
  }
}

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// Display current message block
const wasmLogMemCopyArgs = (src, dest) =>
  console.log(`\nWASM Log: Copying 64 bytes from ${i32AsHexStr(src)} to ${i32AsHexStr(dest)}`)


export {
  wasmLogI32,
  wasmLogI32Pair,
  wasmShowMsgSchedule,
  wasmShowMsgBlock,
  wasmShowHashVals,
  wasmLogMemCopyArgs,
}
