const {
  i32AsBinStr,
  i32AsHexStr,
} = require("./binary_utils.js")

const formatI32 = i32 => `${i32AsBinStr(i32)} ${i32AsHexStr(i32)}`
const formatI64 = i64 => `${i64AsBinStr(i64)} ${i64AsHexStr(i64)}`

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
module.exports = {
  wasmLogI32,
  wasmLogI32Pair,
}
