(module
  ;; Page 1: 0x00000100 - 0x0000011F  Constants - fractional part of square root of first 8 primes
  ;;         0x00000120 - 0x0000021F  Constants - fractional part of cube root of first 64 primes
  ;;         0x00000220 - 0x0000023F  8 * i32 Hash values
  ;;         0x00000240 - 0x0000043F  512 byte message digest
  ;; Page 2: 0x00010000 - 0x00...     Start of file data
  (memory $memory (export "memory") 2)

  (global $INIT_HASH_VALS_PTR i32 (i32.const 0x00000100))
  (global $CONSTANTS_PTR      i32 (i32.const 0x00000120))
  (global $HASH_VALS_PTR      i32 (i32.const 0x00000220))
  (global $MSG_DIGEST_PTR     i32 (i32.const 0x00000240))
  (global $MSG_BLK_PTR        i32 (i32.const 0x00010000))

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; The first 32 bits of the fractional parts of the square roots of the first 8 primes 2..19
  ;; Used to initialise the hash values
  ;; Values below are in little-endian byte order!
  (data (i32.const 0x000100)    ;; $INIT_HASH_VALS_PTR
    ;; 0x00000100
    "\67\E6\09\6A" "\85\AE\67\BB" "\72\F3\6E\3C" "\3A\F5\4F\A5"
    ;; 0x00000110
    "\7F\52\0E\51" "\8C\68\05\9B" "\AB\D9\83\1F" "\19\CD\E0\5B"
  )

  ;; The first 32 bits of the fractional parts of the cube roots of the first 64 primes 2..311
  ;; Used in phase 2 (hash value calculation)
  ;; Values below are in little-endian byte order!
  (data (i32.const 0x000120)    ;; $CONSTANTS_PTR
    ;; 0x00000120
    "\98\2F\8A\42" "\91\44\37\71" "\CF\FB\C0\B5" "\A5\DB\B5\E9"
    ;; 0x00000130
    "\5B\C2\56\39" "\F1\11\F1\59" "\A4\82\3F\92" "\D5\5E\1C\AB"
    ;; 0x00000140
    "\98\AA\07\D8" "\01\5B\83\12" "\BE\85\31\24" "\C3\7D\0C\55"
    ;; 0x00000150
    "\74\5D\BE\72" "\FE\B1\DE\80" "\A7\06\DC\9B" "\74\F1\9B\C1"
    ;; 0x00000160
    "\C1\69\9B\E4" "\86\47\BE\EF" "\C6\9D\C1\0F" "\CC\A1\0C\24"
    ;; 0x00000170
    "\6F\2C\E9\2D" "\AA\84\74\4A" "\DC\A9\B0\5C" "\DA\88\F9\76"
    ;; 0x00000180
    "\52\51\3E\98" "\6D\C6\31\A8" "\C8\27\03\B0" "\C7\7F\59\BF"
    ;; 0x00000190
    "\F3\0B\E0\C6" "\47\91\A7\D5" "\51\63\CA\06" "\67\29\29\14"
    ;; 0x000001A0
    "\85\0A\B7\27" "\38\21\1B\2E" "\FC\6D\2C\4D" "\13\0D\38\53"
    ;; 0x000001B0
    "\54\73\0A\65" "\BB\0A\6A\76" "\2E\C9\C2\81" "\85\2C\72\92"
    ;; 0x000001C0
    "\A1\E8\BF\A2" "\4B\66\1A\A8" "\70\8B\4B\C2" "\A3\51\6C\C7"
    ;; 0x000001D0
    "\19\E8\92\D1" "\24\06\99\D6" "\85\35\0E\F4" "\70\A0\6A\10"
    ;; 0x000001E0
    "\16\C1\A4\19" "\08\6C\37\1E" "\4C\77\48\27" "\B5\BC\B0\34"
    ;; 0x000001F0
    "\B3\0C\1C\39" "\4A\AA\D8\4E" "\4F\CA\9C\5B" "\F3\6F\2E\68"
    ;; 0x00000200
    "\EE\82\8F\74" "\6F\63\A5\78" "\14\78\C8\84" "\08\02\C7\8C"
    ;; 0x00000210
    "\FA\FF\BE\90" "\EB\6C\50\A4" "\F7\A3\F9\BE" "\F2\78\71\C6"
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Generic sigma value of argument $val
  ;; sigma = rotr($w2, $rotr1)  XOR rotr($w2, $rotr2) XOR shr_u($w2, $shr)
  (func $sigma
        (param $val   i32)  ;; Raw binary value
        (param $rotr1 i32)  ;; ROTR twiddle factor 1
        (param $rotr2 i32)  ;; ROTR twiddle factor 2
        (param $shr   i32)  ;; SHR twiddle factor
        (result i32)

    (i32.xor
      (i32.xor
        (i32.rotr (local.get $val) (local.get $rotr1))
        (i32.rotr (local.get $val) (local.get $rotr2))
      )
      (i32.shr_u (local.get $val) (local.get $shr))
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Calculate the message digest word at byte offset $ptr using the four words found at the earlier offsets.
  ;; All data must be treated as raw binary:
  ;;
  ;; $w1 = word_at($ptr - (4 * 16))
  ;; $w2 = word_at($ptr - (4 * 15))
  ;; $w3 = word_at($ptr - (4 * 7))
  ;; $w4 = word_at($ptr - (4 * 2))
  ;;
  ;; result = $w1 + $sigma($w2, 7, 8, 13) + $w3 + $sigma($w4, 17, 19, 10)
  (func $gen_msg_digest_word
        (param $ptr i32)
        (result i32)

    (i32.add
      (i32.add
        (i32.load (i32.sub (local.get $ptr) (i32.const 64)))    ;; word_at($ptr - 16 words)
        (call $sigma                                            ;; Calculate sigma0
          (i32.load (i32.sub (local.get $ptr) (i32.const 60)))  ;; word_at($ptr - 15 words)
          (i32.const 7)                                         ;; ROTR twiddle factor 1
          (i32.const 18)                                        ;; ROTR twiddle factor 2
          (i32.const 3)                                         ;; SHR twiddle factor
        )
      )
      (i32.add
        (i32.load (i32.sub (local.get $ptr) (i32.const 28)))   ;; word_at($ptr - 7 words)
        (call $sigma                                           ;; Calculate sigma1
          (i32.load (i32.sub (local.get $ptr) (i32.const 8)))  ;; word_at($ptr - 2 words)
          (i32.const 17)                                       ;; ROTR twiddle factor 1
          (i32.const 19)                                       ;; ROTR twiddle factor 2
          (i32.const 10)                                       ;; SHR twiddle factor
        )
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Calculate the big sigma value of argument $val
  (func $big_sigma
        (param $val   i32)  ;; Raw binary value
        (param $rotr1 i32)  ;; ROTR twiddle factor 1
        (param $rotr2 i32)  ;; ROTR twiddle factor 2
        (param $rotr3 i32)  ;; ROTR twiddle factor 3
        (result i32)

    (i32.xor
      (i32.xor
        (i32.rotr (local.get $val) (local.get $rotr1))
        (i32.rotr (local.get $val) (local.get $rotr2))
      )
      (i32.rotr (local.get $val) (local.get $rotr3))
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Phase 1: Create message digest
  ;; * Populate words 0..15 of the message digest using the next 64 bytes of the message block
  ;; * Populate words 16..63 of the message digest based on words 0..15
  ;;
  ;; For testing purposes, the number of loop iterations was not hard-coded to 48 but was was parameterized so it can be
  ;; run just $n times
  (func $phase_1
    (param $n           i32)
    (param $blk_ptr     i32)
    (param $msg_blk_ptr i32)

    (local $ptr i32)

    ;; Transfer the next 64 bytes from the message block to words 0..15 of the message digest as raw binary.
    (loop $next_msg_sched_vec
      (v128.store
        (i32.add (local.get $msg_blk_ptr) (local.get $ptr))
        ;; Use swizzle to swap big-endian byte order to little-endian
        (i8x16.swizzle
          (v128.load (i32.add (local.get $blk_ptr) (local.get $ptr)))  ;; 4 words of raw binary in network byte order
          (v128.const i8x16 3 2 1 0 7 6 5 4 11 10 9 8 15 14 13 12)     ;; Rearrange bytes into this order of indices
        )
      )

      (local.set $ptr (i32.add (local.get $ptr) (i32.const 16)))
      (br_if $next_msg_sched_vec (i32.lt_u (local.get $ptr) (i32.const 64)))
    )

    ;; Starting at word 16, populate the next $n words of the message digest
    (local.set $ptr (i32.add (global.get $MSG_DIGEST_PTR) (i32.const 64)))

    (loop $next_pass
      (i32.store (local.get $ptr) (call $gen_msg_digest_word (local.get $ptr)))

      (local.set $ptr (i32.add (local.get $ptr) (i32.const 4)))
      (local.set $n   (i32.sub (local.get $n)   (i32.const 1)))

      (br_if $next_pass (i32.gt_u (local.get $n) (i32.const 0)))
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Phase 2: Process message digest to obtain new hash values
  ;; * Set working variables to current hash values
  ;; * For each of the 64 words in the message digest
  ;;   * Calculate the two temp values
  ;;   * Shunt working variables
  ;; * Add working variable values to corresponding hash values
  ;;
  ;; For testing purposes, the number of loop iterations was not hard-coded to 64 but was was parameterized so it can be
  ;; run just $n times
  (func $phase_2
        (param $n i32)

    (local $idx i32)

    ;; Current hash values and their corresponding internal working variables
    (local $h0 i32) (local $h1 i32) (local $h2 i32) (local $h3 i32) (local $h4 i32) (local $h5 i32) (local $h6 i32) (local $h7 i32)
    (local $a  i32) (local $b  i32) (local $c  i32) (local $d  i32) (local $e  i32) (local $f  i32) (local $g  i32) (local $h  i32)

    (local $temp1 i32)
    (local $temp2 i32)

    ;; Remember the current hash values
    (local.set $h0 (i32.load          (global.get $HASH_VALS_PTR)))
    (local.set $h1 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const  4))))
    (local.set $h2 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const  8))))
    (local.set $h3 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const 12))))
    (local.set $h4 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const 16))))
    (local.set $h5 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const 20))))
    (local.set $h6 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const 24))))
    (local.set $h7 (i32.load (i32.add (global.get $HASH_VALS_PTR) (i32.const 28))))

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
              (i32.load (i32.add (global.get $CONSTANTS_PTR) (i32.shl (local.get $idx) (i32.const 2))))
              ;; Fetch message digest word at word offset $idx
              (i32.load (i32.add (global.get $MSG_DIGEST_PTR) (i32.shl (local.get $idx) (i32.const 2))))
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

    ;; Add working variables to hash values and store back in memory - don't care if addition results in overflow
    (i32.store          (global.get $HASH_VALS_PTR)                 (i32.add (local.get $h0) (local.get $a)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const  4)) (i32.add (local.get $h1) (local.get $b)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const  8)) (i32.add (local.get $h2) (local.get $c)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const 12)) (i32.add (local.get $h3) (local.get $d)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const 16)) (i32.add (local.get $h4) (local.get $e)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const 20)) (i32.add (local.get $h5) (local.get $f)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const 24)) (i32.add (local.get $h6) (local.get $g)))
    (i32.store (i32.add (global.get $HASH_VALS_PTR) (i32.const 28)) (i32.add (local.get $h7) (local.get $h)))
  )

