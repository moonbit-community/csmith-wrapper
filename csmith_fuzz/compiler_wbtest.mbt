///|
test "parse named compiler spec" {
  let compiler = parse_compiler_spec("gcc=gcc-15 -O2")
  assert_eq(compiler.name, "gcc")
  assert_eq(compiler.command.program, "gcc-15")
  assert_true(compiler.command.args == ["-O2"])
}

///|
test "parse unnamed compiler spec" {
  let compiler = parse_compiler_spec("/opt/toolchain/bin/cc -O2")
  assert_eq(compiler.name, "cc")
  assert_eq(compiler.command.program, "/opt/toolchain/bin/cc")
  assert_true(compiler.command.args == ["-O2"])
}

///|
test "config accepts multiple compiler specs" {
  let config = config_from_specs("ref=clang", ["one=clang", "two=gcc-15 -O2"])
  assert_eq(config.reference.name, "ref")
  assert_eq(config.compilers.length(), 2)
  assert_eq(config.compilers[0].name, "one")
  assert_eq(config.compilers[1].name, "two")
}

///|
test "config rejects empty compiler list with typed error" {
  try {
    let _ = config_from_specs("ref=clang", [])
    fail("expected NoCompilers")
  } catch {
    NoCompilers => ()
    err => fail(err.to_string())
  }
}
