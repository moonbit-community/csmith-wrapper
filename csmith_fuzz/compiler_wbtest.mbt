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
  let config = config_from_specs(
    "ref=clang",
    ["one=clang", "two=gcc-15 -O2"],
    "include/csmith",
    Some("counterexamples"),
    false,
  )
  assert_eq(config.reference.name, "ref")
  assert_eq(config.include_root, "include/csmith")
  assert_eq(config.compilers.length(), 2)
  assert_eq(config.compilers[0].name, "one")
  assert_eq(config.compilers[1].name, "two")
}

///|
test "config accepts explicit counterexample directory" {
  let config = config_from_specs(
    "ref=clang",
    ["candidate=clang"],
    "include/csmith",
    Some("counterexamples"),
    false,
  )
  match config.counterexample_dir {
    Some(dir) => assert_eq(dir, "counterexamples")
    None => fail("expected counterexample directory")
  }
}

///|
test "config can disable counterexample saving" {
  let config = config_from_specs(
    "ref=clang",
    ["candidate=clang"],
    "include/csmith",
    None,
    false,
  )
  assert_true(config.counterexample_dir is None)
}

///|
test "config accepts explicit include root and keep going mode" {
  let config = config_from_specs(
    "ref=clang",
    ["candidate=clang"],
    "include/csmith",
    Some("counterexamples"),
    true,
  )
  assert_eq(config.include_root, "include/csmith")
  assert_true(config.continue_on_error)
}

///|
test "config rejects empty compiler list with typed error" {
  try {
    let _ = config_from_specs("ref=clang", [], "include/csmith", None, false)
    fail("expected NoCompilers")
  } catch {
    NoCompilers => ()
    err => fail(err.to_string())
  }
}
