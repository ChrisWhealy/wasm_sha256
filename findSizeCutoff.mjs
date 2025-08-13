import { execFile } from 'child_process'
import { genTestData } from './genTestData.mjs'

// ---------------------------------------------------------------------------------------------------------------------
const callSha256 = sizeKb => {
  return new Promise((resolve, reject) => execFile(
    'sha256sum',
    [`./tests/test_data_${sizeKb}kb.txt`],
    (error, stdout, stderr) => {
      if (error) { return reject(error) }
      if (stderr) { return reject(stderr) }

      const [hash] = stdout.split(/\s+/)
      resolve(hash)
    }
  ))
}

// ---------------------------------------------------------------------------------------------------------------------
const callWasmSha256 = sizeKb => {
  return new Promise((resolve, reject) => execFile(
    'wasmer',
    ['run', '.', '--mapdir', '/::./tests', `test_data_${sizeKb}kb.txt`],
    (error, stdout, stderr) => {
      if (error) { return reject(error) }
      if (stderr) { return reject(stderr) }

      const [hash] = stdout.split(/\s+/)
      resolve(hash)
    }
  ))
}

// ---------------------------------------------------------------------------------------------------------------------
const compareHashes = async sizeKb => {
  await genTestData(sizeKb, true)

  const macOsHash = await callSha256(sizeKb)
  const wasmHash = await callWasmSha256(sizeKb)


  if (macOsHash === wasmHash) {
    console.log(`✅ ${sizeKb}Kb`)
  } else {
    console.log(`❌ ${sizeKb}Kb  WASM hash ${wasmHash} ≠ sha256sum ${macOsHash}`)
  }

  return macOsHash === wasmHash
}

// ---------------------------------------------------------------------------------------------------------------------
const findMismatch = async maxSize => {
  let lastGoodSize = 0
  let firstMismatch = null

  // Find first mismatch
  for (let sizeMb = 1; sizeMb < maxSize; sizeMb++) {
    let sizeKb = sizeMb * 1024
    if (await compareHashes(sizeKb)) {
      lastGoodSize = sizeKb
    } else {
      firstMismatch = sizeKb
      break
    }
  }

  if (firstMismatch === null) {
    console.log(`No mismatches up to ${maxSize}Mb`)
  } else {
    // Binary search for the first non-matching size
    let low = lastGoodSize + 1
    let high = firstMismatch

    while (low < high) {
      const mid = Math.floor((low + high) / 2)

      if (await compareHashes(mid)) {
        low = mid + 1
      } else {
        high = mid
      }
    }

    console.log(`Hashes differ at ${low}Kb`);
  }
}

// ---------------------------------------------------------------------------------------------------------------------
(async () => {
  try {
    await findMismatch(100)
  } catch (err) {
    console.error("Error: ", err);
  }
})()
