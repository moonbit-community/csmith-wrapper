///|
pub trait Compiler {
  fn name(Self) -> String
  fn slug(Self) -> String
  fn preprocess_command(Self, String, String, String, String) -> CommandLine
  fn compile_command(Self, String, String) -> CommandLine
}

///|
pub(all) struct CommandLine {
  program : String
  args : Array[String]
} derive(ToJson, FromJson)

///|
pub(all) struct ShellCompiler {
  name : String
  command : CommandLine
} derive(ToJson, FromJson)

///|
pub impl Show for CommandLine with fn to_string(self) {
  self.display()
}

///|
pub impl Compiler for ShellCompiler with fn name(self) {
  self.name
}

///|
pub impl Compiler for ShellCompiler with fn slug(self) {
  slugify(self.name)
}

///|
pub impl Compiler for ShellCompiler with fn preprocess_command(
  self,
  include_dir,
  source_path,
  preprocessed_path,
  compat_path,
) {
  self.command.append([
    "-w", "-E", "-P", "-DCSMITH_MINIMAL", "-I", include_dir, "-include", compat_path,
    source_path, "-o", preprocessed_path,
  ])
}

///|
pub impl Compiler for ShellCompiler with fn compile_command(
  self,
  preprocessed_path,
  output_path,
) {
  self.command.append(["-w", "-o", output_path, preprocessed_path])
}

///|
pub fn parse_compiler_spec(spec : String) -> ShellCompiler raise WrapperError {
  let (name, command_spec) = split_spec_name(spec)
  let command = parse_command_line(command_spec)
  { name: name.unwrap_or(default_compiler_name(command)), command }
}

///|
pub fn parse_command_line(spec : String) -> CommandLine raise WrapperError {
  let words = split_non_empty(spec, " ")
  if words.length() == 0 {
    raise EmptyCompilerCommand(spec)
  }
  let args : Array[String] = []
  for index in 1..<words.length() {
    args.push(words[index])
  }
  { program: words[0], args }
}

///|
fn split_spec_name(spec : String) -> (String?, String) {
  match spec.split_once("=") {
    Some((left, right)) => {
      let name = left.trim()
      let rest = right.trim()
      if is_spec_name(name.to_owned()) && rest != "" {
        (Some(name.to_owned()), rest.to_owned())
      } else {
        (None, spec.trim().to_owned())
      }
    }
    None => (None, spec.trim().to_owned())
  }
}

///|
fn default_compiler_name(command : CommandLine) -> String {
  let name = last_path_segment(command.program)
  if name == "" {
    "compiler"
  } else {
    name
  }
}

///|
fn CommandLine::append(
  self : CommandLine,
  extra : Array[String],
) -> CommandLine {
  let args : Array[String] = [..self.args, ..extra]
  { program: self.program, args }
}

///|
fn CommandLine::display(self : CommandLine) -> String {
  let output = StringBuilder::new()
  output.write_string(self.program)
  for arg in self.args {
    output.write_char(' ')
    output.write_string(arg)
  }
  output.to_string()
}

///|
fn is_spec_name(value : String) -> Bool {
  if value == "" {
    return false
  }
  for ch in value {
    if !is_spec_name_char(ch) {
      return false
    }
  }
  true
}

///|
fn is_spec_name_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 45 ||
  code == 46 ||
  code == 95
}

///|
fn last_path_segment(path : String) -> String {
  let mut last = path
  for part in last.split("/") {
    last = part.to_owned()
  }
  last
}

///|
fn split_non_empty(input : String, sep : String) -> Array[String] {
  let parts : Array[String] = []
  for part in input.split(sep) {
    let item = part.trim()
    if item != "" {
      parts.push(item.to_owned())
    }
  }
  parts
}

///|
fn slugify(value : String) -> String {
  let buf = StringBuilder::new()
  for ch in value {
    if is_spec_name_char(ch) {
      buf.write_char(ch)
    } else {
      buf.write_char('_')
    }
  }
  let slug = buf.to_string()
  if slug == "" {
    "compiler"
  } else {
    slug
  }
}
