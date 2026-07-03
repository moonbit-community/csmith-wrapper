///|
fn timed_out(code : Int) -> Bool {
  code == 124 || code == 137 || code == 143
}

///|
async fn CaseContext::capture_command(
  self : CaseContext,
  stage : String,
  command : CommandLine,
  timeout : Int,
  cwd? : String,
) -> CommandResult {
  self.log(stage)
  run_command_capture(command, timeout, cwd?)
}

///|
async fn CaseContext::capture_binary(
  self : CaseContext,
  stage : String,
  bin_path : String,
  run_dir : String,
) -> CommandResult {
  ensure_dir(run_dir)
  self.capture_command(
    stage,
    { program: bin_path, args: [] },
    RUN_TIMEOUT_SEC,
    cwd=run_dir,
  )
}

///|
async fn[C : Compiler] CaseContext::execute_compiler(
  self : CaseContext,
  compiler : C,
  slot : String,
) -> CompilerOutcome {
  let name = compiler.name()
  let slug = slugify(slot)
  let preprocessed_path = self.path("\{slug}_preprocessed", ".i")
  let binary_path = self.path(slug, "")
  let run_dir = self.path("\{slug}_run", ".d")
  let source_path = self.path("source", ".c")
  let compat_path = self.path("compat", ".h")
  let preprocess = self.capture_command(
    "\{name} preprocess",
    compiler.preprocess_command(
      self.config.include_root,
      source_path,
      preprocessed_path,
      compat_path,
    ),
    COMPILE_TIMEOUT_SEC,
  )
  if preprocess.code != 0 {
    let stage = if timed_out(preprocess.code) {
      "\{name} preprocess timeout"
    } else {
      "\{name} preprocess"
    }
    return CompilerFailed({
      name,
      slug,
      stage,
      stage_slug: "\{slug}_preprocess",
      bug_source_path: source_path,
      preprocessed_path: None,
      result: preprocess,
    })
  }
  let compile = self.capture_command(
    "\{name} compile",
    compiler.compile_command(preprocessed_path, binary_path),
    COMPILE_TIMEOUT_SEC,
  )
  if compile.code != 0 {
    let stage = if timed_out(compile.code) {
      "\{name} compile timeout"
    } else {
      "\{name} compile"
    }
    return CompilerFailed({
      name,
      slug,
      stage,
      stage_slug: "\{slug}_compile",
      bug_source_path: preprocessed_path,
      preprocessed_path: Some(preprocessed_path),
      result: compile,
    })
  }
  let run = self.capture_binary("\{name} run", binary_path, run_dir)
  CompilerOk({ name, slug, preprocessed_path, result: run })
}
