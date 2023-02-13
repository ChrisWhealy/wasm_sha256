/***********************************************************************************************************************
 * Partial function to create a column-aligned time formatter
 */
const timeStringFormatter = (longestName, maxDigits, markCount) =>
  (thisMark, nextMark, idx) => {
    let str = thisMark.name

    if (idx < markCount) {
      let micros = Math.round((nextMark.time - thisMark.time) * 1000)

      let millis = (micros > 999) ? Math.trunc(micros / 1000) : 0
      let fraction = (micros > 999) ? micros % (millis * 1000) : micros

      // Zero pad both ends of the fraction string
      let fractionStr = fraction < 10
        ? `00${fraction}`
        : fraction < 100
          ? `0${fraction}`
          : fraction.toString().padEnd(3, "0")

      str = `${thisMark.name.padEnd(longestName, " ")} : ${millis.toString().padStart(maxDigits - 4, " ")}.${fractionStr} ms`
    }

    return str
  }

/***********************************************************************************************************************
 * A dummy class containing only no-op methods
 * Allows you to switch off performance tracking without changing any application code
 */
class DummyPerfTracker {
  constructor() { }

  addMark() { }
  reset() { }
  listMarks() { }
}

/***********************************************************************************************************************
 * Performance tracker
 */
class PerfTracker {
  longestName = 0
  maxDigits = 0

  constructor() {
    this.#initialise()
  }

  #initialise = () =>
    this.performanceMarks = [{
      "name": "Start up",
      "time": performance.now()
    }]

  /***
   * Insert new performance marker
   *
   * Timings are shown in milleseconds to three decimal places (the nearest microsecond) and displayed with aligned
   * decimal points.  The number of digits to the left of the decimal point is calculated by:
   *
   *   Math.trunc(Math.log10(Math.round(now * 1000) / 1000)) + 1
   *
   * 4 more characters need to be added to account for the decimal point and the three fractional digits; hence "+ 5"
   */
  addMark = name => {
    let now = performance.now()
    let digits = Math.trunc(Math.log10(Math.round(now * 1000) / 1000)) + 5

    this.performanceMarks.push({
      "name": name,
      "time": now,
    })

    if (digits > this.maxDigits) this.maxDigits = digits
    if (name.length > this.longestName) this.longestName = name.length
  }

  /***
   * Re-initialise the performance markers
   */
  reset = () => this.#initialise()

  /***
   * Display existing performance markers
   */
  listMarks = () => {
    let fmtTimeStr = timeStringFormatter(this.longestName, this.maxDigits, this.performanceMarks.length)

    this.performanceMarks.push({
      "name": "Done",
      "time": performance.now()
    })

    console.log(
      this.performanceMarks.length < 3
        ? "No performance marks recorded between start up and now"
        : this.performanceMarks.map((mark, idx, marks) => fmtTimeStr(mark, marks[idx + 1], idx)).join("\n")
    )
  }
}

export const doTrackPerformance = keepTrack => !!keepTrack ? new PerfTracker : new DummyPerfTracker
