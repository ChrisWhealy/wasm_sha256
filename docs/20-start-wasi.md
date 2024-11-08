# Step 2: Start WASI

Now that the WAT coding imports the required WASI functions, the host environment can start the WASM module instance.

The JavaScript coding in the previous step created an instance of our WebAssembly module.
Now we can use WASI to start that instance.

```javascript
const wasi = new WASI({
  args: process.argv,
  version: "unstable",
  preopens: { ".": process.cwd() },
})

let { instance } = await WebAssembly.instantiate(
  new Uint8Array(readFileSync(pathToWasmMod)),
  {
    wasi: wasi.wasiImport
  },
)

wasi.start(instance)
```

## WASI Prerequisites

When starting a WebAssembly module instance using WASI, that module must fulfil two prerequisites.

1. WASI expects the WebAssembly module to export a block of memory called `memory`.
   This means we need a statement in our WAT coding like this:

   ```wat
   (memory $memory (export "memory") 2)
   ```

1. WASI also expects the WebAssembly module to export a function called `_start`.  When the host environment calls `wasi.start()`, this function will automatically be executed.

   This function must always exists &mdash; even if you have no need for it.
   If that is the case, then the function would look like this:

   ```wat
   (func (export "_start"))
   ```

   However, in our case, the `_start` function needs to contain the functionality to count, then parse the command line arguments.
