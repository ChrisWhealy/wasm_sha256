# [Wasmer Update] SHA256 Implementation in WebAssembly Text

I wrote the original version of this module with the assumption that NodeJS would act as the host environment.
This was all fine and dandy &mdash; everything worked as expected.

However, when I attempted to use [`Wasmer`](https://wasmer.io) as the host environment, the WASM module did not function as expected due to some differences in the way the WASI interface has been implemented.

This update accounts for those differences and yields binary that weighs in at a whopping 2.5Kb (😎)

---

# Run The Published Wasmer Package

If you simply want to run this app from the published package then, assuming you have already installed `wasmer`, use the command:

```bash
wasmer run chriswhealy/sha256 --mapdir <guest_dir>::<host_dir> --command-name=sha256 <host_dir>/<some_file_name>
```

In order for the `sha256` module to have access to your local file system, `wasmer` must pre-open the relevant directory on behalf of the WASM module where:

* `<guest_dir>` is the name of directory as seen by WebAssembly, and
* `<host_dir>` is the name of actual directory in your file system

For example, let's say you have a copy of War and Peace in your home directory and you want this file's hash:

```bash
wasmer run chriswhealy/sha256 --mapdir /::/Users/chris --command-name=sha256 war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  war_and_peace.txt
```

---

# Local Execution

## Host Environment Prerequisites

[Install NodeJS](https://nodejs.org/en/download) plus one or more of these WebAssembly Host environments:

* Wasmer: <https://docs.wasmer.io/runtime>
* Wasmtime: <https://wasmtime.dev/>
* Wazero: <https://wazero.io/>

## Wasmer Update

* NodeJS passes three values as command line arguments to the WASM module, but host environments such as `wasmer` or `wasmtime` pass only two.
* When calling this module via the Wasmer CLI, the `--dir` argument does not pre-open the directory in which the target files live.  [See here](https://github.com/wasmerio/wasmer/issues/5658#issuecomment-3139078222) for an explanation of this behaviour.

   Instead, you need to use the `--mapdir` argument.
* When calling `fd_read`, some WebAssembly host environments such as NodeJS or [`Wasmtime`](https://wasmtime.dev) allow you to specify a buffer size up to 4Gb.  This means that the entire file will be returned in a single call to `fd_read`.

   However, `wasmer` imposes a 2Mb upper limit on the buffer size.[^1]  Therefore, in order to read files larger than 2Mb, multiple calls to `fd_read` are required.

## Building Locally

If you wish to run this app locally,

```bash
$ npm run build

> wasm_sha256@2.0.1 build
> npm run compile & npm run opt


> wasm_sha256@2.0.1 compile
> wat2wasm ./src/sha256.wat -o ./bin/sha256.wasm


> wasm_sha256@2.0.1 opt
> wasm-opt ./bin/sha256.wasm --enable-simd --enable-multivalue --enable-bulk-memory -O4 -o ./bin/sha256.opt.wasm
```

Alternatively, by running `npm run build-dev` you can build a development version of this module that contains deactivated debug/trace functionality.
See [here](#development-and-production-versions) for details of using this version.

## Local Execution: File System Access

A WASM module only has access to the files or directories pre-opened for it by the host environment.
This means that when invoking the WASM module, we must provide the host environment with a list of files or directories to preopen for the WASM module.

The syntax for specifying such resources varies between the different runtimes.

### NodeJS

The JavaScript module used to invoke the `sha256` WASM module does not use very sophisticated logic for determining the location of the target file.
Instead, it assumes the current working directory is the one containing `sha256sum.mjs` and that the target file lives in some immediate subdirectory.
The `WASI` instance then pre-opens `process.cwd()` which means the target file ***must*** live in (or beneath) that directory.

```bash
$ node sha256sum.mjs ./tests/war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  ./tests/war_and_peace.txt
```

## Wasmer

If present in the CWD, `wasmer` will read `wasmer.toml` to discover which WASM module(s) is to be run.
In such cases, you need only specify `wasmer run .` and the meaning of `.` will be derived from `wasmer.toml`.

Also recall that when using `wasmer`, you must use the `--mapdir` argument, not the `--dir` argument.
The value passed to the `--mapdir` argument is in the form `<guest_dir>::<host_dir>`.

***IMPORTANT***<br>
You cannot specify shortcuts such `.` as the value of the `<guest_dir>`, or `~` as the value of the `<host_dir>`.

Instead, for the `<guest_dir>` you would typically use `/`: this then becomes WASM's virtual root directory.

If you wish to grant access to your home directory, then use a fully qualifiied path name such as `/Users/chris/`.

In this example, the local directory `./tests` located under the CWD becomes WASM's virtual root directory.
Consequently, the file name `war_and_peace.txt` does not need to be prefixed with a directory name.

```bash
$ wasmer run . --mapdir /::./tests -- war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  war_and_peace.txt
$
```

## Wasmtime

The same logic used by `wasmer` applies when `wasmtime` creates WASM's virtual root directory.

In this example, the `--dir <host_dir>` argument uses `./tests` as the virtual root; consequently, the file name `war_and_peace.txt` does not need to be prefixed with a directory name.

```bash
$ wasmtime --dir ./tests ./bin/sha256_opt.wasm -- war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  war_and_peace.txt
$
```

## Wazero

When using `wazero`, the `--mount` argument uses a syntax similar to `wasmer`'s `--mapdir` argument.

```bash
$ wazero run -mount=.:. ./bin/sha256_opt.wasm ./tests/war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  ./tests/war_and_peace.txt
$
```

---

# Behind the Scenes

## Making Mistakes With The Memory Map

Inside the WASM module, you (and you alone) are responsible for deciding how linear memory should be laid out.

Therefore, it's your job to decide which values are written to which locations and how long those value are.
This includes the text strings used in error and debug messages.

You must store these strings at locations that do not overlap!

I've added[^2] a Python script called `check_wasm_overlaps.py` that runs the utility `wasm-objdump`, then checks the resulting memory map for overlapping regions.

```bash
$ python3 check_wasm_overlaps.py ./bin/sha256.debug.opt.wasm
```

The reason for having such a script is that if you make a mistake with your memory layout, then `wasm-opt` will output this warning message:

```bash
$ wasm-opt ./bin/sha256.debug.wasm --enable-simd --enable-multivalue --enable-bulk-memory -O4 -o ./bin/sha256.debug.opt.wasm

warning: active memory segments have overlap, which prevents some optimizations.
```

The output of this script will help you locate which `data` sections overlap.

## Development and Production Versions

Whilst adding these modifications, I needed to implement some debug/trace functionality within the WASM module which, before optimisation, bloated the binary to an enormous 6.5Kb (🤣)

However, by commenting out the calls to the debug/trace functions and then running the binary through `wasm-opt`, the size can be reduced to about 3Kb because all unused functions are removed.

That's fine, but `wasm-opt` is not able to trim out any `data` declarations holding the debug/trace messages.
These can only be removed by deleting the declarations from the source code.

Consequently, there are two versions of the source code:
* `sha256.debug.wat` contains all the extra debug functions and message declarations (these function are present, but commented out).
* `sha256.wat` is functionaly identical, but with all the debug/trace coding and declarations removed.

If you wish to see the debug/trace output used during development, you will need to edit `sha256.debug.wat` as follows:

1. Change the global value `$DEBUG_ACTIVE` from `0` to `1`
2. Uncomment whichever of these function calls interest you:
   | Function Name | Description
   |---|---
   | `$write_args` | Writes the command line arguments to `stdout`
   | `$write_msg_with_value <fd> <msg_ptr> <msg_length> <some_i32_value>` | Writes a message followed by an `i32` value to the specified file descriptor
   | `$write_msg <fd> <msg_ptr> <msg_length>` | As above but without the `i32` value
   | `$write_step <fd> <step_no> <return_code>` | Writes the processing step number followed by its return code to the specified file descriptor
3. If you wish to see the content of each message block as the file is being processed, also uncomment the call to `$hexdump`.
   However, be warned. This will write a potentially large amount of data to the console, so depending on the size of the file you're hashing, you may want to redirect `stdout` to a file.
4. Run `npm run build-dev`
5. When you now invoke the debug version of the WASM module (`sha256.debug.opt.wasm`) from `wasmer` or `wasmtime`, trace information will be written to the console.

## Understanding the SHA256 Algorithm

In order to understand the inner workings of the SHA256 algorithm itself, take a look at this excellent [SHA256 Algorithm](https://sha256algorithm.com/) website.
Thanks [@manceraio](https://twitter.com/manceraio)!


## Implementation Details

An explanation of how this updated version has been implemented can be found [here](./docs/README.md)

---
[^1] I have only tested this on macOS

[^2] Use at your own risk! I take neither credit nor responsibility for this script because it was generated by ChatGPT...
