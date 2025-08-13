# [Wasmer Update] SHA256 Implementation in WebAssembly Text

I wrote the original version of this module with the assumption that NodeJS would act as the host environment.
This was all fine and dandy &mdash; everything worked as expected.

However, when I attempted to use [`Wasmer`](https://wasmer.io) as the host environment, the WASM module did not function as expected due to some differences in the way the WASI interface has been implemented.

This update accounts for those differences.

During these modifications, I needed to implement some debug/trace functionality within the WASM module which, in turn, bloated the size of the binary to an enormous 2.9Kb (🤣)

It was less than half that before...

Anyhow, now that this version is working, rather than removing these debug/trace functions from the source code, the places where they were called have simply been commented out.
This affects the size of the initial binary `sha256.wasm` created by `wat2wasm` (6.4Kb); however, since this file is then passed through `wasm-opt`, any uncalled functions are pruned out, reducing the size of the binary by just over 50% (2.9Kb).

---

# Run The Published Wasmer Package

If you simply want to run this app from the published package then, assuming you have already installed wasmer, use the command:

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

* NodeJS passes three values as command line arguments to the WASM module, but host environments such as Wasmer pass only two.
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
> wasm-opt ./bin/sha256.wasm --enable-simd --enable-multivalue --enable-bulk-memory -O4 -o ./bin/sha256_opt.wasm
```

## Local Execution: File System Access

A WASM module only has access to the files or directories pre-opened for it by the host environment.
This means that when invoking the WASM module, we must tell the host environment which directory WASM needs pre-opened.

The syntax for specifying the host directory varies between the different runtimes.

### NodeJS

The JavaScript module used to invoke the `sha256` WASM module does not use very sophisticated logic for determining the location of the target file.
Instead, it assumes the current working directory is the one containing `sha256sum.mjs` and that the target file lives in some immediate subdirectory.
The `WASI` instance then pre-opens `process.cwd()` which means the target ***must*** live in (or beneath) that directory.

```bash
$ node sha256sum.mjs ./tests/war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  ./tests/war_and_peace.txt
```

## Wasmer

If present in the CWD, `wasmer` will read `wasmer.toml` to discover the WASM module(s) to be run.
In such cases, you need only specify `wasmer run .` and the meaning of `.` will be derived from `wasmer.toml`.

Also recall that when using `wasmer`, you must use the `--mapdir` argument, not the `--dir` argument.
The value passed to the `--mapdir` argument is in the form `<guest_dir>::<host_dir>`.

***IMPORTANT***<br>
You cannot specify `.` as the value of `<guest_dir>`; instead, use `/`.
This then becomes WASM's virtual root directory.

In this example, the local directory `./tests` located under the CWD becomes WASM's virtual root directory.
Consequently, the file name `war_and_peace.txt` does not require any directory name as a prefix.

```bash
$ wasmer run . --mapdir /::./tests -- war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  war_and_peace.txt
$
```

## Wasmtime

The same logic used by `wasmer` applies when `wasmtime` creates WASM's virtual root directory.

In this example, the `--dir <host_dir>` argument uses `./tests` as the virtual root; consequently, the file name `war_and_peace.txt` needs no directory name as a prefix.

```bash
$ wasmtime --dir ./tests ./bin/sha256_opt.wasm -- war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  war_and_peace.txt
$
```

## Wazero

When using `wazero`, use the `--mount` argument uses a syntax similar to `wasmer`'s `--mapdir` argument.

```bash
$ wazero run -mount=.:. ./bin/sha256_opt.wasm ./tests/war_and_peace.txt
11a5e2565ce9b182b980aff48ed1bb33d1278bbd77ee4f506729d0272cc7c6f7  ./tests/war_and_peace.txt
$
```

---

# Behind the Scenes

## Enabling Debug/Trace Functionality

If you wish to switch on the debug/trace output used during development, you will need to edit the `sha256.wat` source code as follows:

1. Change the global value `$DEBUG_ACTIVE` from `0` to `1`
2. Uncomment calls to the following functions:
   * `(call $write_args)`
   * `(call $write_msg_with_value <fd> <msg_ptr> <msg_length> <some i32 value>)`
   * `(call $write_msg <fd> <msg_ptr> <msg_length>)`
   * `(call $write_step <fd> <step_no> <return_code>)`
3. If you wish to see the content of each message block as the file is being processed, also uncomment the call to `$hexdump`.
4. Run `npm run build`
5. The WASM module will now output trace information to the console

## Understanding the SHA256 Algorithm

In order to understand the inner workings of the SHA256 algorithm itself, take a look at this excellent [SHA256 Algorithm](https://sha256algorithm.com/) website.
Thanks [@manceraio](https://twitter.com/manceraio)!


## Implementation Details

An explanation of how this updated version has been implemented can be found [here](./docs/README.md)

---
[^1] I have only tested this on macOS
