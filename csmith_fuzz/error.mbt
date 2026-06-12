///|
pub(all) suberror WrapperError {
  MissingOption(String)
  InvalidIntOption(String, String)
  NegativeCount(Int)
  EmptyCompilerCommand(String)
  NoCompilers
  MissingIncludeRoot(String)
  CommandFailed(String, Int)
  AbnormalCases(Array[String])
} derive(Debug)

///|
pub impl Show for WrapperError with fn to_string(self) {
  match self {
    MissingOption(name) => "error: missing parsed option: --\{name}"
    InvalidIntOption(name, value) => "error: invalid --\{name}: \{value}"
    NegativeCount(count) => "error: --count must be non-negative, got \{count}"
    EmptyCompilerCommand(spec) =>
      "error: compiler command cannot be empty in spec: \{spec}"
    NoCompilers => "error: at least one --compiler is required"
    MissingIncludeRoot(description) =>
      "error: csmith include root missing: \{description}"
    CommandFailed(context, code) =>
      "error: \{context} failed with code: \{code}"
    AbnormalCases(failures) => format_failures(failures)
  }
}
