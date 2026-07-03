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

Pass the directory containing `csmith.h` explicitly:

```sh
--include-root /path/to/csmith/include
```

## Compiler Specs

Compiler specs have this form:

```text
name=command
```

`name=` is optional. When omitted, the wrapper uses the last path segment of the
command program. Every compiler command is treated as an ordinary C compiler
driver: preprocess with `-w -E -P`, compile with `-w -o`.

Examples:

```text
clang=clang
gcc=gcc-15
/opt/toolchain/bin/cc -O2
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
csmith csmith_fuzz_0 seed=209 mismatch reference=clang compiler=candidate reference-checksum=6a43d8cf compiler-checksum=6a409c84
```

## Standalone Runner

Build the native binaries first:

```sh
moon build --target native
moon -C csmith_wrapper build --target native
```

Run the standalone fuzzer directly when you want streaming logs:

```sh
csmith_wrapper/_build/native/debug/build/cmd/csmith_wrapper/csmith_wrapper.exe \
  --reference "clang=clang" \
  --compiler "candidate=/path/to/c-compiler" \
  --compiler "system-clang=clang" \
  --include-root /path/to/csmith/include \
  --counterexample-dir counterexamples \
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
moon -C csmith_wrapper run cmd/csmith_wrapper --target native -- \
  --reference "clang=clang" \
  --compiler "candidate=/path/to/c-compiler" \
  --include-root /path/to/csmith/include \
  --counterexample-dir counterexamples \
  --seed 7 \
  --count 20
```

## Install

Install the CLI into Moon's binary directory:

```sh
moon -C csmith_wrapper install ./cmd/csmith_wrapper
```

This installs `csmith_wrapper` to `~/.moon/bin` by default. Use `--bin <dir>` to
install it somewhere else.

After installation:

```sh
csmith_wrapper \
  --reference "clang=clang" \
  --compiler "candidate=/path/to/c-compiler" \
  --include-root /path/to/csmith/include \
  --counterexample-dir counterexamples \
  --seed 7 \
  --count 20
```

Use `--no-save-counterexamples` when you only want the terminal output to report
the failing seed and do not want counterexample C files or abnormal-case records:

```sh
csmith_wrapper \
  --reference "clang=clang" \
  --compiler "candidate=/path/to/c-compiler" \
  --include-root /path/to/csmith/include \
  --no-save-counterexamples \
  --continue-on-error \
  --seed 7 \
  --count 20
```

`--continue-on-error` keeps the batch running after a per-seed wrapper error
such as Csmith generation failure. Compiler failures, timeouts, and mismatches
are already collected without stopping the batch. Global setup errors such as a
missing Csmith include root remain fatal because no seed can run correctly.

The process exits with code `0` if no abnormal case is found. It exits with code
`1` after saving any mismatch, tested-compiler timeout, or tested-compiler
compile/preprocess failure.

## Outputs

Counterexamples are saved only when `--counterexample-dir` is passed:

```text
<counterexample-dir>/csmith_seed_<seed>_<stage>.c
```

When saving is enabled and the tested compiler reached compile or run, the saved
file is that compiler's preprocessed input. For preprocess failures, the
generated source is saved instead.

The record root is:

```text
$TMPDIR/csmith_wrapper_records
```

If `TMPDIR` is unset, `/tmp` is used.

Each record directory contains the original generated source, `compat.h`,
pretty-printed `manifest.json`, per-abnormal `<stage>_failure.json` files, and
the relevant per-compiler preprocessed inputs and stdout files. The JSON reports
include commands, flags, timeouts, compiler metadata, exit codes, captured
stdout, checksums, and saved counterexample paths.

## Manual Reproduction

To compile a saved counterexample with a candidate compiler and compare it with
clang:

```sh
candidate=/path/to/c-compiler

case_c=counterexamples/csmith_seed_209_compiler_0_candidate_runtime_mismatch.c

"$candidate" -w -o /tmp/candidate_bug "$case_c"
/tmp/candidate_bug

record_dir=${TMPDIR:-/tmp}/csmith_wrapper_records/csmith_fuzz_0_209
clang -w -o /tmp/clang_bug "$record_dir/reference_clang_preprocessed.i"
/tmp/clang_bug
```

The expected output shape is the Csmith checksum line:

```text
checksum = <hex>
```
