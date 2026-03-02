# agent-assembly

[![CI](https://github.com/LPASK/agent-assembly/actions/workflows/ci.yml/badge.svg)](https://github.com/LPASK/agent-assembly/actions/workflows/ci.yml)

Your agent should know you — across every project.

[中文版](README.zh-CN.md)

## The Problem

Different projects need different sides of you. A coding project needs your technical background. A research project needs your reading interests and cognitive patterns. But your agent starts every session as a stranger — unless you copy-paste the same context everywhere.

Meanwhile, some things belong to *you*, not to any project. Goals, growth patterns, periodic reviews — these cut across repositories. Today they either live nowhere or get duplicated everywhere.

## How It Works

```
                        agent-assembly
                       ┌──────────────┐
                       │   modules/   │
                       │  ┌────────┐  │
                       │  │ profile │  │
                       │  │ goals   │  │
                       │  │ memory  │  │
                       │  │ hooks   │  │
                       │  └────────┘  │
                       └──────┬───────┘
                              │
               ┌──────────────┼──────────────┐
               ▼              ▼              ▼
          project-A      project-B      project-C
         (all modules)  (profile only)  (profile+goals)
```

- **Modular profile.** Break yourself into components — technical background, goals, cognitive patterns, behavior rules. Each project assembles only the pieces it needs.
- **Launcher = configuration.** A short bash script per project. It picks the modules, runs the pipeline, launches the agent. No YAML, no central config.
- **Shared memory layer.** A `memory/` directory accessible from any session. Personal reflections and cross-project context accumulate here.

## Get Started

```bash
git clone https://github.com/LPASK/agent-assembly.git ~/agent-assembly
cd ~/agent-assembly
```

Then launch your agent CLI here and tell it to set things up:

```bash
claude   # or your preferred agent CLI
```

> Set up agent-assembly for me. Read CLAUDE.md and SPEC.md to understand the system,
> then walk me through writing my modules and creating my first launcher.

Your agent will read the docs, interview you about your background, and generate everything. You just answer questions.

### Agent Setup Guide

If you're an agent helping a human set up this project, here's the sequence:

1. **Read** `CLAUDE.md` and `SPEC.md` to understand the full system.
2. **Rewrite modules.** The files in `modules/` are samples with fake data. Interview the user about their background, goals, and preferences, then rewrite each module with real information.
3. **Create a launcher.** Copy `launchers/example-mac-claude.sh` to a new file named after the user's first project. Set `TARGET` to their project path and select the modules they need. See the Pipeline section below for what each function does.
4. **Test it.** Run `bash tests/run.sh` to verify everything works.
5. **Launch.** Run the new launcher script to start an assembled session.

---

*Something not working?* [Open an issue.](https://github.com/LPASK/agent-assembly/issues)
*Finding it useful?* [Star the repo](https://github.com/LPASK/agent-assembly) — it helps others find it.

---

## Reference

Everything below is reference material for developers and agents.

### Pipeline

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

### Design Decisions

**The launcher is the configuration.** No YAML config files. Each launcher is a short bash script that calls pipeline functions with the modules it needs. Adding a project = copying a launcher and changing the target path and module list.

**Modules are the single source of truth.** Your profile, goals, and behavior rules live in `modules/`. They're assembled into `CLAUDE.local.md` at launch time. The generated file is overwritten on every launch — never hand-edit it.

**Cross-project memory is opt-in.** Launchers can pass `--add-dir ~/agent-assembly/memory` to give the agent read/write access to the shared memory directory. Project-specific memory stays in the project; personal/cross-project memory goes here.

**Hooks are deterministic guards.** The included `prompt-guard.sh` fires on every user prompt, injecting a goal-alignment check for substantive messages and a memory staleness alarm. Write your own hooks for other lifecycle events.

**Generated artifacts are ephemeral.** `CLAUDE.local.md`, `.claude/settings.local.json`, and `.claude/skills/` in the target project are all generated, gitignored, and overwritten on every launch.

### Extending

**New module**: Create `modules/my-module.md`, add the filename to your launcher's `assemble_modules` call.

**New hook**: Create `hooks/my-hook.sh` (receives JSON on stdin, outputs JSON to stdout), add the filename to your launcher's `assemble_hooks` call.

**New project**: Copy an existing launcher, change `TARGET` and module list.

**New skill**: Create `.claude/skills/my-skill/SKILL.md`, add to your launcher's `assemble_skills` call.

See [SPEC.md](SPEC.md) for the complete specification.

### Directory Structure

```
agent-assembly/
├── launchers/           # Per-project launch scripts
│   ├── lib.sh           # Pipeline library (5 functions)
│   └── example-mac-claude.sh
├── modules/             # Profile components (source of truth)
├── hooks/               # Hook scripts injected into sessions
│   └── prompt-guard.sh  # Action check + memory alarm
├── memory/              # Cross-project session logs
├── tests/               # Regression tests
├── SPEC.md              # System specification
└── CLAUDE.md            # Agent entry point
```

### Testing

```bash
bash tests/run.sh
```

21 tests covering module assembly, hook generation, gitignore management, hook behavior, and documentation consistency. CI runs on both Ubuntu and macOS.

### Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or compatible agent CLI
- bash or zsh, jq
- macOS or Linux

## License

MIT
