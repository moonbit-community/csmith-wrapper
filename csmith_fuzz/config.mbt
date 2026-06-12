///|
pub fn config_from_specs(
  reference_spec : String,
  compiler_specs : Array[String],
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
      env("CSMITH_WRAPPER_CSMITH").unwrap_or(
        env("KIMICC_CSMITH").unwrap_or("csmith"),
      ),
    ),
    include_root: match env("CSMITH_WRAPPER_INCLUDE_ROOT") {
      Some(root) => Some(root)
      None => env("KIMICC_CSMITH_INCLUDE_ROOT")
    },
    record_root: default_record_root(),
    bug_dir: env("CSMITH_WRAPPER_BUG_DIR").unwrap_or(
      env("KIMICC_CSMITH_BUG_DIR").unwrap_or("test/bugs"),
    ),
    reference: parse_compiler_spec_with_default(reference_spec, "c"),
    compilers,
  }
}

///|
fn default_record_root() -> String {
  env("CSMITH_WRAPPER_RECORD_ROOT").unwrap_or(
    env("KIMICC_CSMITH_RECORD_ROOT").unwrap_or(
      match env("TMPDIR") {
        Some(tmp) => @path.Path::join(tmp, "csmith_wrapper_records").to_string()
        None => ".csmith_wrapper_records"
      },
    ),
  )
}

///|
pub async fn require_toolchain(config : Config) -> Unit {
  match config.include_root {
    Some(include_dir) =>
      if !@fs.exists(@path.Path::join(include_dir, "csmith.h").to_string()) {
        raise MissingIncludeRoot(include_dir)
      }
    None =>
      raise MissingIncludeRoot(
        "set CSMITH_WRAPPER_INCLUDE_ROOT to the directory containing csmith.h",
      )
  }
}
