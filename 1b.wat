(module
  (type (;0;) (func (param i32 i32 i32 i32 i32 i64 i64 i32 i32) (result i32)))
  (type (;1;) (func (param i32)))
  (type (;2;) (func (param i32 i32 i32 i32) (result i32)))
  (type (;3;) (func (param i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "path_open" (func $open (type 0)))
  (import "wasi_snapshot_preview1" "proc_exit" (func $exit (type 1)))
  (import "wasi_snapshot_preview1" "fd_read" (func $read (type 2)))
  (import "wasi_snapshot_preview1" "fd_write" (func $write (type 3)))
  (memory (;0;) 1)
  (export "memory" (memory 0))
  (data (i32.const 8) "data.txt")
  ;; store space padded 6-letter words for digits 1-9 6x9=53 bytes (extra space after nine is truncated)
  ;;                    11111122222233333344444455555566666677777788888899999
  (data (i32.const 32) "one   two   three four  five  six   seven eight nine ")
  (func $main (export "_start")
    (local $errno i32)
    (local $total i32)
    (local $first i32)
    (local $last i32)
    (local $pointer i32)
    (local $digit i32)
    (local $wordptr i32)
    (local $charnum i32)
    (i32.store (i32.const 0) (i32.const 8))  ;; iov.iov_base - pointer to filename buffer
    (i32.store (i32.const 4) (i32.const 8))  ;; iov.iov_len - length of filename buffer
    (call $open
      (i32.const 3)  ;; Mounted file descriptor
      (i32.const 0)  ;; No lookup flags
      (i32.const 8)  ;; Path address
      (i32.const 8)  ;; Path length
      (i32.const 0)  ;; Open flags
      (i64.const 2)  ;; Rights to read
      (i64.const 0)  ;; Inherited rights
      (i32.const 0)  ;; fdflags
      (i32.const 16)  ;; Opened file descriptor address
    )
    (if
      (i32.ne (local.tee $errno) (i32.const 0))
      (then (call $exit (local.get $errno)))
    )
    ;; iov struct pointing to where to store file contents
    (i32.store (i32.const 0) (i32.const 85))  ;; iov.iov_base - pointer to read buffer
    (i32.store (i32.const 4) (i32.const 32768))  ;; iov.iov_len - length of read buffer
    (call $read
      (i32.load (i32.const 16))  ;; File descriptor address
      (i32.const 0)  ;; iov address
      (i32.const 1)  ;; Number of iov structs
      (i32.const 20)  ;; Number of bytes read
    )
    (if
      (i32.ne (local.tee $errno) (i32.const 0))
      (then (call $exit (local.get $errno)))
    )
    (local.set $total (i32.const 0))
    (local.set $pointer (i32.const 85))
    (local.set $first (i32.const -1))
    (local.set $last (i32.const -1))
    (loop $loop
      ;; if pointer = \n then add first * 10 + last to total
      (if
        (i32.eq (i32.load8_u (local.get $pointer)) (i32.const 10))
        (then
          (local.set $total
            (i32.add
              (local.get $total)
              (i32.add
                (i32.mul (local.get $first) (i32.const 10))
                (local.get $last)
              )
            )
          )
          ;; Reset first=-1, last=-1
          (local.set $first (i32.const -1))
          (local.set $last (i32.const -1))
        )
      )
      ;; if pointer = digit
      (if
        (i32.and
          (i32.ge_u (i32.load8_u (local.get $pointer)) (i32.const 48))
          (i32.le_u (i32.load8_u (local.get $pointer)) (i32.const 57))
        )
        (then
          (local.set $digit (i32.sub (i32.load8_u (local.get $pointer)) (i32.const 48)))
          ;; if first = -1 then first = value
          (if
            (i32.eq (local.get $first) (i32.const -1))
            (then (local.set $first (local.get $digit)))
          )
          ;; last = value
          (local.set $last (local.get $digit))
        )
      )
      ;; Look for digits as words
      (local.set $digit (i32.const 1))
      (loop $word_loop (block $word_block
        (local.set $wordptr (i32.add (i32.const 26) (i32.mul (local.get $digit) (i32.const 6))))
        (local.set $charnum (i32.const 0))
        (loop $char_loop (block $char_block
          ;; if chars does not match, break char loop
          (if
            (i32.ne (i32.load8_u (i32.add (local.get $wordptr) (local.get $charnum))) (i32.load8_u (i32.add (local.get $pointer) (local.get $charnum))))
            (then (br $char_block))
          )
          ;; increment charnum
          (local.set $charnum (i32.add (local.get $charnum) (i32.const 1)))
          ;; if char is ' ' then word matches so set first/last digit and break word block
          (if
            (i32.eq (i32.load8_u (i32.add (local.get $wordptr) (local.get $charnum))) (i32.const 32))
            (then
              ;; if first = -1 then first = value
              (if
                (i32.eq (local.get $first) (i32.const -1))
                (then (local.set $first (local.get $digit)))
              )
              ;; last = value
              (local.set $last (local.get $digit))
              (br $word_block)
            )
          )
          ;; if pointer + charnum < EOF then goto char loop
          (if (i32.lt_u (i32.add (local.get $pointer) (local.get $charnum)) (i32.add (i32.const 84) (i32.load (i32.const 20))))
            (then (br $char_loop))
          )
        ))
        (local.set $digit (i32.add (local.get $digit) (i32.const 1)))
        ;; if word < 10 then goto word loop
        (if
          (i32.lt_u (local.get $digit) (i32.const 10))
          (then (br $word_loop))
        )
      ))
      ;; pointer += 1
      (local.set $pointer (i32.add (local.get $pointer) (i32.const 1)))
      ;; if pointer < EOF then continue loop
      (if
        (i32.lt_u (local.get $pointer) (i32.add (i32.const 84) (i32.load (i32.const 20))))
        (then (br $loop))
      )
    )
    ;; print total
    (i32.store8 (i32.const 64) (i32.const 10))
    (local.set $pointer (i32.const 64))
    (loop $print_digit
      (local.set $pointer (i32.sub (local.get $pointer) (i32.const 1)))
      (local.set $digit (i32.rem_u (local.get $total) (i32.const 10)))
      (local.set $total (i32.div_u (local.get $total) (i32.const 10)))
      (i32.store8 (local.get $pointer) (i32.add (local.get $digit) (i32.const 48)))
      (if
        (i32.ne (local.get $total) (i32.const 0))
        (then (br $print_digit))
      )
    )
    (i32.store (i32.const 0) (local.get $pointer))  ;; iov.iov_base - pointer to read buffer
    (i32.store (i32.const 4) (i32.sub (i32.const 65) (local.get $pointer)))  ;; iov.iov_len - length of write buffer
    (call $write
      (i32.const 1) ;; file_descriptor - 1 for stdout
      (i32.const 0) ;; *iovs - pointer to iov array
      (i32.const 1) ;; iovs_len - 1 string stored in an iov - so one.
      (i32.const 24) ;; nwritten - Where to store bytes written
    )
    drop
  )
)
