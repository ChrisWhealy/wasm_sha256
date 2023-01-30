(module
  (import "memory" "pages" (memory 2)
    ;; Page 1: 0x000000 - 0x00001F  Constants - fractional part of square root of first 8 primes
    ;;         0x000020 - 0x00011F  Constants - fractional part of cube root of first 64 primes
    ;;         0x000120 - 0x00012F  Hex character lookup
    ;;         0x000130 - 0x00014F  Hash values
    ;;         0x000150 - 0x00024F  Message Schedule
    ;; Page 2: 0x010000 - 0x01FFFF  Message Block (file data)
  )

  ;; The host environment tells WASM how many message blocks the file occupies
  (global $MSG_BLK_COUNT (import "message" "blockCount") i32)

  (global $INIT_HASH_VALS_OFFSET i32 (i32.const 0x000000))
  (global $CONSTANTS_OFFSET      i32 (i32.const 0x000020))
  (global $HEX_CHARS_OFFSET      i32 (i32.const 0x000120))
  (global $HASH_VALS_OFFSET      i32 (i32.const 0x000130))
  (global $MSG_SCHED_OFFSET      i32 (i32.const 0x000150))
  (global $MSG_BLK_OFFSET        i32 (i32.const 0x010000))

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; The first 32 bits of the fractional parts of the square roots of the first 8 primes 2..19
  ;; Used to initialise the hash values
  ;; Values below are in little-endian byte order!
  (data (i32.const 0x000000)    ;; $INIT_HASH_VALS_OFFSET
    "\67\E6\09\6A"  ;; 0x000000
    "\85\AE\67\BB"
    "\72\F3\6E\3C"
    "\3A\F5\4F\A5"
    "\7F\52\0E\51"  ;; 0x010010
    "\8C\68\05\9B"
    "\AB\D9\83\1F"
    "\19\CD\E0\5B"
  )

  ;; The first 32 bits of the fractional parts of the cube roots of the first 64 primes 2..311
  ;; Used in phase 2 of message schedule processing
  ;; Values below are in little-endian byte order!
  (data (i32.const 0x000020)    ;; $CONSTANTS_OFFSET
    "\98\2F\8A\42"  ;; 0x000020
    "\91\44\37\71"
    "\CF\FB\C0\B5"
    "\A5\DB\B5\E9"
    "\5B\C2\56\39"  ;; 0x000030
    "\F1\11\F1\59"
    "\A4\82\3F\92"
    "\D5\5E\1C\AB"
    "\98\AA\07\D8"  ;; 0x000040
    "\01\5B\83\12"
    "\BE\85\31\24"
    "\C3\7D\0C\55"
    "\74\5D\BE\72"  ;; 0x000050
    "\FE\B1\DE\80"
    "\A7\06\DC\9B"
    "\74\F1\9B\C1"
    "\C1\69\9B\E4"  ;; 0x000060
    "\86\47\BE\EF"
    "\C6\9D\C1\0F"
    "\CC\A1\0C\24"
    "\6F\2C\E9\2D"  ;; 0x000070
    "\AA\84\74\4A"
    "\DC\A9\B0\5C"
    "\DA\88\F9\76"
    "\52\51\3E\98"  ;; 0x000080
    "\6D\C6\31\A8"
    "\C8\27\03\B0"
    "\C7\7F\59\BF"
    "\F3\0B\E0\C6"  ;; 0x000090
    "\47\91\A7\D5"
    "\51\63\CA\06"
    "\67\29\29\14"
    "\85\0A\B7\27"  ;; 0x0000A0
    "\38\21\1B\2E"
    "\FC\6D\2C\4D"
    "\13\0D\38\53"
    "\54\73\0A\65"  ;; 0x0000B0
    "\BB\0A\6A\76"
    "\2E\C9\C2\81"
    "\85\2C\72\92"
    "\A1\E8\BF\A2"  ;; 0x0000C0
    "\4B\66\1A\A8"
    "\70\8B\4B\C2"
    "\A3\51\6C\C7"
    "\19\E8\92\D1"  ;; 0x0000D0
    "\24\06\99\D6"
    "\85\35\0E\F4"
    "\70\A0\6A\10"
    "\16\C1\A4\19"  ;; 0x0000E0
    "\08\6C\37\1E"
    "\4C\77\48\27"
    "\B5\BC\B0\34"
    "\B3\0C\1C\39"  ;; 0x0000F0
    "\4A\AA\D8\4E"
    "\4F\CA\9C\5B"
    "\F3\6F\2E\68"
    "\EE\82\8F\74"  ;; 0x000100
    "\6F\63\A5\78"
    "\14\78\C8\84"
    "\08\02\C7\8C"
    "\FA\FF\BE\90"  ;; 0x000110
    "\EB\6C\50\A4"
    "\F7\A3\F9\BE"
    "\F2\78\71\C6"
  )

  ;; $HEX_CHARS_OFFSET
  (data (i32.const 0x000120) "0123456789abcdef")

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Reverse the byte order of $val
  (func $swap_endianness
        (param $val i32)
        (result i32)
    (i32.or
      (i32.or
        (i32.shl (i32.and (local.get $val) (i32.const 0x000000FF)) (i32.const 24))
        (i32.shl (i32.and (local.get $val) (i32.const 0x0000FF00)) (i32.const 8))
      )
      (i32.or
        (i32.shr_u (i32.and (local.get $val) (i32.const 0x00FF0000)) (i32.const 8))
        (i32.shr_u (i32.and (local.get $val) (i32.const 0xFF000000)) (i32.const 24))
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Calculate the sigma value of the raw binary 32-bit word $val
  (func $sigma
        (param $val        i32)  ;; Raw binary value
        (param $rotr_bits1 i32)  ;; 1st rotate right value
        (param $rotr_bits2 i32)  ;; 2nd rotate right value
        (param $shftr_bits i32)  ;; Shift right value
        (result i32)

    (i32.xor
      (i32.xor
        (i32.rotr (local.get $val) (local.get $rotr_bits1))
        (i32.rotr (local.get $val) (local.get $rotr_bits2))
      )
      (i32.shr_u (local.get $val) (local.get $shftr_bits))
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; The value of the 32-bit word found at byte offset $offset is calculated using the four, 32-bit words found at the
  ;; following earlier offsets.  These four words must all be treated as raw binary:
  ;;
  ;; $w1 = word_at($offset - (4 * 16))
  ;; $w2 = word_at($offset - (4 * 15))
  ;; $w3 = word_at($offset - (4 * 7))
  ;; $w4 = word_at($offset - (4 * 2))
  ;;
  ;; sigma0 = rotr($w2, 7)  XOR rotr($w2, 18) XOR shr_u($w2, 3)
  ;; sigma1 = rotr($w4, 17) XOR rotr($w4, 19) XOR shr_u($w4, 10)
  ;;
  ;; result = $w1 + $sigma0($w2) + $w3 + $sigma1($w4)
  (func $gen_msg_sched_word
        (param $offset i32)
        (result i32)

    (i32.add
      (i32.add
        (i32.load (i32.sub (local.get $offset) (i32.const 64)))    ;; word_at($offset - 16 words)
        (call $sigma                                               ;; Calculate sigma0
          (i32.load (i32.sub (local.get $offset) (i32.const 60)))  ;; word_at($offset - 15 words)
          (i32.const 7)
          (i32.const 18)
          (i32.const 3)
        )
      )
      (i32.add
        (i32.load (i32.sub (local.get $offset) (i32.const 28)))   ;; word_at($offset - 7 words)
        (call $sigma                                              ;; Calculate sigma1
          (i32.load (i32.sub (local.get $offset) (i32.const 8)))  ;; word_at($offset - 2 words)
          (i32.const 17)
          (i32.const 19)
          (i32.const 10)
        )
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Phase 1 of message digest calculation
  ;; * Copy the next 64 bytes of the message block to the start of the message schedule
  ;; * Populate words 16-63 of the message schedule based on the contents of the message block in words 0-15
  ;;
  ;; For testing purposes, the number of loop iterations was not hard-coded to 48 but was was parameterized so it can be
  ;; run just $n times
  (func $msg_sched_phase_1
    (param $n i32)
    (param $blk_offset i32)

    (local $offset i32)

    ;; Transfer the next 64 bytes from the message block to words 0-15 of the message schedule as raw binary
    ;; Can't use memory.copy here because the endianness needs to be swapped
    (loop $next_msg_sched_word
      (i32.store
        (i32.add (global.get $MSG_SCHED_OFFSET) (local.get $offset))
        (call $swap_endianness (i32.load (i32.add (local.get $blk_offset) (local.get $offset))))
      )

      (local.set $offset (i32.add (local.get $offset) (i32.const 4)))
      (br_if $next_msg_sched_word (i32.lt_u (local.get $offset) (i32.const 64)))
    )

    ;; Starting at word 16, populate the next $n words of the message schedule
    (local.set $offset (i32.add (global.get $MSG_SCHED_OFFSET) (i32.const 64)))

    (loop $next_pass
      (i32.store (local.get $offset) (call $gen_msg_sched_word (local.get $offset)))

      (local.set $offset (i32.add (local.get $offset) (i32.const 4)))
      (local.set $n      (i32.sub (local.get $n) (i32.const 1)))

      (br_if $next_pass (i32.gt_u (local.get $n) (i32.const 0)))
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Calculate the big sigma value of $val
  (func $big_sigma
        (param $val        i32)  ;; Raw binary value
        (param $rotr_bits1 i32)  ;; 1st rotate right value
        (param $rotr_bits2 i32)  ;; 2nd rotate right value
        (param $rotr_bits3 i32)  ;; 3rd rotate right value
        (result i32)

    (i32.xor
      (i32.xor
        (i32.rotr (local.get $val) (local.get $rotr_bits1))
        (i32.rotr (local.get $val) (local.get $rotr_bits2))
      )
      (i32.rotr (local.get $val) (local.get $rotr_bits3))
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Phase 2 of message digest calculation
  ;; * Set working variables to current hash values
  ;; * For each of the 64 words in the message schedule
  ;;   * Calculate the two temp values
  ;;   * Shunt working variables
  ;; * Update hash values with final working variable values
  ;;
  ;; For testing purposes, the number of loop iterations was not hard-coded to 64 but was was parameterized so it can be
  ;; run just $n times
  (func $msg_sched_phase_2
        (param $n i32)

    (local $idx i32)

    ;; Current hash values and their corresponding internal working variables
    (local $h0 i32) (local $h1 i32) (local $h2 i32) (local $h3 i32) (local $h4 i32) (local $h5 i32) (local $h6 i32) (local $h7 i32)
    (local $a  i32) (local $b  i32) (local $c  i32) (local $d  i32) (local $e  i32) (local $f  i32) (local $g  i32) (local $h  i32)

    (local $temp1 i32)
    (local $temp2 i32)

    ;; Remember the current hash values
    (local.set $h0 (i32.load          (global.get $HASH_VALS_OFFSET)))
    (local.set $h1 (i32.load (i32.add (global.get $HASH_VALS_OFFSET) (i32.const  4))))
    (local.set $h2 (i32.load (i32.add (global.get $HASH_VALS_OFFSET) (i32.const  8))))
    (local.set $h3 (i32.load (i32.add (global.get $HASH_VALS_OFFSET) (i32.const 12))))
    (local.set $h4 (i32.load (i32.add (global.get $HASH_VALS_OFFSET) (i32.const 16))))
    (local.set $h5 (i32.load (i32.add (global.get $HASH_VALS_OFFSET) (i32.const 20))))
    (local.set $h6 (i32.load (i32.add (global.get $HASH_VALS_OFFSET) (i32.const 24))))
    (local.set $h7 (i32.load (i32.add (global.get $HASH_VALS_OFFSET) (i32.const 28))))

    ;; Set the working variables to the current hash values
    (local.set $a (local.get $h0))
    (local.set $b (local.get $h1))
    (local.set $c (local.get $h2))
    (local.set $d (local.get $h3))
    (local.set $e (local.get $h4))
    (local.set $f (local.get $h5))
    (local.set $g (local.get $h6))
    (local.set $h (local.get $h7))

    (loop $next_update
      ;; temp1 = $h + $big_sigma1($e) + constant($idx) + msg_schedule_word($idx) + $choice($e, $f, $g)
      (local.set $temp1
        (i32.add
          (i32.add
            (i32.add
              (local.get $h)
              (call $big_sigma (local.get $e) (i32.const 6) (i32.const 11) (i32.const 25))
            )
            (i32.add
              ;; Fetch constant at word offset $idx
              (i32.load (i32.add (global.get $CONSTANTS_OFFSET) (i32.shl (local.get $idx) (i32.const 2))))
              ;; Fetch message schedule word at word offset $idx
              (i32.load (i32.add (global.get $MSG_SCHED_OFFSET) (i32.shl (local.get $idx) (i32.const 2))))
            )
          )
          ;; Choice = ($e AND $f) XOR (NOT($e) AND $G)
          (i32.xor
            (i32.and (local.get $e) (local.get $f))
            ;; WebAssembly has no bitwise NOT instruction 😱
            ;; NOT is therefore implemented as i32.xor($val, -1)
            (i32.and (i32.xor (local.get $e) (i32.const -1)) (local.get $g))
          )
        )
      )

      ;; temp2 = $big_sigma0($a) + $majority($a, $b, $c)
      (local.set $temp2
        (i32.add
          (call $big_sigma (local.get $a) (i32.const 2) (i32.const 13) (i32.const 22))
          ;; Majority = ($a AND $b) XOR ($a AND $c) XOR ($b AND $c)
          (i32.xor
            (i32.xor
              (i32.and (local.get $a) (local.get $b))
              (i32.and (local.get $a) (local.get $c))
            )
            (i32.and (local.get $b) (local.get $c))
          )
        )
      )

      ;; Shunt internal working variables
      (local.set $h (local.get $g))                                   ;; $h = $g
      (local.set $g (local.get $f))                                   ;; $g = $f
      (local.set $f (local.get $e))                                   ;; $f = $e
      (local.set $e (i32.add (local.get $d) (local.get $temp1)))      ;; $e = $d + $temp1
      (local.set $d (local.get $c))                                   ;; $d = $c
      (local.set $c (local.get $b))                                   ;; $c = $b
      (local.set $b (local.get $a))                                   ;; $b = $a
      (local.set $a (i32.add (local.get $temp1) (local.get $temp2)))  ;; $a = $temp1 + $temp2

      ;; Update index and counter
      (local.set $idx (i32.add (local.get $idx) (i32.const 1)))
      (local.set $n   (i32.sub (local.get $n)   (i32.const 1)))

      (br_if $next_update (i32.gt_u (local.get $n) (i32.const 0)))
    )

    ;; Add working variables to hash values and store back in memory
    (i32.store          (global.get $HASH_VALS_OFFSET)                 (i32.add (local.get $h0) (local.get $a)))
    (i32.store (i32.add (global.get $HASH_VALS_OFFSET) (i32.const  4)) (i32.add (local.get $h1) (local.get $b)))
    (i32.store (i32.add (global.get $HASH_VALS_OFFSET) (i32.const  8)) (i32.add (local.get $h2) (local.get $c)))
    (i32.store (i32.add (global.get $HASH_VALS_OFFSET) (i32.const 12)) (i32.add (local.get $h3) (local.get $d)))
    (i32.store (i32.add (global.get $HASH_VALS_OFFSET) (i32.const 16)) (i32.add (local.get $h4) (local.get $e)))
    (i32.store (i32.add (global.get $HASH_VALS_OFFSET) (i32.const 20)) (i32.add (local.get $h5) (local.get $f)))
    (i32.store (i32.add (global.get $HASH_VALS_OFFSET) (i32.const 24)) (i32.add (local.get $h6) (local.get $g)))
    (i32.store (i32.add (global.get $HASH_VALS_OFFSET) (i32.const 28)) (i32.add (local.get $h7) (local.get $h)))
  )

;; *********************************************************************************************************************
;; PUBLIC API
;; *********************************************************************************************************************
  (func (export "digest")
        (result i32)  ;; Pointer to the binary,32-byte SHA256 digest

    (local $blk_count   i32)
    (local $blk_offset  i32)
    (local $word_offset i32)

    (local.set $blk_offset (global.get $MSG_BLK_OFFSET))

    ;; Initialise hash values
    ;; Argument order for memory.copy is dest_offset, src_offset, length (yeah, I know, it's weird)
    (memory.copy (global.get $HASH_VALS_OFFSET) (global.get $INIT_HASH_VALS_OFFSET) (i32.const 32))

    ;; Process file in 64-byte blocks
    (loop $next_msg_blk
      (call $msg_sched_phase_1 (i32.const 48) (local.get $blk_offset))
      (call $msg_sched_phase_2 (i32.const 64))

      (local.set $blk_offset (i32.add (local.get $blk_offset) (i32.const 64)))
      (local.set $blk_count  (i32.add (local.get $blk_count)  (i32.const 1)))

      (br_if $next_msg_blk (i32.lt_u (local.get $blk_count) (global.get $MSG_BLK_COUNT)))
    )

    ;; Return offset of hash values
    (global.get $HASH_VALS_OFFSET)
  )
)
