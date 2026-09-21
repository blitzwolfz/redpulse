# redpulse

`redpulse` is a tiny project-health radar for Red workspaces. It is written
entirely in Red and has no native extension or third-party runtime dependency.

It walks `.red` files and reports:

- source shape: files, lines, code, comments, blanks, functions, classes, and imports;
- friction signals: `TODO:`/`FIXME:` markers and lines over 100 characters;
- the largest source files, when `--hotspots` is requested;
- a compact JSON document for scripts and dashboards.

## Build

The Red interpreter is required only while building. From a Red checkout:

```bash
../Red/build/red build pulse.red -o redpulse
```

The result is a standalone executable. You can move `redpulse` anywhere; it
does not need the Red source tree or the Red interpreter at runtime.

## Use

```bash
./redpulse .
./redpulse --hotspots --todos ~/src/my-red-project
./redpulse --json . > pulse.json
```

The default command prints a human-readable signal score. The score is a
conversation starter, not a quality gate: it drops as TODO/FIXME markers and
very long lines accumulate.

## Smoke test

After building the executable:

```bash
./redpulse fixtures --hotspots --todos
./redpulse --json fixtures | grep '"files": 2'
```

The fixture intentionally contains one TODO, one import, one function in each
file, and one class, making it easy to verify the scanner by eye.
