# Step 6: Open the File

Opening a file means calling the function `$wasi.path_open`.

Since this function takes quite a few arguments, it is first worth looking at a Rust implementation of [`path_open`](https://github.com/bytecodealliance/wasmtime/blob/06377eb08a649619cc8ac9a934cb3f119017f3ef/crates/wasi-preview1-component-adapter/src/lib.rs#L1819) to get an idea of what these argument values mean.

The `wasmtime` Rust function signature looks like this:

```rust
pub unsafe extern "C" fn path_open(
    fd: Fd,
    dirflags: Lookupflags,
    path_ptr: *const u8,
    path_len: usize,
    oflags: Oflags,
    fs_rights_base: Rights,
    fs_rights_inheriting: Rights,
    fdflags: Fdflags,
    opened_fd: *mut Fd,
) -> Errno
```

A successful call to this function returns a file descriptor with the correct capabilities.
If we get the capability flags wrong, then the resulting file descriptor will still point to an open file, but we are likely to get back `Errno = 76` (Not capable) when trying to perform our required operations.

| Arg No | Arg Name | Description
|---|---|---
| 1 | `fd` | The first argument is the file descriptor of the directory in (or below) which we expect to find the file we want to open. In our case, this is file descriptor `3` that WASI preopened for us.
| 2 | `dirFlags` | We can pass zero here because we are not interested in following symbolic links
| 3 | `path_ptr` | The pointer to the file pathname.  In our case, we assume this is the last argument in the list
| 4 | `path_len` | The length of the path name.
| 5 | `oflags` | These flags determine whether we are opening a file or a directory, and what should happen if that object either does or does not already exist.
| 6 | `fs_rights_base` | The capability flags assigned to the file descriptor.
| 7 | `fs_rights_inheriting` | Inherited capability flags (not relevant in our case).
| 8 | `fdflags` | Bit flags that describe the manner in which data is written to the file (not relevant in our case).
| 9 | `opened_fd` | A pointer to the file descriptor that `path_open` has just openend for us.

The WebAssembly coding looks like this:

```wat
(call $wasi.path_open
  (local.get $fd_dir)        ;; fd of preopened directory
  (i32.const 0)              ;; dirflags (no special flags)
  (local.get $path_offset)   ;; path (pointer to file path in memory)
  (local.get $path_len)      ;; path_len (length of the path string)
  (i32.const 0)              ;; oflags (O_RDONLY for reading)
  (i64.const 6)              ;; Base rights (RIGHTS_FD_READ 0x02 + RIGHTS_FD_SEEK 0x04)
  (i64.const 0)              ;; Inherited rights
  (i32.const 0)              ;; fdflags (O_RDONLY)
  (global.get $FD_FILE_PTR)  ;; Write new file descriptor here
)
```

The only flags that we need to specify are the base rights.
Here we must switch on bit 2 for "read capability" and bit 3 for "seek capability", which, when OR'ed together give 6.

Assuming that we are allowed to open this file, we will get back a new file descriptor that can be saved in a local variable as follows:

```wat
;; Pick up the file descriptor value
(local.set $fd_file (i32.load (global.get $FD_FILE_PTR)))
```

Now that the file is open, we cannot yet start reading from it.
First we must check that our WebAssembly module has sufficient memory allocated to it.
