# SHA256/224 Implementation in WebAssembly Text

I wrote the original version of this module on the assumption that NodeJS would act as the host environment.
This was all fine and dandy &mdash; everything worked as expected and also functioned correctly when invoked from [`wasmtime`](https://wasmtime.dev/).

However, when I attempted to run the program from [`wasmer`](https://wasmer.io), it generated a nonsense hash value... 🤔

After some investigation it turned out that `wasmer`'s implementation of the WASI interface to the `fd_read` function contained an unexpected difference.

This update accounts for that difference and yields binary that weighs in at a whopping 2.5Kb (😎)

---

# Run The Published Wasmer Package

If you simply want to run this app from the published package then, assuming you have already installed `wasmer`, use the command:

## To Obtain the SHA256 Hash

Set the `--command-name` argument to `sha256`

```bash
wasmer run chriswhealy/sha256 --mapdir <guest_dir>::<host_dir> --command-name=sha256 <host_dir>/<some_file_name>
```

## To Obtain the SHA224 Hash

The module name remains the same, but change the value of the `--command-name` argument to `sha224`

```bash
wasmer run chriswhealy/sha256 --mapdir <guest_dir>::<host_dir> --command-name=sha224 <host_dir>/<some_file_name>
```

In order for the `sha256` module to have access to your local file system, the host environment must pre-open the relevant files or directories on behalf of the WASM module where:

* `<guest_dir>` is the virtual directory name used by WebAssembly, and
* `<host_dir>` is the name of actual directory in your file system

For example, let's say you have a copy of ["War and Peace"](https://github.com/ChrisWhealy/wasm_sha256/blob/main/tests/war_and_peace.txt) in your home directory and you want to calculate this file's SHA256 hash:

```bash
wasmer run chriswhealy/sha256 --mapdir /::/Users/chris --command-name=sha256 war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  war_and_peace.txt
```

or the SHA224 hash:

```bash
wasmer run chriswhealy/sha256 --mapdir /::/Users/chris --command-name=sha224 war_and_peace.txt
93df4316673fc8ca9d9ab46e5804eb0101ac5bf89b15129999586f25  war_and_peace.txt
```

---

# Local Execution

## Host Environment Prerequisites

[Install NodeJS](https://nodejs.org/en/download) plus one or more of these WebAssembly Host environments:

* Wasmer: <https://docs.wasmer.io/runtime>
* Wasmtime: <https://wasmtime.dev/>
* Wazero: <https://wazero.io/>

## Building Locally

If you wish to run this app locally, clone the repo into some local directory, change into that directory, then:

```bash
$ npm run build

> wasm_sha256@2.0.1 build
> npm run compile & npm run opt


> wasm_sha256@2.0.1 compile
> wat2wasm ./src/sha256.wat -o ./bin/sha256.wasm


> wasm_sha256@2.0.1 opt
> wasm-opt ./bin/sha256.wasm --enable-simd --enable-multivalue --enable-bulk-memory -O4 -o ./bin/sha256.opt.wasm
```

## WASM File System Access

A WASM module only has access to the files or directories preopened for it by the host environment.
This means that when invoking the WASM module, we must instruct the host environment which files or directories need to be preopened.

The syntax for specifying such preopened resources varies between the different runtimes.

### NodeJS

The JavaScript module invoked by NodeJS does not use very sophisticated logic for determining the location of the target file.
Instead, it assumes the current working directory is the one containing `sha256sum.mjs` and the `WASI` instance then preopens `process.cwd()`.
This means the target file ***must*** live in (or beneath) that directory.

***SHA256***

```bash
$ node sha256sum.mjs sha256 ./tests/war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  ./tests/war_and_peace.txt
```

***SHA224***

```bash
$ node sha256sum.mjs sha224 ./tests/war_and_peace.txt
93df4316673fc8ca9d9ab46e5804eb0101ac5bf89b15129999586f25  war_and_peace.txt
```

## Wasmer

If present in the CWD, `wasmer` will read `wasmer.toml` to discover which WASM module is to be run.
In such cases, you need only specify `wasmer run .` and the meaning of `.` will be derived from the contents of `wasmer.toml`.

`wasmer`, has both a `--dir` and a `--mapdir` argument, but you should always use the `--mapdir` argument.
See [below](#wasmer-update) for why this is the case.

The value passed to the `--mapdir` argument is in the form `<guest_dir>::<host_dir>`.

***IMPORTANT***<br>
You cannot specify shortcuts such `.` as the value of the `<guest_dir>`, nor `~` as the value of the `<host_dir>`.

Since `<guest_dir>` identifies the name of the WebAssembly module's virtual root directory, you would typically identify this as `/`.

For the `<host_dir>`, `wasmer` does not evaluate the shell shortcut to your home directory (`~`).
Instead, to grant access to your home directory, use the fully qualifiied path name.
E.G. `/Users/chris/`.

In this example, the CWD contains the directory `./tests` which then contains `war_and_peace.txt`.
Since `./tests` becomes WASM's virtual root directory, the file name `war_and_peace.txt` does not need to be prefixed with the directory name.

***SHA256***

```bash
$ wasmer run . --mapdir /::./tests --command-name=sha256 -- war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  war_and_peace.txt
```
***SHA224***

```bash
$ wasmer run . --mapdir /::./tests --command-name=sha224 -- war_and_peace.txt
93df4316673fc8ca9d9ab46e5804eb0101ac5bf89b15129999586f25  war_and_peace.txt
```

## Wasmtime

The same logic used by `wasmer` applies when `wasmtime` creates WASM's virtual root directory.

In this example, the `--dir <host_dir>` argument uses `./tests` as the virtual root and from within WASM, `/` is implied.

***SHA256***

```bash
$ wasmtime --dir ./tests ./bin/sha256.opt.wasm -- sha256 war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  war_and_peace.txt
```

***SHA224***

```bash
$ wasmtime --dir ./tests ./bin/sha256.opt.wasm -- sha224 war_and_peace.txt
93df4316673fc8ca9d9ab46e5804eb0101ac5bf89b15129999586f25  war_and_peace.txt
```

## Wazero

When using `wazero`, the `--mount` argument uses a syntax similar to `wasmer`'s `--mapdir` argument.

***SHA256***

```bash
$ wazero run -mount=.:. ./bin/sha256.opt.wasm sha256 ./tests/war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  ./tests/war_and_peace.txt
```

***SHA224***

```bash
$ wazero run -mount=.:. ./bin/sha256.opt.wasm sha224 ./tests/war_and_peace.txt
93df4316673fc8ca9d9ab46e5804eb0101ac5bf89b15129999586f25  war_and_peace.txt
```

---

# Behind the Scenes

## Wasmer Update

* NodeJS passes three values as command line arguments to the WASM module, but host environments such as `wasmer` or `wasmtime` pass only two.

   This program therefore assumes that the filename will occur in the last argument.
* When calling this module via the Wasmer CLI, the `--dir` argument does not pre-open the directory in which the target files live.  [See here](https://github.com/wasmerio/wasmer/issues/5658#issuecomment-3139078222) for an explanation of this behaviour.

   Instead, you need to use the `--mapdir` argument.
* When calling `fd_read`, some WebAssembly host environments such as NodeJS or [`Wasmtime`](https://wasmtime.dev) allow you to specify a buffer size up to 4Gb.  This means that the entire file will be returned in a single call to `fd_read`.

   However, `wasmer` imposes a 2Mb upper limit on the buffer size.<sup>[1](#footnote1)</sup>  Therefore, in order to read files larger than 2Mb, multiple calls to `fd_read` are required.

## Making Mistakes With The Memory Map

Inside the WASM module, you (and you alone) are responsible for deciding how linear memory should be laid out.

Therefore, it's your job to decide which values are written to which locations and ***perform your own bounds checking!***.

When running the compiled binary through the optimization program `wasm-opt`, if you see the following warning message, then you know there is an overlap problem with two or more of your `data` declarations:

```bash
$ wasm-opt ./bin/sha256.wasm --enable-simd --enable-multivalue --enable-bulk-memory -O4 -o ./bin/sha256.opt.wasm

warning: active memory segments have overlap, which prevents some optimizations.
```

To make detecting such overlaps simpler, I've added<sup>[2](#footnote2)</sup> a Python script called `check_mem_overlaps.py` that runs the utility `wasm-objdump`, then parses the resulting memory map output to detect overlapping regions.

```bash
$ python3 check_mem_overlaps.py ./bin/sha256.opt.wasm
```

The output of this script will help you locate which `data` sections overlap.

## Debug/Trace Tools Used During Development

Whilst modifying this program to used buffered I/O, I needed to implement some debug/trace functionality within the WASM module which, before optimisation, bloated the binary to an enormous 6.5Kb (🤣).

Once the program worked correctly, these functions were no longer needed; however, I did not want to remove these functions from the source code because they will no doubt be useful for later enhancements.

In order to make this program "production ready", the following sections of the code have been commented out:

* Lines 135 - 151: Most of the `global` declarations whose names start with `DBG_*`
* Lines 214 - 231: The correspponding `data` declarations containing debug/trace message strings (pointed to by the above `global` declarations)
* All the calls to functions
  * `$write_args`
  * `$write_msg_with_value <fd> <msg_ptr> <msg_length> <some_i32_value>`
  * `$write_msg <fd> <msg_ptr> <msg_length>`
  * `$write_step <fd> <step_no> <return_code>`
  * `$hexdump`
* Notice that the source code for the above functions ***does not*** need to be commented out

As you would expect, the compiled binary does not contain any comments from the original source code; however, it still contains compiled versions of all the above, unused functions.

This is one of the reasons the compiled binary is then run through `wasm-opt`.
This program will both optimize the logic wherever it can, and trim out all unused functions.

This reduces the size of the compiled binary down to about 2.5Kb (😎).

## Activating the Debug/Trace Tools

Should you wish to play around with the inner workings of the module, it is recommended to activate the debug/trace coding.

1. On line 27, change the value of the global declaration `$DEBUG_ACTIVE` from `0` to `1`
2. Uncomment whichever of these function calls interest you:
   | Function Name | Description
   |---|---
   | `$write_args` | Writes the command line arguments to `stdout`
   | `$write_msg_with_value <fd> <msg_ptr> <msg_length> <some_i32_value>` | Writes a message followed by an `i32` value to the specified file descriptor
   | `$write_msg <fd> <msg_ptr> <msg_length>` | As above but without the `i32` value
   | `$write_step <fd> <step_no> <return_code>` | Writes the processing step number followed by its return code to the specified file descriptor
3. If you wish to see the content of each message block as the file is being processed, also uncomment the call to `$hexdump`.
   However, be warned. This will write a potentially large amount of data to the console, so you may want to redirect `stdout` to a file.
4. Run `npm run build`
5. When you now invoke the WASM module (`sha256.opt.wasm`) from `wasmer` or `wasmtime`, trace information will be written to the console.

## Understanding the SHA256 Algorithm

In order to understand the inner workings of the SHA256 algorithm itself, take a look at this excellent [SHA256 Algorithm](https://sha256algorithm.com/) website.
Thanks [@manceraio](https://twitter.com/manceraio)!


## Implementation Details

An explanation of how this updated version has been implemented can be found [here](./docs/README.md)

---
<a name="footnote1">1</a>) I have only tested this on macOS

<a name="footnote2">2</a>) I take neither credit nor responsibility for this script because it was generated by ChatGPT... Use at your own risk!
