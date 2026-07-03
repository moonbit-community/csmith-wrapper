///|
priv struct CsmithReport {
  command : CommandLine
  flags : Array[String]
} derive(ToJson, FromJson)

///|
priv struct TimeoutReport {
  compile_seconds : Int
  run_seconds : Int
} derive(ToJson, FromJson)

///|
priv struct ManifestReport[D] {
  tag : String
  seed : Int
  stage : String
  csmith : CsmithReport
  timeouts : TimeoutReport
  include_root : String
  reference : ShellCompiler
  compilers : Array[ShellCompiler]
  record_root : String
  counterexample_dir : String?
  continue_on_error : Bool
  details : D
} derive(ToJson, FromJson)

///|
priv struct RunReport {
  name : String
  slug : String
  preprocessed_path : String
  result : CommandResult
  checksum : String
} derive(ToJson, FromJson)

///|
priv struct FailureReport {
  name : String
  slug : String
  stage : String
  stage_slug : String
  bug_source_path : String
  has_preprocessed_path : Bool
  preprocessed_path : String
  result : CommandResult
} derive(ToJson, FromJson)

///|
priv struct AbnormalReport[D] {
  stage : String
  compiler : String
  counterexample_path : String?
  details : D
} derive(ToJson, FromJson)

///|
priv struct ReferenceFailureDetails {
  discarded : Bool
  reason : String
  failure : FailureReport
} derive(ToJson, FromJson)

///|
priv struct ReferenceTimeoutDetails {
  discarded : Bool
  reason : String
  reference : RunReport
} derive(ToJson, FromJson)

///|
priv struct CandidateFailureDetails {
  reference : RunReport
  compiler_failure : FailureReport
} derive(ToJson, FromJson)

///|
priv struct CandidateRunDetails {
  reference : RunReport
  compiler : RunReport
} derive(ToJson, FromJson)

///|
priv struct AbnormalCaseSummary {
  summary : String
} derive(ToJson, FromJson)

///|
priv struct AbnormalCasesReport {
  abnormal_cases : Array[AbnormalCaseSummary]
} derive(ToJson, FromJson)

///|
fn CompilerRun::report(self : CompilerRun) -> RunReport {
  {
    name: self.name,
    slug: self.slug,
    preprocessed_path: self.preprocessed_path,
    result: self.result,
    checksum: output_checksum(self.result.output),
  }
}

///|
fn CompilerFailure::report(self : CompilerFailure) -> FailureReport {
  match self.preprocessed_path {
    Some(path) =>
      {
        name: self.name,
        slug: self.slug,
        stage: self.stage,
        stage_slug: self.stage_slug,
        bug_source_path: self.bug_source_path,
        has_preprocessed_path: true,
        preprocessed_path: path,
        result: self.result,
      }
    None =>
      {
        name: self.name,
        slug: self.slug,
        stage: self.stage,
        stage_slug: self.stage_slug,
        bug_source_path: self.bug_source_path,
        has_preprocessed_path: false,
        preprocessed_path: "",
        result: self.result,
      }
  }
}

///|
async fn[D : ToJson + FromJson] CaseContext::write_common_record(
  self : CaseContext,
  stage : String,
  details : D,
) -> Unit {
  ensure_dir(self.record_dir)
  let source_path = self.path("source", ".c")
  @fs.write_file(
    @path.Path::join(self.record_dir, "source.c").to_string(),
    @fs.read_file(source_path).text(),
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    @path.Path::join(self.record_dir, "compat.h").to_string(),
    compat_header_source(),
    create_mode=CreateOrTruncate,
  )
  let manifest = ManifestReport::{
    tag: self.tag,
    seed: self.seed,
    stage,
    csmith: { command: self.config.csmith_command, flags: csmith_flags() },
    timeouts: {
      compile_seconds: COMPILE_TIMEOUT_SEC,
      run_seconds: RUN_TIMEOUT_SEC,
    },
    include_root: self.config.include_root,
    reference: self.config.reference,
    compilers: self.config.compilers,
    record_root: self.config.record_root,
    counterexample_dir: self.config.counterexample_dir,
    continue_on_error: self.config.continue_on_error,
    details,
  }
  write_json_file(
    @path.Path::join(self.record_dir, "manifest.json").to_string(),
    manifest,
  )
}

///|
async fn CaseContext::copy_text_to_record(
  self : CaseContext,
  source : String,
  name : String,
) -> Unit {
  if @fs.exists(source) {
    @fs.write_file(
      @path.Path::join(self.record_dir, name).to_string(),
      @fs.read_file(source).text(),
      create_mode=CreateOrTruncate,
    )
  }
}

///|
async fn CaseContext::record_run_artifact(
  self : CaseContext,
  run : CompilerRun,
) -> Unit {
  self.copy_text_to_record(run.preprocessed_path, "\{run.slug}_preprocessed.i")
  @fs.write_file(
    @path.Path::join(self.record_dir, "\{run.slug}.out").to_string(),
    run.result.output,
    create_mode=CreateOrTruncate,
  )
}

///|
async fn CaseContext::record_failure_artifact(
  self : CaseContext,
  failure : CompilerFailure,
) -> Unit {
  match failure.preprocessed_path {
    Some(path) =>
      self.copy_text_to_record(path, "\{failure.slug}_preprocessed.i")
    None => ()
  }
}

