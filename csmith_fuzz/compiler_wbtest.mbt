///|
test "parse named c-like compiler spec" {
  let compiler = parse_compiler_spec("gcc=c:gcc-15 -O2")
  assert_eq(compiler.name, "gcc")
  assert_eq(compiler.command.program, "gcc-15")
  assert_true(compiler.command.args == ["-O2"])
  assert_eq(compiler.kind, "c")
}

///|
test "parse named kimicc compiler spec" {
  let compiler = parse_compiler_spec("kimicc=kimicc:moon -C .. run cmd/main --")
  assert_eq(compiler.name, "kimicc")
  assert_eq(compiler.command.program, "moon")
  assert_true(compiler.command.args == ["-C", "..", "run", "cmd/main", "--"])
  assert_eq(compiler.kind, "kimicc")
}

///|
test "config accepts multiple compiler specs" {
  let config = config_from_specs("ref=c:clang", [
    "one=c:clang", "two=kimicc:moon -C .. run cmd/main --",
  ])
  assert_eq(config.reference.name, "ref")
  assert_eq(config.compilers.length(), 2)
  assert_eq(config.compilers[0].name, "one")
  assert_eq(config.compilers[1].name, "two")
  assert_eq(config.compilers[1].kind, "kimicc")
}

///|
test "config rejects empty compiler list with typed error" {
  try {
    let _ = config_from_specs("ref=c:clang", [])
    fail("expected NoCompilers")
  } catch {
    NoCompilers => ()
    err => fail(err.to_string())
  }
}
