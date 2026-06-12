///|
fn compat_header_source() -> String {
  (
    #|extern double fabs(double);
    #|extern float fabsf(float);
    #|extern double ldexp(double, int);
    #|extern float ldexpf(float, int);
  )
}

///|
fn csmith_flags() -> Array[String] {
  [
    "--concise", "--quiet", "--no-argc", "--no-float", "--no-packed-struct", "--max-funcs",
    "3", "--max-block-depth", "3", "--max-block-size", "3", "--max-expr-complexity",
    "5", "--max-array-dim", "2", "--max-array-len-per-dim", "4",
  ]
}

///|
fn Config::generate_command(
  self : Config,
  seed : Int,
  source_path : String,
) -> CommandLine {
  self.csmith_command.append(
    ["--seed", seed.to_string(), ..csmith_flags(), "--output", source_path],
  )
}

///|
async fn CaseContext::log(self : CaseContext, stage : String) -> Unit {
  @stdio.stdout.write("csmith \{self.tag} seed=\{self.seed} \{stage}\n")
}

///|
fn CaseContext::path(
  self : CaseContext,
  name : String,
  suffix : String,
) -> String {
  temp_file_path("\{self.prefix}_\{name}", self.seed.to_string(), suffix)
}

///|
async fn CaseContext::generate(self : CaseContext) -> Unit {
  let source_path = self.path("source", ".c")
  let compat_path = self.path("compat", ".h")
  let generate_dir = self.path("generate", ".d")
  @fs.write_file(
    compat_path,
    compat_header_source(),
    create_mode=CreateOrTruncate,
  )
  ensure_dir(generate_dir)
  self.log("generate")
  run_command_checked_timed(
    self.config.generate_command(self.seed, source_path),
    COMPILE_TIMEOUT_SEC,
    "generate csmith \{self.tag}",
    cwd=generate_dir,
  )
}
