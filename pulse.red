// redpulse: a small project-health radar for Red workspaces.
//
// This utility is intentionally written in pure Red. It walks a workspace,
// reads Red source files, and turns the shape of the code into a quick signal:
// code/comment/blank balance, declarations, TODOs, and the largest files.

const VERSION = "0.1.0";
const EXIT_USAGE = 64;
const EXIT_INPUT = 74;

class FilePulse {
  init(path, lines, code, comments, blanks, functions, classes, imports,
       todos, long_lines) {
    this.path = path;
    this.lines = lines;
    this.code = code;
    this.comments = comments;
    this.blanks = blanks;
    this.functions = functions;
    this.classes = classes;
    this.imports = imports;
    this.todos = todos;
    this.long_lines = long_lines;
  }
}

class WorkspacePulse {
  init(root) {
    this.root = root;
    this.files = [];
    this.todo_items = [];
    this.errors = [];
    this.lines = 0;
    this.code = 0;
    this.comments = 0;
    this.blanks = 0;
    this.functions = 0;
    this.classes = 0;
    this.imports = 0;
    this.todos = 0;
    this.long_lines = 0;
  }

  add(file) {
    this.files.push(file);
    this.lines += file.lines;
    this.code += file.code;
    this.comments += file.comments;
    this.blanks += file.blanks;
    this.functions += file.functions;
    this.classes += file.classes;
    this.imports += file.imports;
    this.todos += file.todos;
    this.long_lines += file.long_lines;
  }
}

fun usage() {
  return "Usage: redpulse [options] [directory]\n\n" +
    "Read Red source files and show a compact project-health radar.\n\n" +
    "Options:\n" +
    "  -h, --help       show this message\n" +
    "      --version    print the version\n" +
    "      --json       emit machine-readable JSON\n" +
    "      --todos      show TODO and FIXME notes\n" +
    "      --hotspots   show the five largest source files\n" +
    "\n" +
    "The default directory is the current working directory. Hidden folders,\n" +
    "build artifacts, and vendored dependencies are skipped automatically.";
}

fun join_path(parent, child) {
  if (parent.ends_with("/")) { return parent + child; }
  return parent + "/" + child;
}

fun skip_directory(name) {
  if (name.starts_with(".")) { return true; }
  return name == "build" or name == "build-asan" or name == "target" or
    name == "node_modules" or name == "vendor" or name == "dist" or
    name == "out";
}

fun short_line(line) {
  if (line.len() <= 96) { return line; }
  return line.sub(0, 93) + "...";
}

fun scan_file(path, display, workspace) {
  const text = read_file(path);
  if (text == nil) {
    workspace.errors.push("cannot read ${display}");
    return;
  }

  let lines = 0;
  let code = 0;
  let comments = 0;
  let blanks = 0;
  let functions = 0;
  let classes = 0;
  let imports = 0;
  let todos = 0;
  let long_lines = 0;
  let line_number = 0;

  for (let line in text.split("\n")) {
    line_number += 1;
    lines += 1;
    const trimmed = line.trim();

    if (trimmed == "") {
      blanks += 1;
      continue;
    }
    if (trimmed.starts_with("//")) { comments += 1; }
    else { code += 1; }

    if (trimmed.starts_with("fun ")) { functions += 1; }
    if (trimmed.starts_with("class ")) { classes += 1; }
    if (trimmed.starts_with("import ")) { imports += 1; }
    if (line.len() > 100) { long_lines += 1; }

    if (line.contains("TODO:") or line.contains("FIXME:")) {
      todos += 1;
      workspace.todo_items.push("${display}:${line_number}: ${short_line(trimmed)}");
    }
  }

  workspace.add(FilePulse(display, lines, code, comments, blanks, functions,
    classes, imports, todos, long_lines));
}

fun scan_directory(path, display, workspace) {
  const entries = list_dir(path);
  if (entries == nil) {
    workspace.errors.push("cannot open directory ${display}");
    return;
  }

  for (let name in entries) {
    const child = join_path(path, name);
    const shown = join_path(display, name);
    if (is_dir(child)) {
      if (!skip_directory(name)) { scan_directory(child, shown, workspace); }
    } else if (is_file(child) and name.ends_with(".red")) {
      scan_file(child, shown, workspace);
    }
  }
}

fun json_quote(text) {
  return "\"" + text.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
}

