///|
pub fn config_from_specs(
  reference_spec : String,
  compiler_specs : Array[String],
  include_root : String,
  counterexample_dir : String?,
  continue_on_error : Bool,
) -> Config raise WrapperError {
  let compilers : Array[ShellCompiler] = []
  for spec in compiler_specs {
    let spec = spec.trim()
    if spec != "" {
      compilers.push(parse_compiler_spec(spec.to_owned()))
    }
  }
  if compilers.length() == 0 {
    raise NoCompilers
  }
  {
    csmith_command: parse_command_line(
      env("CSMITH_WRAPPER_CSMITH").unwrap_or("csmith"),
    ),
    include_root,
    record_root: default_record_root(),
    counterexample_dir,
    continue_on_error,
    reference: parse_compiler_spec(reference_spec),
    compilers,
  }
}

///|
pub fn default_counterexample_dir() -> String? {
  Some(env("CSMITH_WRAPPER_COUNTEREXAMPLE_DIR").unwrap_or("test/bugs"))
}

///|
fn default_record_root() -> String {
  env("CSMITH_WRAPPER_RECORD_ROOT").unwrap_or(
    match env("TMPDIR") {
      Some(tmp) => @path.Path::join(tmp, "csmith_wrapper_records").to_string()
      None => ".csmith_wrapper_records"
    },
  )
}

///|
pub async fn require_toolchain(config : Config) -> Unit {
  if !@fs.exists(@path.Path::join(config.include_root, "csmith.h").to_string()) {
    raise MissingIncludeRoot(config.include_root)
  }
}
