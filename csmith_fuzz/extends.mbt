///|
pub extend CommandLine with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend CommandLine with Show::{to_string, output}

///|
pub extend CommandLine with ToJson::{to_json}

///|
pub extend ShellCompiler with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend ShellCompiler with Compiler::{
  name,
  slug,
  compile_command,
  preprocess_command,
}

///|
pub extend ShellCompiler with ToJson::{to_json}

///|
pub extend WrapperError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend WrapperError with Show::{to_string, output}
