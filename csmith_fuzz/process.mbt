///|
async fn ensure_dir(path : String) -> Unit {
  if !@fs.exists(path) {
    @fs.mkdir(path, recursive=true)
  }
}

///|
fn[T : ToJson + FromJson] stringify_report(value : T) -> String {
  let json = value.to_json()
  let _roundtrip : T = @json.from_json(json) catch { _ => value }
  json.stringify(indent=2)
}

///|
async fn[T : ToJson + FromJson] write_json_file(
  path : String,
  value : T,
) -> Unit {
  @fs.write_file(
    path,
    stringify_report(value) + "\n",
    create_mode=CreateOrTruncate,
  )
}

///|
async fn run_command_checked_timed(
  cmd : CommandLine,
  timeout_seconds : Int,
  context : String,
  cwd? : String,
) -> Unit {
  let rc = run_command_with_timeout(cmd, timeout_seconds, cwd?)
  if rc != 0 {
    raise CommandFailed(context, rc)
  }
}

///|
async fn run_command_with_timeout(
  cmd : CommandLine,
  timeout_seconds : Int,
  cwd? : String,
) -> Int {
  match
    @async.with_timeout_opt(timeout_seconds * 1000, () => {
      match cwd {
        Some(dir) => @process.run(cmd.program, cmd.args, cwd=dir)
        None => @process.run(cmd.program, cmd.args)
      }
    }) {
    Some(rc) => rc
    None => 124
  }
}

///|
async fn run_command_capture(
  cmd : CommandLine,
  timeout_seconds : Int,
  cwd? : String,
) -> CommandResult {
  match
    @async.with_timeout_opt(timeout_seconds * 1000, () => {
      match cwd {
        Some(dir) =>
          @process.collect_output_merged(cmd.program, cmd.args, cwd=dir)
        None => @process.collect_output_merged(cmd.program, cmd.args)
      }
    }) {
    Some((rc, data)) =>
      { code: rc, timed_out: timed_out(rc), output: data.text() }
    None =>
      {
        code: 124,
        timed_out: true,
        output: "timed out after \{timeout_seconds} seconds\n",
      }
  }
}

///|
fn source_id(source : String) -> String {
  let mut h = 0
  for ch in source {
    h = h * 31 + ch.to_int()
  }
  h.to_string()
}

///|
fn temp_file_path(prefix : String, seed : String, suffix : String) -> String {
  @path.Path::join(
    env("TMPDIR").unwrap_or("."),
    "csmith_\{prefix}_\{source_id(seed)}\{suffix}",
  ).to_string()
}
