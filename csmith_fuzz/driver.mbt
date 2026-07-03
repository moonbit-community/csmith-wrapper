///|
async fn CaseContext::compare_candidate(
  self : CaseContext,
  reference : CompilerRun,
  compiler : ShellCompiler,
  slot : String,
) -> String? {
  match self.execute_compiler(compiler, slot) {
    CompilerFailed(failure) =>
      Some(self.record_candidate_failure(reference, failure))
    CompilerOk(candidate) =>
      if timed_out(candidate.result.code) {
        Some(self.record_candidate_timeout(reference, candidate))
      } else if candidate.result.code != reference.result.code ||
        candidate.result.output != reference.result.output {
        Some(self.record_candidate_mismatch(reference, candidate))
      } else {
        None
      }
  }
}

///|
async fn CaseContext::compare_candidates(
  self : CaseContext,
  reference : CompilerRun,
) -> Array[String] {
  let failures : Array[String] = []
  for index in 0..<self.config.compilers.length() {
    let compiler = self.config.compilers[index]
    let slot = "compiler_\{index}_\{compiler.slug()}"
    match self.compare_candidate(reference, compiler, slot) {
      Some(failure) => failures.push(failure)
      None => ()
    }
  }
  failures
}

///|
async fn Config::run_case(
  self : Config,
  seed : Int,
  tag : String,
) -> Array[String] {
  let case = {
    config: self,
    seed,
    tag,
    prefix: "\{tag}_csmith",
    record_dir: @path.Path::join(self.record_root, "\{tag}_\{seed}").to_string(),
  }
  case.log("start")
  case.generate()
  let reference_slot = "reference_\{self.reference.slug()}"
  let reference = match case.execute_compiler(self.reference, reference_slot) {
    CompilerOk(run) => run
    CompilerFailed(failure) => {
      case.record_reference_failure(failure)
      return []
    }
  }
  if timed_out(reference.result.code) {
    case.record_reference_timeout(reference)
    return []
  }
  let failures = case.compare_candidates(reference)
  if failures.length() == 0 {
    case.log("ok")
  }
  failures
}

///|
pub async fn run_batch(
  config : Config,
  first_seed : Int,
  count : Int,
) -> BatchResult {
  require_toolchain(config)
  let failures : Array[String] = []
  for case_index in 0..<count {
    let seed = first_seed + case_index * 101
    let tag = "[\{case_index}]"
    try {
      for failure in config.run_case(seed, tag) {
        failures.push(failure)
      }
    } catch {
      err =>
        if config.continue_on_error {
          let summary = "wrapper error seed=\{seed} case=\{tag} error=\{err}"
          @stdio.stderr.write(
            "csmith \{tag} seed=\{seed} error=\{err}; continuing\n",
          )
          failures.push(summary)
        } else {
          raise err
        }
    }
  }
  { failures, }
}
