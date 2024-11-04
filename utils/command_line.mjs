import { TEST_DATA } from "../tests/testData.mjs"
import { existsSync } from "fs"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const abortWithErrMsg = errMsg => {
  console.error(errMsg)
  process.exit(1)
}

const abortWithUsage = () => abortWithErrMsg("Usage: node index.mjs <filename>\n   or: node index.mjs -test <test_case_num>")
const abortWithFileNotFound = fileName => abortWithErrMsg(`Error: File "${fileName}" does not exist`)
const abortWithTestCaseMissing = () => abortWithErrMsg("Error: Test case number missing")
const abortWithTestCaseNotFound = testCase => abortWithErrMsg(`Error: Test case "${testCase}" does not exist\n       Enter a test case number between 0 and ${TEST_DATA.length - 1}`)

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const handleCmdLine = argv => {
  // I can haz command line arguments?
  if (argv.length < 3) {
    abortWithUsage()
  }

  let filename = argv[2]

  // Check for running test cases
  if (filename === "-test") {
    // Check for valid test case number
    if (argv.length > 3) {
      if (isNaN(parseInt(argv[3])) || argv[3] >= TEST_DATA.length) {
        abortWithTestCaseNotFound(argv[3])
      }

      filename = TEST_DATA[argv[3]].fileName
    } else {
      abortWithTestCaseMissing()
    }
  }

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Handle file not found gracefully
  if (!existsSync(filename)) {
    abortWithFileNotFound(filename)
  }

  return filename
}

export {
  handleCmdLine
}
