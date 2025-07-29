import fs from 'fs'

const line64Bytes = "ABCDEFGHIJKLMNOPQRSTUVWXYZ012345ABCDEFGHIJKLMNOPQRSTUVWXYZ01234"
const divLine = "---------------------------------------------------------|"
const divider = num => `|${num.toString().padStart(4, ' ')}${divLine}`
const LF = "\n"

const genTestData = sizeInKb => {
  const filename = `./tests/test_data_${sizeInKb}kb.txt`
  const ws = fs.createWriteStream(filename)

  for (let kbCount = 0; kbCount < sizeInKb; kbCount += 1) {
    let chunk = [
      divider(kbCount), line64Bytes, line64Bytes, line64Bytes, line64Bytes, line64Bytes, line64Bytes, line64Bytes,
      line64Bytes, line64Bytes, line64Bytes, line64Bytes, line64Bytes, line64Bytes, line64Bytes, line64Bytes,
    ].join(LF)

    ws.write(`${chunk}${LF}`)
  }

  ws.end()

  ws.on('finish', () => {
      const stats = fs.statSync(filename)
      console.log(`File created successfully!`)
      console.log(`Actual size: ${stats.size} bytes (${(stats.size / 1024).toFixed(2)} KB)`)
  })

  ws.on('error', err => console.error('Error writing file:', err))
}

// ---------------------------------------------------------------------------------------------------------------------
if (process.argv.length < 3) {
  console.error("Please specify a file size in Kb")
} else {
  let size = Number(process.argv[2])

  if (isNaN(size)) {
    console.error("Please specify a numeric value in Kb for the file size")
  } else {
    genTestData(size)
  }
}
