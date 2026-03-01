# agent-assembly

[![CI](https://github.com/LPASK/agent-assembly/actions/workflows/ci.yml/badge.svg)](https://github.com/LPASK/agent-assembly/actions/workflows/ci.yml)

A build system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and compatible agent CLIs. Assemble per-project agent context from modular profile components, and maintain a cross-project memory layer.

## The Problem

As you use Claude Code across more projects, the global user-level config becomes increasingly awkward:

1. **Different projects need different sides of you.** A coding project needs your technical background and style preferences. A research project needs your reading interests and cognitive patterns. A single global config either carries too much noise or not enough context.
2. **Some things belong to the person, not the project.** Goals, time allocation, periodic reviews, personal growth patterns — these cut across projects. But Claude Code's memory model is per-project: each agent only sees what happened in its own directory.

## How It Works

Two ideas:

1. **Assemble, don't broadcast.** Break your profile into modules (background, technical skills, cognitive patterns, goals, ...). Each project's launcher picks the modules it needs — no more, no less. The launcher *is* the configuration.
2. **A cross-project memory layer.** Maintain a shared `memory/` directory. Personal reflections, goal tracking, weekly reviews, and anything that isn't project-specific accumulates here, accessible from any session via `--add-dir`.

```
agent-assembly/
├── launchers/           # Per-project launch scripts
│   ├── lib.sh           # Pipeline library (5 functions)
│   └── example-mac-claude.sh
├── modules/             # Profile components (source of truth)
│   ├── core-behavior.md      # Agent behavior (sample)
│   ├── profile-technical.md  # Technical background (sample)
│   ├── profile-goals.md      # Goals tracking (sample)
│   ├── memory-system.md      # Memory rules (sample)
│   └── operating-principles.md  # (sample)
├── hooks/               # Hook scripts injected into sessions
│   └── prompt-guard.sh  # Action check + memory alarm
├── memory/              # Cross-project session logs
├── tests/               # Regression tests
├── SPEC.md              # System specification
└── CLAUDE.md            # Agent entry point
```

## Pipeline

Every launcher runs the same pipeline:

```
assemble_modules → assemble_hooks → assemble_skills → ensure_gitignore → launch
```

| Step | What it does | Output |
|------|-------------|--------|
| `assemble_modules` | Concatenates selected modules into one file | `TARGET/CLAUDE.local.md` |
| `assemble_hooks` | Generates hook config from scripts | `TARGET/.claude/settings.local.json` |
| `assemble_skills` | Symlinks skills into target | `TARGET/.claude/skills/*` |
| `ensure_gitignore` | Ensures generated files are gitignored | Appends to `TARGET/.gitignore` |
| `launch` | Opens CLI in the target directory | — |

All generated artifacts are gitignored in the target project. The target project's own `CLAUDE.md` is untouched.

## Quick Start

### 1. Clone

```bash
git clone https://github.com/LPASK/agent-assembly.git ~/agent-assembly
cd ~/agent-assembly
```

### 2. Write your modules

The files in `modules/` are **samples with fake data**. They demonstrate the format and structure — don't use them as-is. Have your agent rewrite each file with your real information, or write them yourself.

- `profile-technical.md` — technical background, skills, priorities
- `profile-goals.md` — active commitments and progress tracking
- `core-behavior.md` — how you want the agent to think and act
- `memory-system.md` — rules for what gets recorded and how
- `operating-principles.md` — general working principles

Add more modules as needed (e.g. `profile-cognitive.md`, `profile-health.md`). Each module is a self-contained markdown file — different projects can assemble different subsets.

### 3. Create a launcher

```bash
cp launchers/example-mac-claude.sh launchers/my-project.sh
```

Edit it — set `TARGET` to your project path, choose which modules to assemble:

```bash
#!/bin/bash
source "$(dirname "$0")/lib.sh"

CLI="${CLI:-claude}"
TARGET="$HOME/my-project"

assemble_modules "$TARGET" \
  core-behavior.md \
  profile-technical.md \
  profile-goals.md \
  memory-system.md operating-principles.md

assemble_hooks "$TARGET" prompt-guard.sh
ensure_gitignore "$TARGET"
launch "$CLI" "$TARGET"
```

A different project might only need a subset:

```bash
assemble_modules "$TARGET" \
  core-behavior.md \
  profile-technical.md   # just the basics — no goals, no memory system
```

### 4. Launch

```bash
bash ~/agent-assembly/launchers/my-project.sh

# Override the CLI binary:
CLI=claude bash ~/agent-assembly/launchers/my-project.sh
```

## Design Decisions

**The launcher is the configuration.** No YAML config files. Each launcher is a short bash script that calls pipeline functions with the modules it needs. Adding a project = copying a launcher and changing the target path and module list.

**Modules are the single source of truth.** Your profile, goals, and behavior rules live in `modules/`. They're assembled into `CLAUDE.local.md` at launch time. The generated file is overwritten on every launch — never hand-edit it.

**Cross-project memory is opt-in.** Launchers can pass `--add-dir ~/agent-assembly/memory` to give the agent read/write access to the shared memory directory. Project-specific memory stays in the project; personal/cross-project memory goes here.

**Hooks are deterministic guards.** The included `prompt-guard.sh` fires on every user prompt, injecting a goal-alignment check for substantive messages and a memory staleness alarm. Write your own hooks for other lifecycle events.

**Generated artifacts are ephemeral.** `CLAUDE.local.md`, `.claude/settings.local.json`, and `.claude/skills/` in the target project are all generated, gitignored, and overwritten on every launch.

## Extending

**New module**: Create `modules/my-module.md`, add the filename to your launcher's `assemble_modules` call.

**New hook**: Create `hooks/my-hook.sh` (receives JSON on stdin, outputs JSON to stdout), add the filename to your launcher's `assemble_hooks` call.

**New project**: Copy an existing launcher, change `TARGET` and module list.

**New skill**: Create `.claude/skills/my-skill/SKILL.md`, add to your launcher's `assemble_skills` call.

See [SPEC.md](SPEC.md) for the complete specification.

## Testing

```bash
bash tests/run.sh
```

21 tests covering module assembly, hook generation, gitignore management, hook behavior, and documentation consistency. CI runs on both Ubuntu and macOS.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or compatible agent CLI
- bash, jq
- macOS or Linux

## License

MIT