///|
async fn[D : ToJson + FromJson] CaseContext::record_abnormal(
  self : CaseContext,
  stage : String,
  stage_slug : String,
  compiler_name : String,
  bug_source_path : String,
  details : D,
) -> String {
  let counterexample_path = match self.config.counterexample_dir {
    Some(dir) => {
      ensure_dir(dir)
      let path = @path.Path::join(
        dir,
        "csmith_seed_\{self.seed}_\{stage_slug}.c",
      ).to_string()
      @fs.write_file(
        path,
        @fs.read_file(bug_source_path).text(),
        create_mode=CreateOrTruncate,
      )
      self.log("saved \{path}")
      Some(path)
    }
    None => {
      self.log(
        "counterexample seed=\{self.seed} compiler=\{compiler_name} not-saved",
      )
      None
    }
  }
  let report = AbnormalReport::{
    stage,
    compiler: compiler_name,
    counterexample_path,
    details,
  }
  match counterexample_path {
    Some(path) => {
      self.write_common_record(stage, report)
      write_json_file(
        @path.Path::join(self.record_dir, "\{stage_slug}_failure.json").to_string(),
        report,
      )
      "\{stage} seed=\{self.seed} compiler=\{compiler_name} counterexample=\{path} record=\{self.record_dir}"
    }
    None =>
      "\{stage} seed=\{self.seed} compiler=\{compiler_name} counterexample=not-saved"
  }
}

///|
fn output_checksum(output : String) -> String {
  for raw in output.split("\n") {
    for part in raw.split("\r") {
      let line = part.trim()
      match line.split_once("=") {
        Some((left, right)) if left.trim() == "checksum" =>
          return right.trim().to_owned()
        _ => ()
      }
    }
  }
  "<missing>"
}

///|
fn runtime_mismatch_report(
  reference : CompilerRun,
  candidate : CompilerRun,
) -> (String, CandidateRunDetails, String, String) {
  let reference_checksum = output_checksum(reference.result.output)
  let candidate_checksum = output_checksum(candidate.result.output)
  let stage = "runtime mismatch reference=\{reference.name} compiler=\{candidate.name} reference-checksum=\{reference_checksum} compiler-checksum=\{candidate_checksum}"
  let details = { reference: reference.report(), compiler: candidate.report() }
  (stage, details, reference_checksum, candidate_checksum)
}

///|
async fn CaseContext::record_reference_failure(
  self : CaseContext,
  failure : CompilerFailure,
) -> Unit {
  let details = ReferenceFailureDetails::{
    discarded: true,
    reason: "reference \{failure.stage}",
    failure: failure.report(),
  }
  self.write_common_record("\{failure.stage} discarded", details)
  self.record_failure_artifact(failure)
  self.log("skip reference-\{failure.stage_slug} record=\{self.record_dir}")
}

///|
async fn CaseContext::record_reference_timeout(
  self : CaseContext,
  reference : CompilerRun,
) -> Unit {
  let details = ReferenceTimeoutDetails::{
    discarded: true,
    reason: "reference run timeout",
    reference: reference.report(),
  }
  self.write_common_record("reference run timeout discarded", details)
  self.record_run_artifact(reference)
  self.log("discard reference-run-timeout record=\{self.record_dir}")
}

///|
async fn CaseContext::record_candidate_failure(
  self : CaseContext,
  reference : CompilerRun,
  failure : CompilerFailure,
) -> String {
  let details = CandidateFailureDetails::{
    reference: reference.report(),
    compiler_failure: failure.report(),
  }
  let failure_summary = self.record_abnormal(
    failure.stage,
    failure.stage_slug,
    failure.name,
    failure.bug_source_path,
    details,
  )
  match self.config.counterexample_dir {
    Some(_) => {
      self.record_run_artifact(reference)
      self.record_failure_artifact(failure)
    }
    None => ()
  }
  failure_summary
}

///|
async fn CaseContext::record_candidate_timeout(
  self : CaseContext,
  reference : CompilerRun,
  candidate : CompilerRun,
) -> String {
  let details = CandidateRunDetails::{
    reference: reference.report(),
    compiler: candidate.report(),
  }
  let failure = self.record_abnormal(
    "\{candidate.name} run timeout",
    "\{candidate.slug}_run_timeout",
    candidate.name,
    candidate.preprocessed_path,
    details,
  )
  match self.config.counterexample_dir {
    Some(_) => {
      self.record_run_artifact(reference)
      self.record_run_artifact(candidate)
    }
    None => ()
  }
  failure
}

///|
async fn CaseContext::record_candidate_mismatch(
  self : CaseContext,
  reference : CompilerRun,
  candidate : CompilerRun,
) -> String {
  let (stage, details, reference_checksum, candidate_checksum) = runtime_mismatch_report(
    reference, candidate,
  )
  self.log(
    "mismatch reference=\{reference.name} compiler=\{candidate.name} reference-checksum=\{reference_checksum} compiler-checksum=\{candidate_checksum}",
  )
  let failure = self.record_abnormal(
    stage,
    "\{candidate.slug}_runtime_mismatch",
    candidate.name,
    candidate.preprocessed_path,
    details,
  )
  match self.config.counterexample_dir {
    Some(_) => {
      self.record_run_artifact(reference)
      self.record_run_artifact(candidate)
    }
    None => ()
  }
  failure
}

///|
pub fn format_failures(failures : Array[String]) -> String {
  let cases : Array[AbnormalCaseSummary] = []
  for failure in failures {
    cases.push({ summary: failure })
  }
  stringify_report(AbnormalCasesReport::{ abnormal_cases: cases })
}
