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
    csmith_command: parse_command_line("csmith"),
    include_root,
    record_root: @path.Path::join(tmp_root(), "csmith_wrapper_records").to_string(),
    counterexample_dir,
    continue_on_error,
    reference: parse_compiler_spec(reference_spec),
    compilers,
  }
}

///|
pub async fn require_toolchain(config : Config) -> Unit {
  if !@fs.exists(@path.Path::join(config.include_root, "csmith.h").to_string()) {
    raise MissingIncludeRoot(config.include_root)
  }
}