;; *********************************************************************************************************************
;; PUBLIC API
;; *********************************************************************************************************************
  (func (export "sha256_hash")
        (param $msg_blk_count i32)  ;; Number of message blocks
        (result i32)                ;; The SHA256 digest is the concatenation of the 8, i32s starting at this location

    (local $blk_count i32)
    (local $blk_ptr   i32)

    (local.set $blk_ptr (global.get $MSG_BLK_PTR))

    ;; Initialise hash values
    ;; Argument order for memory.copy is dest_ptr, src_ptr, length (yeah, I know, it's weird)
    (memory.copy (global.get $HASH_VALS_PTR) (global.get $INIT_HASH_VALS_PTR) (i32.const 32))

    ;; Process file in 64-byte blocks
    (loop $next_msg_blk
      (call $phase_1 (i32.const 48) (local.get $blk_ptr) (global.get $MSG_DIGEST_PTR))
      (call $phase_2 (i32.const 64))

      (local.set $blk_ptr   (i32.add (local.get $blk_ptr)   (i32.const 64)))
      (local.set $blk_count (i32.add (local.get $blk_count) (i32.const 1)))

      (br_if $next_msg_blk (i32.lt_u (local.get $blk_count) (local.get $msg_blk_count)))
    )

    ;; Return offset of hash values
    (global.get $HASH_VALS_PTR)
  )
)
