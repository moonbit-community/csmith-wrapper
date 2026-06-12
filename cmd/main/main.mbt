///|
fn command() -> @argparse.Command {
  @argparse.Command(
    "csmith-wrapper",
    about="Run Csmith differential fuzzing across compiler commands.",
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
  let config = @fuzz.config_from_specs(
    option_value(matches, "reference"),
    option_values(matches, "compiler"),
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
