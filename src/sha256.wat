(;
************************************************************************************************************************
CAUTION!

The binary data for which we are calculating the SHA256 digest appears in memory as an undifferentiated stream of bits.

Since WebAssembly only has numeric data types, the i32.load and i32.store instructions will automatically apply the
CPU's endianness to any data transfered to and from memory.

Since this program will (almost certainly) be run on a little-endian CPU, the i32.load and i32.store instructions will
assume that the data in memory has been stored in little-endian byte order (which it hasn't), and helpfully reverse the
byte order...

:-(

In short, the WebAssembly instructions i32.load and i32.store must not be used directly.  Instead, they must be wrapped
by functions that swap the endianness after loading and swap it back before storing.

Failure to account for this byte order reversal will cause the SHA256 algorithm to generate nonsense.

Data in memory : Big-endian
Data on stack  : Little-endian
************************************************************************************************************************
;)
(module
  (import "log" "i32"
    (func $log_i32
          (param i32)  ;; Message id
          (param i32)  ;; i32 value
    )
  )
  (import "log" "checkTest"
    (func $check_test
          (param i32)  ;; Test id
          (param i32)  ;; Arg 1 - Got value
          (param i32)  ;; Arg 0 - Expected value
    )
  )

  (import "memory" "pages" (memory 2)
    ;; Page 1: 0x000000 - 0x00FFFF  Message Block + Message Schedule
    ;; Page 2: 0x010000 - 0x01001F  Constants - fractional part of square root of first 8 primes
    ;;         0x010020 - 0x01011F  Constants - fractional part of cube root of first 64 primes
    ;;         0x010120 - 0x01013F  Hash values used during hash generation
    ;;         0x010140 - 0x01015F  Working values used during hash generation
    ;;         0x010160 - 0x01017F  Final message digest
    ;;         0x010200 - 0x01027F  Test Data
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Where stuff lives in memory
  (global $MSG_SCHED_OFFSET      i32 (i32.const 0x000000))
  (global $INIT_HASH_VALS_OFFSET i32 (i32.const 0x010000))
  (global $CONSTANTS_OFFSET      i32 (i32.const 0x010020))
  (global $HASH_VALS_OFFSET      i32 (i32.const 0x010120))
  (global $WORKING_VARS_OFFSET   i32 (i32.const 0x010140))
  (global $DIGEST_OFFSET         i32 (i32.const 0x010160))
  (global $TEST_DATA_OFFSET      i32 (i32.const 0x010200))

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Initial hash values are the first 32 bits of the fractional parts of the square roots of the first 8 primes 2..19
  (data (i32.const 0x010000)
    "\6A\09\E6\67"  ;; 0x010000
    "\BB\67\AE\85"
    "\3C\6E\F3\72"
    "\A5\4F\F5\3A"
    "\51\0E\52\7F"  ;; 0x010010
    "\9B\05\68\8C"
    "\1F\83\D9\AB"
    "\5B\E0\CD\19"
  )

  ;; Constants are the first 32 bits of the fractional parts of the cube roots of the first 64 primes 2..311
  (data (i32.const 0x010020)
    "\42\8A\2F\98"  ;; 0x010020
    "\71\37\44\91"
    "\B5\C0\FB\CF"
    "\E9\B5\DB\A5"
    "\39\56\C2\5B"  ;; 0x010030
    "\59\F1\11\F1"
    "\92\3F\82\A4"
    "\AB\1C\5E\D5"
    "\D8\07\AA\98"  ;; 0x010040
    "\12\83\5B\01"
    "\24\31\85\BE"
    "\55\0C\7D\C3"
    "\72\BE\5D\74"  ;; 0x010050
    "\80\DE\B1\FE"
    "\9B\DC\06\A7"
    "\C1\9B\F1\74"
    "\E4\9B\69\C1"  ;; 0x010060
    "\EF\BE\47\86"
    "\0F\C1\9D\C6"
    "\24\0C\A1\CC"
    "\2D\E9\2C\6F"  ;; 0x010070
    "\4A\74\84\AA"
    "\5C\B0\A9\DC"
    "\76\F9\88\DA"
    "\98\3E\51\52"  ;; 0x010080
    "\A8\31\C6\6D"
    "\B0\03\27\C8"
    "\BF\59\7F\C7"
    "\C6\E0\0B\F3"  ;; 0x010090
    "\D5\A7\91\47"
    "\06\CA\63\51"
    "\14\29\29\67"
    "\27\B7\0A\85"  ;; 0x0100A0
    "\2E\1B\21\38"
    "\4D\2C\6D\FC"
    "\53\38\0D\13"
    "\65\0A\73\54"  ;; 0x0100B0
    "\76\6A\0A\BB"
    "\81\C2\C9\2E"
    "\92\72\2C\85"
    "\A2\BF\E8\A1"  ;; 0x0100C0
    "\A8\1A\66\4B"
    "\C2\4B\8B\70"
    "\C7\6C\51\A3"
    "\D1\92\E8\19"  ;; 0x0100D0
    "\D6\99\06\24"
    "\F4\0E\35\85"
    "\10\6A\A0\70"
    "\19\A4\C1\16"  ;; 0x0100E0
    "\1E\37\6C\08"
    "\27\48\77\4C"
    "\34\B0\BC\B5"
    "\39\1C\0C\B3"  ;; 0x0100F0
    "\4E\D8\AA\4A"
    "\5B\9C\CA\4F"
    "\68\2E\6F\F3"
    "\74\8F\82\EE"  ;; 0x010100
    "\78\A5\63\6F"
    "\84\C8\78\14"
    "\8C\C7\02\08"
    "\90\BE\FF\FA"  ;; 0x010110
    "\A4\50\6C\EB"
    "\BE\F9\A3\F7"
    "\C6\71\78\F2"
  )

  ;; Hash values updated after each 512-byte messsage schedule is calculated
  (data (i32.const 0x010120)
    "\00\00\00\00"  ;; 0x010120
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"  ;; 0x010130
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"
  )

  ;; Working values used when processing a 512-byte message schedule block
  (data (i32.const 0x010140)
    "\00\00\00\00"  ;; 0x010140
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"  ;; 0x010150
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"
  )

  ;; Final message digest appears here
  (data (i32.const 0x010160)
    "\00\00\00\00"  ;; 0x0010160
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"  ;; 0x0010170
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Set up test data
  ;; * Populate the first 512 bits of the message schedule with "ABCD" followed by a binary 1, terminated with the bit
  ;;   length of the data as an i64.
  ;; * Initialise hash values
  ;; * Initialise working variables used by function $update_hash_vals
  (func $populate_test_data
    (local $n i32)
    (local.set $n (i32.const 8))

    ;; Words 0 and 1 contain 0x41424344 and 0x80000000 respectively
    (call $i32_swap_store          (global.get $MSG_SCHED_OFFSET)                (i32.const 0x41424344))
    (call $i32_swap_store (i32.add (global.get $MSG_SCHED_OFFSET) (i32.const 4)) (i32.const 0x80000000))

    ;; Words 2 to 14 are empty
    (loop $next_word
      (call $i32_swap_store
        (i32.add (global.get $MSG_SCHED_OFFSET) (local.get $n))
        (i32.const 0x00000000)
      )

      (local.set $n (i32.add (local.get $n) (i32.const 4)))
      (br_if $next_word (i32.le_u (local.get $n) (i32.const 56)))
    )

    ;; w15 contains 0x00000020 (bit length = 16)
    (call $i32_swap_store (i32.add (global.get $MSG_SCHED_OFFSET) (i32.const 60)) (i32.const 0x00000020))

    ;; Initialise hash values and working variables
    (call $write_i32_values (i32.const 8) (global.get $INIT_HASH_VALS_OFFSET) (global.get $HASH_VALS_OFFSET))
    (call $write_i32_values (i32.const 8) (global.get $HASH_VALS_OFFSET)      (global.get $WORKING_VARS_OFFSET))
  )

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

  (func (export "test_swap_endianness")
    (call $check_test
      (i32.const 4)
      (call $swap_endianness (i32.const 0xDEADBEEF))
      (i32.const 0xEFBEADDE)
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Return the 32-bit word at byte offset $offset preserving the big-endian byte order
  (func $i32_load_swap
        (param $offset i32)
        (result i32)
    (call $swap_endianness (i32.load (local.get $offset)))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Transform $little_endian_i32 to big-endian byte order and store at byte offset $offset
  (func $i32_swap_store
        (param $offset i32)
        (param $little_endian_i32 i32)
    (i32.store (local.get $offset) (call $swap_endianness (local.get $little_endian_i32)))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Write the $n i32 values at byte offset $src to byte offset $dest
  ;; The memory blocks at offsets $src and $dest must be contiguous
  (func $write_i32_values
        (param $n    i32)
        (param $src  i32)
        (param $dest i32)

    (loop $next_hash_value
      (i32.store (local.get $dest) (i32.load (local.get $src)))

      (local.set $n    (i32.sub (local.get $n)    (i32.const 1)))
      (local.set $src  (i32.add (local.get $src)  (i32.const 4)))
      (local.set $dest (i32.add (local.get $dest) (i32.const 4)))

      ;; Test for continuation
      (br_if $next_hash_value (i32.gt_u (local.get $n) (i32.const 0)))
    )
  )

  (func (export "test_initialise_hash_values")
    (call $write_i32_values (i32.const 8) (global.get $INIT_HASH_VALS_OFFSET) (global.get $HASH_VALS_OFFSET))
    (call $check_test
      (i32.const 0)
      (global.get $INIT_HASH_VALS_OFFSET)
      (global.get $HASH_VALS_OFFSET)
    )
  )

  (func (export "test_initialise_working_variables")
    (call $write_i32_values (i32.const 8) (global.get $INIT_HASH_VALS_OFFSET) (global.get $HASH_VALS_OFFSET))
    (call $write_i32_values (i32.const 8) (global.get $HASH_VALS_OFFSET)      (global.get $WORKING_VARS_OFFSET))
    (call $check_test
      (i32.const 1)
      (global.get $HASH_VALS_OFFSET)
      (global.get $WORKING_VARS_OFFSET)
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Fetch constant value
  (func $fetch_constant_value
        (param $idx i32)  ;; Index of constant to be fetched in the range 0..63
        (result i32)
    (call $i32_load_swap (i32.add (global.get $CONSTANTS_OFFSET) (i32.shl (local.get $idx) (i32.const 2))))
  )

  (func (export "test_fetch_constant_value")
        (param $idx i32)
    (call $check_test
      (i32.add (i32.const 400) (local.get $idx))    ;; Test id = 400 + $idx
      (call $fetch_constant_value (local.get $idx))
      (local.get $idx)
    )
  )

  ;; Fetch message schedule value
  (func $fetch_msg_sched_word
        (param $idx i32)  ;; Index of msg sched word to be fetched in the range 0..63
        (result i32)
    (call $i32_load_swap (i32.add (global.get $MSG_SCHED_OFFSET) (i32.shl (local.get $idx) (i32.const 2))))
  )

  ;; Fetch working value
  (func $fetch_working_value
        (param $idx i32)  ;; Index of working value to be fetched in the range 0..7
        (result i32)
    (call $i32_load_swap (i32.add (global.get $WORKING_VARS_OFFSET) (i32.shl (local.get $idx) (i32.const 2))))
  )

  (func (export "test_fetch_working_variable")
    (call $check_test
      (i32.const 2)
      (call $fetch_working_value (i32.const 0))
      (i32.const 0x6A09E667)
    )
  )

  ;; Set working value
  (func $set_working_value
        (param $idx i32)  ;; Index of working value to be set in the range 0..7
        (param $val i32)  ;; New value
    (i32.store
      (i32.add (global.get $WORKING_VARS_OFFSET) (i32.shl (local.get $idx) (i32.const 2)))
      (local.get $val)
    )
  )

  (func (export "test_set_working_variable")
    (call $set_working_value (i32.const 0) (i32.const 0xDEADBEEF))

    (call $check_test
      (i32.const 3)
      (call $fetch_working_value (i32.const 0))
      (i32.const 0xEFBEADDE)
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Calculate the sigma value of the 32-bit word found at byte offset $offset
  (func $sigma
        (param $offset i32)
        (param $rotr_bits1 i32)  ;; 1st rotate right value
        (param $rotr_bits2 i32)  ;; 2nd rotate right value
        (param $shftr_bits i32)  ;; Shift right value
        (result i32)

    (local $big_endian_i32 i32)
    (local.set $big_endian_i32 (call $i32_load_swap (local.get $offset)))

    (i32.xor
      (i32.xor
        (i32.rotr (local.get $big_endian_i32) (local.get $rotr_bits1))
        (i32.rotr (local.get $big_endian_i32) (local.get $rotr_bits2))
      )
      (i32.shr_u (local.get $big_endian_i32) (local.get $shftr_bits))
    )
  )

  ;; Calculate sigma0 of the 32-bit word found at byte offset $offset
  (func $sigma0
        (param $offset i32)
        (result i32)

    (call $sigma (local.get $offset) (i32.const 7) (i32.const 18) (i32.const 3))
  )

  (func (export "test_sigma0")
    (call $i32_swap_store (global.get $TEST_DATA_OFFSET) (i32.const 0x52426344))
    (call $check_test
      (i32.const 5)
      (call $sigma0 (global.get $TEST_DATA_OFFSET))
      (i32.const 0x1A3DDC3E)
    )
  )

  ;; Calculate sigma1 of the 32-bit word found at byte offset $offset
  (func $sigma1
        (export "sigma1")
        (param $offset i32)
        (result i32)

    (call $sigma (local.get $offset) (i32.const 17) (i32.const 19) (i32.const 10))
  )

  (func (export "test_sigma1")
    (call $i32_swap_store (global.get $TEST_DATA_OFFSET) (i32.const 0xA36D00CA))
    (call $check_test
      (i32.const 6)
      (call $sigma1 (global.get $TEST_DATA_OFFSET))
      (i32.const 0x2054DE9B)
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Calculate the big sigma value of $val
  ;; $val must be in big-endian format
  (func $big_sigma
        (param $val i32)
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

  ;; Calculate big_sigma0 of $val
  (func $big_sigma0
        (param $val i32)
        (result i32)

    (call $big_sigma (local.get $val) (i32.const 2) (i32.const 13) (i32.const 22))
  )

  (func (export "test_big_sigma0")
    (call $check_test
      (i32.const 7)
      (call $big_sigma0 (i32.const 0x6A09E667))
      (i32.const 0xCE20B47E)
    )
  )

  ;; Calculate big_sigma1 of $val
  (func $big_sigma1
        (param $val i32)
        (result i32)

    (call $big_sigma (local.get $val) (i32.const 6) (i32.const 11) (i32.const 25))
  )

  (func (export "test_big_sigma1")
    (call $check_test
      (i32.const 8)
      (call $big_sigma1 (i32.const 0x510E527F))
      (i32.const 0x3587272B)
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; The value of the 32-bit word found at byte offset $offset is calculated using the four, 32-bit words found at the
  ;; following earlier offsets:
  ;;
  ;; $w1 = word_at($offset - (4 * 16))
  ;; $w2 = word_at($offset - (4 * 15))
  ;; $w3 = word_at($offset - (4 * 7))
  ;; $w4 = word_at($offset - (4 * 2))
  ;;
  ;; sigma0 = rotr($w2, 7)  XOR rotr($w2, 18) XOR shr_u($w2, 3)
  ;; sigma1 = rotr($w4, 17) XOR rotr($w4, 19) XOR shr_u($w4, 10)
  ;;
  ;; result = $w1 + $sigma0 + $w3 + $sigma1
  (func $gen_msg_sched_word
        (param $offset i32)
        (result i32)

    (i32.add
      (i32.add
        (call $i32_load_swap (i32.sub (local.get $offset) (i32.const 64))) ;; $offset - 16 words
        (call $sigma0        (i32.sub (local.get $offset) (i32.const 60))) ;; $offset - 15 words
      )
      (i32.add
        (call $i32_load_swap (i32.sub (local.get $offset) (i32.const 28))) ;; $offset - 7 words
        (call $sigma1        (i32.sub (local.get $offset) (i32.const 8)))  ;; $offset - 2 words
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Run $n passes of the message schedule calculation
  (func $run_msg_sched_passes
    (param $n i32)

    ;; First message schedule word starts at offset 64 (word 16)
    (local $offset i32)
    (local.set $offset (i32.add (global.get $MSG_SCHED_OFFSET) (i32.const 64)))

    (loop $next_pass
      (call $i32_swap_store (local.get $offset) (call $gen_msg_sched_word (local.get $offset)))
      (local.set $offset (i32.add (local.get $offset) (i32.const 4)))
      (local.set $n (i32.sub (local.get $n) (i32.const 1)))
      (br_if $next_pass (i32.gt_u (local.get $n) (i32.const 0)))
    )
  )

  ;; Run $n passes of the message schedule calculation against the test data
  (func (export "test_gen_msg_sched")
        (param $n i32)

    (call $populate_test_data)
    (call $run_msg_sched_passes (local.get $n))

    ;; Check nth word of the message schedule
    (call $check_test
      (i32.add (local.get $n) (i32.const 100))  ;; Test id = number of passes + 100
      (call $i32_load_swap
        ;; The word created by $n message schedule passes lives at offset $MSG_SCHED_OFFSET + 60 + ($n * 4)
        (i32.add
          (global.get $MSG_SCHED_OFFSET)
          (i32.add
            (i32.const 60)
            (i32.shl (local.get $n) (i32.const 2))
          )
        )
      )
      ;; Index of nth word in expected message schedule
      ;; This data lives in the JavaScript test module
      (i32.sub (local.get $n) (i32.const 1))
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; $choice = (e AND f) XOR (NOT(e) AND g)
  (func $choice
        (param $e i32)
        (param $f i32)
        (param $g i32)
        (result i32)
    (i32.xor
      (i32.and (local.get $e) (local.get $f))
      ;; Since WebAssembly has no bitwise NOT instruction, NOT must be implemented as i32.xor($val, -1)
      (i32.and (i32.xor (local.get $e) (i32.const -1)) (local.get $g))
    )
  )

  (func (export "test_choice")
    (call $check_test
      (i32.const 200)
      (call $choice
        (i32.const 0x510E527F)  ;; $e
        (i32.const 0x9B05688C)  ;; $f
        (i32.const 0x1F83D9AB)  ;; $g
      )
      (i32.const 0x1F85C98C)
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; majority = (a AND b) XOR (a AND c) XOR (b AND c)
  (func $majority
        (param $a i32)
        (param $b i32)
        (param $c i32)
        (result i32)
    (i32.xor
      (i32.xor
        (i32.and (local.get $a) (local.get $b))
        (i32.and (local.get $a) (local.get $c))
      )
      (i32.and (local.get $b) (local.get $c))
    )
  )

  (func (export "test_majority")
    (call $check_test
      (i32.const 202)
      (call $majority (i32.const 0x6A09E667) (i32.const 0xBB67AE85) (i32.const 0x3C6EF372))
      (i32.const 0x3A6FE667)
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Perform $n updates to the working variables
  ;; Called 64 times during digest generation: once for each of the 32-bit words in the 512-byte message schedule
  (func $update_working_vars
        (param $n i32)

    (local $idx i32)

    (local $a i32)
    (local $b i32)
    (local $c i32)
    (local $d i32)
    (local $e i32)
    (local $f i32)
    (local $g i32)
    (local $h i32)

    (local $w i32)
    (local $k i32)

    (local $sig0 i32)
    (local $sig1 i32)

    (local $maj i32)
    (local $ch i32)

    (local $temp1 i32)
    (local $temp2 i32)

    (loop $next_update
      (local.set $a (call $fetch_working_value (i32.const 0)))
      (local.set $b (call $fetch_working_value (i32.const 1)))
      (local.set $c (call $fetch_working_value (i32.const 2)))
      (local.set $d (call $fetch_working_value (i32.const 3)))
      (local.set $e (call $fetch_working_value (i32.const 4)))
      (local.set $f (call $fetch_working_value (i32.const 5)))
      (local.set $g (call $fetch_working_value (i32.const 6)))
      (local.set $h (call $fetch_working_value (i32.const 7)))

      (local.set $sig0 (call $big_sigma0 (local.get $a)))
      (local.set $sig1 (call $big_sigma1 (local.get $e)))

      (local.set $maj (call $majority (local.get $a) (local.get $b) (local.get $c)))
      (local.set $ch  (call $choice (local.get $e) (local.get $f) (local.get $g)))

      (local.set $w (call $fetch_msg_sched_word (local.get $idx)))
      (local.set $k (call $fetch_constant_value (local.get $idx)))

      ;; temp1 = $h + $big_sigma1($e) + constant($idx) + msg_schedule_word($idx) + $choice($e, $f, $g)
      (local.set $temp1
        (i32.add
          (i32.add
            (i32.add (local.get $h) (local.get $sig1))
            (i32.add (local.get $k) (local.get $w))
          )
          (local.get $ch)
        )
      )

      ;; temp2 = $big_sigma0($a) + $majority($a, $b, $c)
      (local.set $temp2 (i32.add (local.get $sig0) (local.get $maj)))

      ;; (call $log_i32 (i32.const 0) (local.get $a))
      ;; (call $log_i32 (i32.const 1) (local.get $b))
      ;; (call $log_i32 (i32.const 2) (local.get $c))
      ;; (call $log_i32 (i32.const 3) (local.get $d))
      ;; (call $log_i32 (i32.const 4) (local.get $e))
      ;; (call $log_i32 (i32.const 5) (local.get $f))
      ;; (call $log_i32 (i32.const 6) (local.get $g))
      ;; (call $log_i32 (i32.const 7) (local.get $h))

      ;; (call $log_i32 (i32.const 4) (local.get $e))
      ;; (call $log_i32 (i32.const 9) (local.get $sig1))
      ;; (call $log_i32 (i32.const 10) (local.get $ch))
      ;; (call $log_i32 (i32.add (local.get $idx) (i32.const 400)) (local.get $k))
      ;; (call $log_i32 (i32.add (local.get $idx) (i32.const 500)) (local.get $w))
      ;; (call $log_i32 (i32.const 14) (local.get $temp1))

      ;; (call $log_i32 (i32.const 11) (local.get $maj))
      ;; (call $log_i32 (i32.const 8)  (local.get $sig0))
      ;; (call $log_i32 (i32.const 15) (local.get $temp2))

      ;; (call $log_i32 (i32.const 20) (i32.add (local.get $d) (local.get $temp1)))
      ;; (call $log_i32 (i32.const 21) (i32.add (local.get $temp1) (local.get $temp2)))

      (call $set_working_value (i32.const 7) (local.get $g))  ;; $h = $g
      (call $set_working_value (i32.const 6) (local.get $f))  ;; $g = $f
      (call $set_working_value (i32.const 5) (local.get $e))  ;; $f = $e
      (call $set_working_value (i32.const 4)
        (i32.add (local.get $d) (local.get $temp1))           ;; $e = $d + $temp1
      )
      (call $set_working_value (i32.const 3) (local.get $c))  ;; $d = $c
      (call $set_working_value (i32.const 2) (local.get $b))  ;; $c = $b
      (call $set_working_value (i32.const 1) (local.get $a))  ;; $b = $a
      (call $set_working_value (i32.const 0)
        (i32.add (local.get $temp1) (local.get $temp2))       ;; $a = $temp1 + $temp2
      )

      (local.set $idx (i32.add (local.get $idx) (i32.const 1)))
      (local.set $n   (i32.sub (local.get $n)   (i32.const 1)))
      (br_if $next_update (i32.gt_u (local.get $n) (i32.const 0)))
    )
  )

  (func (export "test_update_working_vars")
        (param $n i32)
    (call $populate_test_data)

    ;; Generate the full message schedule against the test data
    (call $run_msg_sched_passes (i32.const 48))

    ;; Run update the working vars $n times
    (call $update_working_vars (local.get $n))

    (call $check_test
      (i32.add (i32.const 300) (local.get $n))  ;; 300 < test ids < 400
      (global.get $WORKING_VARS_OFFSET)
      (local.get $n)  ;; Index into expected values array held in the JavaScript test environment
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Update hash values
  ;; Called after each 512-byte message schedule is processed
  (func $update_hash_vals
        (export "update_hash_vals")

    (local $idx i32)
    (local $w_vars_offset i32)
    (local $hash_offset i32)

    (local.set $w_vars_offset (global.get $WORKING_VARS_OFFSET))
    (local.set $hash_offset (global.get $HASH_VALS_OFFSET))

    (loop $next_hash_val
      (i32.store
        (local.get $hash_offset)
        (i32.add (i32.load (local.get $w_vars_offset)) (i32.load (local.get $hash_offset)))
      )

      (local.set $idx           (i32.add (local.get $idx)           (i32.const 1)))
      (local.set $w_vars_offset (i32.add (local.get $w_vars_offset) (i32.const 4)))
      (local.set $hash_offset   (i32.add (local.get $hash_offset)   (i32.const 4)))

      ;; Test for continuation
      (br_if $next_hash_val (i32.lt_u (local.get $idx) (i32.const 8)))
    )
  )

  (;********************************************************************************************************************
    PUBLIC API
    ********************************************************************************************************************
  ;)
  (func (export "digest")
        (result i32)  ;; Pointer to the SHA256 digest
    (call $write_i32_values (i32.const 8) (global.get $INIT_HASH_VALS_OFFSET) (global.get $HASH_VALS_OFFSET))
    (call $write_i32_values (i32.const 8) (global.get $HASH_VALS_OFFSET)      (global.get $WORKING_VARS_OFFSET))

    (call $run_msg_sched_passes (i32.const 48))
    (call $update_working_vars  (i32.const 64))

    (global.get $DIGEST_OFFSET)
  )
)