fun json_report(report) {
  const files = [];
  for (let file in report.files) {
    files.push("{" +
      "\"path\": " + json_quote(file.path) + ", " +
      "\"lines\": " + str(file.lines) + ", " +
      "\"code\": " + str(file.code) + ", " +
      "\"comments\": " + str(file.comments) + ", " +
      "\"blanks\": " + str(file.blanks) + ", " +
      "\"functions\": " + str(file.functions) + ", " +
      "\"classes\": " + str(file.classes) + ", " +
      "\"imports\": " + str(file.imports) + ", " +
      "\"todos\": " + str(file.todos) + ", " +
      "\"long_lines\": " + str(file.long_lines) + "}");
  }

  const notes = [];
  for (let note in report.todo_items) { notes.push(json_quote(note)); }
  return "{" +
    "\"version\": " + json_quote(VERSION) + ", " +
    "\"root\": " + json_quote(report.root) + ", " +
    "\"files\": " + str(report.files.len()) + ", " +
    "\"lines\": " + str(report.lines) + ", " +
    "\"code\": " + str(report.code) + ", " +
    "\"comments\": " + str(report.comments) + ", " +
    "\"blanks\": " + str(report.blanks) + ", " +
    "\"functions\": " + str(report.functions) + ", " +
    "\"classes\": " + str(report.classes) + ", " +
    "\"imports\": " + str(report.imports) + ", " +
    "\"todos\": " + str(report.todos) + ", " +
    "\"long_lines\": " + str(report.long_lines) + ", " +
    "\"todo_items\": [" + notes.join(", ") + "], " +
    "\"file_details\": [" + files.join(", ") + "]}";
}

fun bar(value, total, width) {
  if (total == 0) { return ""; }
  let filled = int((value * width) / total);
  if (filled > width) { filled = width; }
  let result = "";
  for (let i in range(0, filled)) { result += "#"; }
  for (let i in range(filled, width)) { result += "."; }
  return result;
}

fun health_score(report) {
  let score = 100 - report.todos * 4 - report.long_lines;
  if (report.files == 0) { return 0; }
  if (score < 0) { return 0; }
  return score;
}

fun print_hotspots(report) {
  if (report.files.len() == 0) { return; }
  const ordered = report.files.sort(fun (a, b) {
    if (a.code == b.code) { return a.path < b.path; }
    return a.code > b.code;
  });
  print("");
  print("HOTSPOTS");
  let rank = 1;
  for (let file in ordered) {
    if (rank > 5) { break; }
    print("  ${rank}. ${str(file.code).pad_left(5)} code  ${file.path}");
    rank += 1;
  }
}

fun print_todos(report) {
  print("");
  print("NOTES");
  if (report.todo_items.len() == 0) {
    print("  no TODO or FIXME markers found");
    return;
  }
  for (let note in report.todo_items) { print("  " + note); }
}

fun print_table(report, show_todos, show_hotspots) {
  const score = health_score(report);
  print("REDPULSE ${VERSION}");
  print("workspace  ${report.root}");
  print("");
  print("signal     ${score}/100  [${bar(score, 100, 24)}]");
  print("files      ${report.files.len()}");
  print("lines      ${report.lines}  (${report.code} code, ${report.comments} comments, ${report.blanks} blank)");
  print("shape      ${report.functions} functions  ${report.classes} classes  ${report.imports} imports");
  print("friction   ${report.todos} TODO/FIXME  ${report.long_lines} long lines");

  if (report.files.len() == 0) {
    print("");
    print("No .red files found. Point redpulse at a workspace or source tree.");
  }
  if (show_hotspots) { print_hotspots(report); }
  if (show_todos) { print_todos(report); }
  for (let problem in report.errors) { eprint("redpulse: " + problem); }
}

fun parse_options(argv) {
  const options = {"root": cwd(), "json": false, "todos": false,
    "hotspots": false, "help": false, "version": false, "error": nil};
  let i = 0;
  let positional = [];
  while (i < argv.len()) {
    const arg = argv[i];
    i += 1;
    switch (arg) {
      case "-h":
      case "--help": options["help"] = true;
      case "--version": options["version"] = true;
      case "--json": options["json"] = true;
      case "--todos": options["todos"] = true;
      case "--hotspots": options["hotspots"] = true;
      default:
        if (arg.starts_with("-")) {
          options["error"] = "unknown option '${arg}'";
        } else { positional.push(arg); }
    }
  }
  if (positional.len() > 1) {
    options["error"] = "expected one directory, got ${positional.len()}";
  } else if (positional.len() == 1) {
    options["root"] = positional[0];
  }
  return options;
}

fun main() {
  const options = parse_options(args());
  if (options["error"] != nil) {
    eprint("redpulse: ${options["error"]}");
    eprint("");
    eprint(usage());
    return EXIT_USAGE;
  }
  if (options["help"]) { print(usage()); return 0; }
  if (options["version"]) { print("redpulse ${VERSION}"); return 0; }

  const root = options["root"];
  if (!is_dir(root)) {
    eprint("redpulse: '${root}' is not a directory");
    return EXIT_INPUT;
  }

  const report = WorkspacePulse(root);
  scan_directory(root, ".", report);
  if (options["json"]) { print(json_report(report)); }
  else { print_table(report, options["todos"], options["hotspots"]); }
  if (report.errors.len() > 0) { return EXIT_INPUT; }
  return 0;
}

const status = main();
if (status != 0) { exit(status); }
