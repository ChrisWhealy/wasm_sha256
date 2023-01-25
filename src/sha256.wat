(;
************************************************************************************************************************
CAUTION!

This program needs to handle a fundamental collision of concepts:
1) WebAssembly has no "raw binary" data type; only numeric data types.
2) The basic unit of data used by the SHA256 algorithm is 32-bit data word of raw binary data

PROBLEM:
Whenever the WebAssembly i32.load instruction is used, it will, by definition, treat the data as a 32-bit integer.
Therefore, when moving  data from memory to the stack, the data's byte order will be swapped according to the endianness
of the CPU on which this program is running.

Since this program will (almost certainly) be run on a little-endian CPU, simply calling i32.load against "raw binary"
data such as 0x0A0B0C0D, will cause 0x0D0C0B0A to appear on the stack... :-(

Therefore, in all situations where "raw binary" data is needed, the i32.load instruction must be wrapped by a function
that swaps the endianness after loading.

We now have two types of memory operation:
1) Those operations that read numeric data    (Safe to use i32.load)
2) Those operations that read raw binary data (Must use wrapper function $i32_load_swap)

Great care must be taken to distinguish when these two operation types are needed!
************************************************************************************************************************
;)
(module
  (import "log" "showMsgSchedule" (func $show_msg_schedule))
  (import "log" "showMsgBlock"    (func $show_msg_block    (param i32)))
  (import "log" "memCopyArgs"     (func $log_mem_copy_args (param i32) (param i32)))
  (import "log" "i32"             (func $log_i32           (param i32) (param i32)))

  (import "memory" "pages" (memory 2))

  (global $MEM_GROW_BY   (import "memory"  "growBy")     i32)
  (global $MSG_BLK_COUNT (import "message" "blockCount") i32)

  ;; Page 1: 0x000000 - 0x00001F  Constants - fractional part of square root of first 8 primes
  ;;         0x000020 - 0x00011F  Constants - fractional part of cube root of first 64 primes
  ;;         0x000120 - 0x00013F  Hash values used during hash generation
  ;;         0x000140 - 0x00015F  Working values used during hash generation
  ;;         0x000200 - 0x0002FF  Message Schedule
  ;; Page 2: 0x010000 - 0x01FFFF  Message Block (file data)
  (global $INIT_HASH_VALS_OFFSET i32 (i32.const 0x000000))
  (global $CONSTANTS_OFFSET      i32 (i32.const 0x000020))
  (global $HASH_VALS_OFFSET      i32 (i32.const 0x000120))
  (global $WORKING_VARS_OFFSET   i32 (i32.const 0x000140))
  (global $MSG_SCHED_OFFSET      i32 (i32.const 0x000200))
  (global $MSG_BLK_OFFSET        i32 (i32.const 0x010000))


  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Initial hash values are the first 32 bits of the fractional parts of the square roots of the first 8 primes 2..19
  (data (i32.const 0x000000)    ;; $INIT_HASH_VALS_OFFSET
    "\6A\09\E6\67"  ;; 0x000000
    "\BB\67\AE\85"
    "\3C\6E\F3\72"
    "\A5\4F\F5\3A"
    "\51\0E\52\7F"  ;; 0x010010
    "\9B\05\68\8C"
    "\1F\83\D9\AB"
    "\5B\E0\CD\19"
  )

  ;; Constants are the first 32 bits of the fractional parts of the cube roots of the first 64 primes 2..311
  (data (i32.const 0x000020)    ;; $CONSTANTS_OFFSET
    "\42\8A\2F\98"  ;; 0x000020
    "\71\37\44\91"
    "\B5\C0\FB\CF"
    "\E9\B5\DB\A5"
    "\39\56\C2\5B"  ;; 0x000030
    "\59\F1\11\F1"
    "\92\3F\82\A4"
    "\AB\1C\5E\D5"
    "\D8\07\AA\98"  ;; 0x000040
    "\12\83\5B\01"
    "\24\31\85\BE"
    "\55\0C\7D\C3"
    "\72\BE\5D\74"  ;; 0x000050
    "\80\DE\B1\FE"
    "\9B\DC\06\A7"
    "\C1\9B\F1\74"
    "\E4\9B\69\C1"  ;; 0x000060
    "\EF\BE\47\86"
    "\0F\C1\9D\C6"
    "\24\0C\A1\CC"
    "\2D\E9\2C\6F"  ;; 0x000070
    "\4A\74\84\AA"
    "\5C\B0\A9\DC"
    "\76\F9\88\DA"
    "\98\3E\51\52"  ;; 0x000080
    "\A8\31\C6\6D"
    "\B0\03\27\C8"
    "\BF\59\7F\C7"
    "\C6\E0\0B\F3"  ;; 0x000090
    "\D5\A7\91\47"
    "\06\CA\63\51"
    "\14\29\29\67"
    "\27\B7\0A\85"  ;; 0x0000A0
    "\2E\1B\21\38"
    "\4D\2C\6D\FC"
    "\53\38\0D\13"
    "\65\0A\73\54"  ;; 0x0000B0
    "\76\6A\0A\BB"
    "\81\C2\C9\2E"
    "\92\72\2C\85"
    "\A2\BF\E8\A1"  ;; 0x0000C0
    "\A8\1A\66\4B"
    "\C2\4B\8B\70"
    "\C7\6C\51\A3"
    "\D1\92\E8\19"  ;; 0x0000D0
    "\D6\99\06\24"
    "\F4\0E\35\85"
    "\10\6A\A0\70"
    "\19\A4\C1\16"  ;; 0x0000E0
    "\1E\37\6C\08"
    "\27\48\77\4C"
    "\34\B0\BC\B5"
    "\39\1C\0C\B3"  ;; 0x0000F0
    "\4E\D8\AA\4A"
    "\5B\9C\CA\4F"
    "\68\2E\6F\F3"
    "\74\8F\82\EE"  ;; 0x000100
    "\78\A5\63\6F"
    "\84\C8\78\14"
    "\8C\C7\02\08"
    "\90\BE\FF\FA"  ;; 0x000110
    "\A4\50\6C\EB"
    "\BE\F9\A3\F7"
    "\C6\71\78\F2"
  )

  ;; Hash values updated after each 512-byte messsage schedule is calculated
  (data (i32.const 0x000120)    ;; $HASH_VALS_OFFSET
    "\00\00\00\00"  ;; 0x000120
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"  ;; 0x000130
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"
  )

  ;; Working values used when processing a 512-byte message schedule block
  (data (i32.const 0x000140)    ;; $WORKING_VARS_OFFSET
    "\00\00\00\00"  ;; 0x000140
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"  ;; 0x000150
    "\00\00\00\00"
    "\00\00\00\00"
    "\00\00\00\00"
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

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Return the 32-bit word at byte offset $offset preserving the in-memory, big-endian byte order
  (func $i32_load_swap
        (param $offset i32)
        (result i32)
    (call $swap_endianness (i32.load (local.get $offset)))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Store $val at byte offset $offset preserving byte order
  (func $i32_swap_store
        (param $offset i32)
        (param $val i32)
    (i32.store (local.get $offset) (call $swap_endianness (local.get $val)))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Transfer working variable from memory to the stack
  ;; Endianness needs to be swapped to preserve raw binary byte order
  (func $fetch_working_variable
        (param $idx i32)  ;; Index of working value to be fetched in the range 0..7
        (result i32)
    (call $i32_load_swap (i32.add (global.get $WORKING_VARS_OFFSET) (i32.shl (local.get $idx) (i32.const 2))))
  )

  ;; Transfer working variable from the stack to memory
  (func $set_working_variable
        (param $idx i32)  ;; Index of working value to be set in the range 0..7
        (param $val i32)  ;; New value
    (i32.store
      (i32.add (global.get $WORKING_VARS_OFFSET) (i32.shl (local.get $idx) (i32.const 2)))
      (local.get $val)
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
  ;; result = $w1 + $sigma0 + $w3 + $sigma1
  (func $gen_msg_sched_word
        (param $offset i32)
        (result i32)

    (i32.add
      (i32.add
        (call $i32_load_swap (i32.sub (local.get $offset) (i32.const 64)))    ;; Value at $offset - 16 words
        (call $sigma                                                          ;; Calculate sigma0
          (call $i32_load_swap (i32.sub (local.get $offset) (i32.const 60)))  ;; Value at $offset - 15 words
          (i32.const 7)
          (i32.const 18)
          (i32.const 3)
        )
      )
      (i32.add
        (call $i32_load_swap (i32.sub (local.get $offset) (i32.const 28)))   ;; Value at $offset - 7 words
        (call $sigma                                                         ;; Calculate sigma1
          (call $i32_load_swap (i32.sub (local.get $offset) (i32.const 8)))  ;; Value at $offset - 2 words
          (i32.const 17)
          (i32.const 19)
          (i32.const 10)
        )
      )
    )
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Run $n passes of the message schedule calculation
  (func $run_msg_sched_passes
    (param $n i32)

    ;; First calculated message schedule word starts at offset 64 (word 16)
    (local $offset i32)
    (local.set $offset (i32.add (global.get $MSG_SCHED_OFFSET) (i32.const 64)))

    (loop $next_pass
      (call $i32_swap_store (local.get $offset) (call $gen_msg_sched_word (local.get $offset)))

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

    (local $temp1 i32)
    (local $temp2 i32)

    (local.set $a (call $fetch_working_variable (i32.const 0)))
    (local.set $b (call $fetch_working_variable (i32.const 1)))
    (local.set $c (call $fetch_working_variable (i32.const 2)))
    (local.set $d (call $fetch_working_variable (i32.const 3)))
    (local.set $e (call $fetch_working_variable (i32.const 4)))
    (local.set $f (call $fetch_working_variable (i32.const 5)))
    (local.set $g (call $fetch_working_variable (i32.const 6)))
    (local.set $h (call $fetch_working_variable (i32.const 7)))

    (loop $next_update
      ;; temp1 = $h + $big_sigma1($e) + constant($idx) + msg_schedule_word($idx) + $choice($e, $f, $g)
      (local.set $temp1
        (i32.add
          (i32.add
            (i32.add
              (local.get $h)
              ;; BigSigma1
              (call $big_sigma (local.get $e) (i32.const 6) (i32.const 11) (i32.const 25))
            )
            (i32.add
              ;; Fetch constant
              (call $i32_load_swap (i32.add (global.get $CONSTANTS_OFFSET) (i32.shl (local.get $idx) (i32.const 2))))
              ;; Fetch message schedule word
              (call $i32_load_swap (i32.add (global.get $MSG_SCHED_OFFSET) (i32.shl (local.get $idx) (i32.const 2))))
            )
          )
          ;; Choice
          (i32.xor
            (i32.and (local.get $e) (local.get $f))
            ;; Since WebAssembly has no bitwise NOT instruction, NOT must be implemented as i32.xor($val, -1)
            (i32.and (i32.xor (local.get $e) (i32.const -1)) (local.get $g))
          )
        )
      )

      ;; temp2 = $big_sigma0($a) + $majority($a, $b, $c)
      (local.set $temp2
        (i32.add
          ;; BigSigma0
          (call $big_sigma (local.get $a) (i32.const 2) (i32.const 13) (i32.const 22))
          ;; Majority
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

      ;; Test for continuation
      (br_if $next_update (i32.gt_u (local.get $n) (i32.const 0)))
    )

    ;; Write internal working variables back to memory
    (call $set_working_variable (i32.const 7) (local.get $h))
    (call $set_working_variable (i32.const 6) (local.get $g))
    (call $set_working_variable (i32.const 5) (local.get $f))
    (call $set_working_variable (i32.const 4) (local.get $e))
    (call $set_working_variable (i32.const 3) (local.get $d))
    (call $set_working_variable (i32.const 2) (local.get $c))
    (call $set_working_variable (i32.const 1) (local.get $b))
    (call $set_working_variable (i32.const 0) (local.get $a))
  )

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Add the 8 working variables ($a - $h) to the corresponding 8 hash values ($h0 - $h7)
  ;; Called after each 512-byte message schedule is processed
  (func $update_hash_vals
    (local $idx i32)

    (local $w_vars_offset i32)
    (local $hash_offset   i32)

    (local.set $w_vars_offset (global.get $WORKING_VARS_OFFSET))
    (local.set $hash_offset   (global.get $HASH_VALS_OFFSET))

    (loop $next_hash_val
      ;; Add current working variable to current hash value
      (call $i32_swap_store
        (local.get $hash_offset)
        (i32.add
          ;; Current hash value
          (call $i32_load_swap (local.get $hash_offset))
          ;; Current working variable - loaded as numeric data, not raw binary!
          (i32.load (local.get $w_vars_offset))
        )
      )

      (local.set $idx           (i32.add (local.get $idx)           (i32.const 1)))
      (local.set $w_vars_offset (i32.add (local.get $w_vars_offset) (i32.const 4)))
      (local.set $hash_offset   (i32.add (local.get $hash_offset)   (i32.const 4)))

      ;; Test for continuation
      (br_if $next_hash_val (i32.lt_u (local.get $idx) (i32.const 8)))
    )
  )

  ;; *******************************************************************************************************************
  ;; PUBLIC API
  ;; *******************************************************************************************************************
  (func (export "digest")
        (result i32)  ;; Pointer to the SHA256 digest

    (local $blk_count i32)
    (local $msg_blk_src i32)

    (local.set $msg_blk_src (global.get $MSG_BLK_OFFSET))

    ;; Initialise hash values and working variables
    (memory.copy (global.get $HASH_VALS_OFFSET)    (global.get $INIT_HASH_VALS_OFFSET) (i32.const 32))
    (memory.copy (global.get $WORKING_VARS_OFFSET) (global.get $HASH_VALS_OFFSET)      (i32.const 32))

    (call $log_i32 (i32.const 16) (global.get $MSG_BLK_OFFSET))

    (loop $next_msg_blk
      (call $log_mem_copy_args (local.get $msg_blk_src) (global.get $MSG_SCHED_OFFSET))

      ;; Transfer the next message block to the message schedule
      (memory.copy
        (global.get $MSG_SCHED_OFFSET) ;; Destination offset
        (local.get $msg_blk_src)       ;; Source offset
        (i32.const 64)                 ;; Length
      )

      (call $show_msg_block (i32.add (local.get $blk_count) (i32.const 1)))

      (call $run_msg_sched_passes (i32.const 48))
      (call $update_working_vars  (i32.const 64))
      (call $update_hash_vals)

      (local.set $msg_blk_src (i32.add (local.get $msg_blk_src) (i32.const 64)))
      (local.set $blk_count   (i32.add (local.get $blk_count)   (i32.const 1)))

      (br_if $next_msg_blk (i32.lt_u (local.get $blk_count) (global.get $MSG_BLK_COUNT)))
    )

    (global.get $HASH_VALS_OFFSET)
  )
)
