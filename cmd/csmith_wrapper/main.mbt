///|
fn command() -> @argparse.Command {
  @argparse.Command(
    "csmith-wrapper",
    about="Run Csmith differential fuzzing across compiler commands.",
    flags=[
      @argparse.FlagArg(
        "no-save-counterexamples",
        about="do not write counterexample C files; print failing seeds only",
        action=@argparse.SetTrue,
      ),
      @argparse.FlagArg(
        "continue-on-error",
        about="continue with later seeds after a per-case wrapper error",
        action=@argparse.SetTrue,
      ),
    ],
    options=[
      @argparse.OptionArg(
        "seed",
        about="first Csmith seed",
        default_values=[@fuzz.DEFAULT_SEED.to_string()],
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg(
        "count",
        about="number of cases to run",
        default_values=[@fuzz.DEFAULT_COUNT.to_string()],
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg(
        "reference",
        about="reference compiler spec",
        default_values=[@fuzz.default_reference_spec()],
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg(
        "compiler",
        about="compiler spec to compare; repeat for multiple compilers",
        action=@argparse.Append,
        default_values=@fuzz.default_compiler_specs(),
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg(
        "counterexample-dir",
        about="directory for saved counterexample C files",
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg(
        "include-root",
        about="directory containing csmith.h",
        allow_hyphen_values=true,
      ),
    ],
  )
}

///|
fn option_value(matches : @argparse.Matches, name : String) -> String raise {
  match matches.values.get(name) {
    Some(values) if values.length() > 0 => values[0]
    _ => raise @fuzz.MissingOption(name)
  }
}

///|
fn option_values(matches : @argparse.Matches, name : String) -> Array[String] {
  match matches.values.get(name) {
    Some(values) => values
    _ => []
  }
}

///|
fn option_value_or_none(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) if values.length() > 0 => Some(values[0])
    _ => None
  }
}

///|
fn flag_value(matches : @argparse.Matches, name : String) -> Bool {
  match matches.flags.get(name) {
    Some(value) => value
    None => false
  }
}

///|
fn int_option(matches : @argparse.Matches, name : String) -> Int raise {
  let value = option_value(matches, name)
  @string.parse_int(value) catch {
    _ => raise @fuzz.InvalidIntOption(name, value)
  }
}

///|
async fn run() -> Unit {
  let matches = command().parse()
  let seed = int_option(matches, "seed")
  let count = int_option(matches, "count")
  if count < 0 {
    raise @fuzz.NegativeCount(count)
  }
  let counterexample_dir = if flag_value(matches, "no-save-counterexamples") {
    None
  } else {
    match option_value_or_none(matches, "counterexample-dir") {
      Some(path) => Some(path)
      None => @fuzz.default_counterexample_dir()
    }
  }
  let config = @fuzz.config_from_specs(
    option_value(matches, "reference"),
    option_values(matches, "compiler"),
    option_value(matches, "include-root"),
    counterexample_dir,
    flag_value(matches, "continue-on-error"),
  )
  let result = @fuzz.run_batch(config, seed, count)
  if result.failures.length() > 0 {
    raise @fuzz.AbnormalCases(result.failures)
  }
}

///|
async fn main {
  run() catch {
    err => {
      @stdio.stderr.write("\{err}\n")
      @sys.exit(1)
    }
  }
}
