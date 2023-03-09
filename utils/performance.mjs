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
  #totalMillis = 0
  #longestName = 0
  #maxDigits = 0
  #performanceMarks = []

  constructor() {
    this.#initialise()
  }

  #initialise = () => {
    this.#totalMillis = 0
    this.#longestName = 0
    this.#maxDigits = 0
    this.#performanceMarks = []
    this.addMark("Start up")
  }

  #formatAsMillis = p_millis => {
    let micros = Math.round(p_millis * 1000)
    let millis = (micros > 999) ? Math.trunc(micros / 1000) : 0
    let fraction = ((micros > 999) ? micros % (millis * 1000) : micros).toString().padStart(3, "0")

    return `${millis.toString().padStart(this.#maxDigits - 4, " ")}.${fraction}`
  }

  #formatPerfMark = (thisMark, nextMark, idx) =>
    (idx < this.#performanceMarks.length - 1)
      ? `${thisMark.name.padEnd(this.#longestName, " ")} : ${this.#formatAsMillis(nextMark.time - thisMark.time)} ms`
      : `\n${thisMark.name} in ${this.#formatAsMillis(this.#totalMillis)} ms`

  /***
   * Insert new performance marker
   */
  addMark = name => {
    let now = performance.now()

    this.#performanceMarks.push({
      "name": name,
      "time": now,
    })

    // Calculate the length of the formatted string
    // Math.log10() returns the number of digits to the left of the decimal point minus one, then 4 more characters
    // need to be added to account for the decimal point and the three fractional digits; hence "+ 5"
    let digits = Math.trunc(Math.log10(Math.round(now * 1000) / 1000)) + 5

    if (digits > this.#maxDigits) this.#maxDigits = digits
    if (name.length > this.#longestName) this.#longestName = name.length
    if (this.#performanceMarks.length > 1) {
      this.#totalMillis += now - this.#performanceMarks[this.#performanceMarks.length - 2].time
    }
  }

  /***
   * Re-initialise the performance markers
   */
  reset = () => this.#initialise()

  /***
   * Display existing performance markers
   *
   * Timings are shown in milleseconds to three decimal places (the nearest microsecond) and displayed with aligned
   * decimal points.
   */
  listMarks = () => {
    this.addMark("Done")

    console.log(
      this.#performanceMarks.length < 3
        ? "No performance marks recorded between start up and now"
        : this.#performanceMarks
          .map((mark, idx, marks) => this.#formatPerfMark(mark, marks[idx + 1], idx))
          .join("\n")
    )
  }
}

export const doTrackPerformance = keepTrack => !!keepTrack ? new PerfTracker : new DummyPerfTracker
