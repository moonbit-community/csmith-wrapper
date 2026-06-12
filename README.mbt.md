# Csmith Differential Fuzzing

This standalone MoonBit CLI drives Csmith-generated C programs through one
reference compiler and one or more compilers under test. Every compiler gets its
own preprocessed input, then the runner compares each tested compiler's exit
code and stdout against the reference result.

The reference compiler is special: if the reference build or run is unusable,
the seed is discarded. In particular, reference runtime timeout means the Csmith
program is not a useful oracle for that seed. Runtime timeouts from other
compilers are recorded as abnormal results.

## Prerequisites

On macOS, install Csmith before running the fuzzer:

```sh
brew install csmith
```

The default commands are:

- `csmith`, used to generate random C programs.
- `clang`, used as the reference compiler.
- `moon`, used by the default kimicc compiler command.

Set the Csmith include directory explicitly. For a Homebrew install on Apple
Silicon this is usually:

```sh
export CSMITH_WRAPPER_INCLUDE_ROOT=/opt/homebrew/opt/csmith/include/csmith-2.3.0
```

## Compiler Specs

Compiler specs have this form:

```text
name=kind:command
```

`kind` is optional and defaults to `c`. Supported kinds:

- `c`: clang/gcc-like driver. Preprocess with `-E -P`, compile with `-w -o`.
- `kimicc`: kimicc-like driver. Preprocess with `-E`, compile with
  `--preprocessed`.

Examples:

```text
clang=c:clang
gcc=c:gcc-15
kimicc=kimicc:moon -C .. run cmd/main --target native --
```

The command portion is split into `program + argv` and passed directly to
`moonbitlang/async/process`; it is not executed through a shell. The split is
plain whitespace splitting, so keep command specs simple and use a wrapper
script if a command needs shell-only features such as pipes, redirection,
command substitution, glob expansion, or inline environment-variable expansion.

## Compile And Compare Scheme

Each fuzz case follows this pipeline:

1. Generate C with Csmith using a deterministic seed.
2. Preprocess, compile, and run the reference compiler.
3. If the reference compiler fails to preprocess/compile, discard the seed.
4. If the reference binary times out, discard the seed.
5. For each `--compiler`, preprocess, compile, and run its own input.
6. Save an abnormal case if a tested compiler fails, times out, or produces a
   different exit code or stdout from the reference.

Runtime mismatch logs include the seed, reference checksum, and compiler
checksum, for example:

```text
csmith csmith_fuzz_0 seed=209 mismatch reference=clang compiler=kimicc reference-checksum=6a43d8cf compiler-checksum=6a409c84
```

## Standalone Runner

Build the native binaries first:

```sh
moon build --target native
moon -C csmith_wrapper build --target native
```

Run the standalone fuzzer directly when you want streaming logs:

```sh
export KIMICC_BIN="$PWD/_build/native/debug/build/cmd/main/main.exe"
csmith_wrapper/_build/native/debug/build/cmd/main/main.exe \
  --reference "clang=c:clang" \
  --compiler "kimicc=kimicc:$KIMICC_BIN" \
  --compiler "system-clang=c:clang" \
  --seed 7 \
  --count 20
```

`--seed` is the first seed in the batch. The runner uses:

```text
seed_for_case = first_seed + case_index * 101
```

`--count` is the number of cases to run. The default is `20`.

You can also run it through `moon`:

```sh
moon -C csmith_wrapper run cmd/main --target native -- \
  --reference "clang=c:clang" \
  --compiler "kimicc=kimicc:moon -C .. run cmd/main --target native --" \
  --seed 7 \
  --count 20
```

The process exits with code `0` if no abnormal case is found. It exits with code
`1` after saving any mismatch, tested-compiler timeout, or tested-compiler
compile/preprocess failure.

## Outputs

The default bug directory is:

```text
test/bugs
```

Abnormal cases are saved as C files:

```text
test/bugs/csmith_seed_<seed>_<stage>.c
```

When the tested compiler reached compile or run, the saved file is that
compiler's preprocessed input. For preprocess failures, the generated source is
saved instead.

The default record root is:

```text
$TMPDIR/csmith_wrapper_records
```

Each record directory contains the original generated source, `compat.h`,
pretty-printed `manifest.json`, per-abnormal `<stage>_failure.json` files, and
the relevant per-compiler preprocessed inputs and stdout files. The JSON reports
include commands, flags, timeouts, compiler metadata, exit codes, captured
stdout, checksums, and saved bug-case paths.

## Environment Variables

- `CSMITH_WRAPPER_CSMITH`: Csmith command. Default: `csmith`.
- `CSMITH_WRAPPER_REFERENCE`: reference compiler spec. Default:
  `clang=c:clang`.
- `CSMITH_WRAPPER_COMPILERS`: semicolon-separated compiler specs used when
  `--compiler` is not passed.
- `CSMITH_WRAPPER_INCLUDE_ROOT`: directory containing `csmith.h`.
- `CSMITH_WRAPPER_RECORD_ROOT`: directory for full per-case records.
- `CSMITH_WRAPPER_BUG_DIR`: directory for saved abnormal cases. Default:
  `test/bugs`.

The old `KIMICC_CSMITH_*` variables are still accepted as fallbacks for the
default kimicc workflow.

## Manual Reproduction

To compile a saved bug with kimicc and compare it with clang:

```sh
moon build --target native

case_c=test/bugs/csmith_seed_209_compiler_0_kimicc_runtime_mismatch.c

_build/native/debug/build/cmd/main/main.exe --preprocessed "$case_c" -o /tmp/kimicc_bug
/tmp/kimicc_bug

record_dir=$TMPDIR/csmith_wrapper_records/csmith_fuzz_0_209
clang -w -o /tmp/clang_bug "$record_dir/reference_clang_preprocessed.i"
/tmp/clang_bug
```

The expected output shape is the Csmith checksum line:

```text
checksum = <hex>
```
