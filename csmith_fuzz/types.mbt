///|
pub(all) struct Config {
  csmith_command : CommandLine
  include_root : String
  record_root : String
  counterexample_dir : String?
  continue_on_error : Bool
  reference : ShellCompiler
  compilers : Array[ShellCompiler]
}

///|
pub(all) struct BatchResult {
  failures : Array[String]
}

///|
priv struct CommandResult {
  code : Int32
  timed_out : Bool
  output : String
} derive(ToJson, FromJson)

///|
priv struct CaseContext {
  config : Config
  seed : Int32
  tag : String
  prefix : String
  record_dir : String
}

///|
priv struct CompilerRun {
  name : String
  slug : String
  preprocessed_path : String
  result : CommandResult
}

///|
priv struct CompilerFailure {
  name : String
  slug : String
  stage : String
  stage_slug : String
  bug_source_path : String
  preprocessed_path : String?
  result : CommandResult
}

///|
priv enum CompilerOutcome {
  CompilerOk(CompilerRun)
  CompilerFailed(CompilerFailure)
}

///|
pub const DEFAULT_SEED : Int32 = 7

///|
pub const DEFAULT_COUNT : Int32 = 20

///|
const COMPILE_TIMEOUT_SEC : Int32 = 30

///|
const RUN_TIMEOUT_SEC : Int32 = 20
