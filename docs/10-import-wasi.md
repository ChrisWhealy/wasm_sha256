# Step 1: Import WASI Functions Into WebAssembly

## Defining a WASI instance in the Host Environment

Before we can import any WASI functions into WebAssembly, we must first create a WASI instance in the host environment.
In our case, that WASI instance looks like this:

```javascript
const wasi = new WASI({
  args: process.argv,
  version: "unstable",
  preopens: { ".": process.cwd() },
})
```

Once the WASI instance has been created, it makes all the operating system calls available via its `.wasiImport` property.

Consequently, when we create the WebAssembly module instance, we grant that instance access to those functions by supplying `wasi.wasiImport` as the value of some arbitrarily named property.
In this case, we are using the property name `wasi`.

```javascript
let { instance } = await WebAssembly.instantiate(
  new Uint8Array(readFileSync(pathToWasmMod)),
  {
    wasi: wasi.wasiImport
  },
)
```

## Importing WASI Functions into WebAssembly

Now that the host environment provides the WebAssembly module with access to OS level calls, we can start to make use of those calls in the WAT coding.
First, we must import the required functions.

```wat
(module
  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Function types for WASI calls
  (type $type_wasi_args      (func (param i32 i32)                             (result i32)))
  (type $type_wasi_path_open (func (param i32 i32 i32 i32 i32 i64 i64 i32 i32) (result i32)))
  (type $type_wasi_fd_seek   (func (param i32 i64 i32 i32)                     (result i32)))
  (type $type_wasi_fd_io     (func (param i32 i32 i32 i32)                     (result i32)))
  (type $type_wasi_fd_close  (func (param i32)                                 (result i32)))

  ;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ;; Import OS system calls via WASI
  (import "wasi" "args_sizes_get" (func $wasi_args_sizes_get (type $type_wasi_args)))
  (import "wasi" "args_get"       (func $wasi_args_get       (type $type_wasi_args)))
  (import "wasi" "path_open"      (func $wasi_path_open      (type $type_wasi_path_open)))
  (import "wasi" "fd_seek"        (func $wasi_fd_seek        (type $type_wasi_fd_seek)))
  (import "wasi" "fd_read"        (func $wasi_fd_read        (type $type_wasi_fd_io)))
  (import "wasi" "fd_write"       (func $wasi_fd_write       (type $type_wasi_fd_io)))
  (import "wasi" "fd_close"       (func $wasi_fd_close       (type $type_wasi_fd_close)))
```

These declarations need to occur at the start of the WAT coding.
