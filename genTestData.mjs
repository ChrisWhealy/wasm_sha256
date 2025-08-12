import fs from 'fs'

const line64Bytes = "ABCDEFGHIJKLMNOPQRSTUVWXYZ012345ABCDEFGHIJKLMNOPQRSTUVWXYZ01234"
const divLine = "---------------------------------------------------------|"
const divider = num => `|${num.toString().padStart(4, ' ')}${divLine}`
const LF = "\n"

export const genTestData = async (sizeInKb, silent) => {
  const filename = `./tests/test_data_${sizeInKb}kb.txt`
  const ws = fs.createWriteStream(filename)
  const lineEnd = [
      line64Bytes, line64Bytes, line64Bytes, line64Bytes, line64Bytes,
      line64Bytes, line64Bytes, line64Bytes, line64Bytes, line64Bytes,
      line64Bytes, line64Bytes, line64Bytes, line64Bytes, line64Bytes,
    ].join(LF)

  for (let kbCount = 0; kbCount < sizeInKb; kbCount += 1) {
    ws.write(`${divider(kbCount)}${LF}${lineEnd}${LF}`)
  }

  ws.end()

  ws.on('finish', () => {
      if (!silent) {
        const stats = fs.statSync(filename)
        console.log(`File created successfully!`)
        console.log(`Actual size: ${stats.size} bytes (${(stats.size / 1024).toFixed(2)} KB)`)
      }
  })

  ws.on('error', err => console.error('Error writing file:', err))
}

// ---------------------------------------------------------------------------------------------------------------------
if (process.argv.length < 3) {
  console.error("Usage: node genTestData <file-size-in-Kb>")
} else {
  let size = Number(process.argv[2])

  if (isNaN(size)) {
    console.error(`Error: '${process.argv[2]}' is not numeric`)
  } else {
    genTestData(size)
  }
}
