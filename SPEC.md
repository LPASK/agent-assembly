# agent-assembly — Specification

agent-assembly is a build system for agent sessions. It assembles behavior context, hooks, and skills into a target project directory, then launches the CLI.

**This SPEC describes mechanisms, not instances.** It defines how `assemble_modules` works, not which modules a specific project uses. Project-specific configurations belong in their launcher scripts and launcher test files, not here.

## Pipeline

Every launcher picks from the same pipeline steps as needed:

```
assemble_modules → assemble_hooks → assemble_skills → ensure_gitignore → launch
```

Not every launcher uses every step. The launcher itself is the configuration — it calls only the steps it needs.

| Step | What it does | Generated artifact | CLI pick-up mechanism |
|------|-------------|-------------------|----------------------|
| `assemble_modules` | Concatenates selected module files into a single behavior context file | `TARGET/CLAUDE.local.md` | CLI auto-loads `CLAUDE.local.md` from working directory |
| `assemble_hooks` | Builds hook JSON from selected hook scripts, merges into settings file | `TARGET/.claude/settings.local.json` | CLI auto-loads `settings.local.json`, merges with `settings.json` |
| `assemble_skills` | Symlinks selected skills into target project | `TARGET/.claude/skills/<name>` (symlink) | CLI discovers skills from `.claude/skills/` |
| `ensure_gitignore` | Ensures all generated artifacts are in `.gitignore` | Appends to `TARGET/.gitignore` | — |
| `launch` | `cd TARGET && exec CLI [args...]` | — | Caller passes `--add-dir`, flags, etc. |

A launcher script is just: source `lib.sh`, choose what to assemble, call these functions in order.

---

## Component Contracts

### assemble_modules(TARGET, mod1.md, mod2.md, ...)

- **Pre**: TARGET directory exists; each mod is a filename in `modules/`
- **Post**: `TARGET/CLAUDE.local.md` contains concatenation of all found modules, separated by `---`, with `{{ASSEMBLY_DIR}}` placeholders replaced by actual path
- **Missing module**: warning to stderr, skip, continue
- **Bad target**: return 1, error to stderr (never `exit` — must not kill the caller)
- **Stdout**: `Assembled N modules → <path>`

### assemble_hooks(TARGET, hook1.sh, hook2.sh, ...)

- **Pre**: each hook is a filename in `hooks/`
- **Post**: `TARGET/.claude/settings.local.json` is **overwritten** with hooks JSON. No merge — previous content is discarded.
- **Missing hook**: warning to stderr, skip
- **No valid hooks**: writes `{"hooks": {}}`
- **Hook event type**: currently all hooks are injected as `UserPromptSubmit`. When other event types are needed, extend the interface.

### assemble_skills(TARGET, skill1, skill2, ...)

- **Pre**: each skill is a directory name in `.claude/skills/`
- **Post**: symlinks created at `TARGET/.claude/skills/<name>` pointing to source
- **Missing skill**: warning to stderr, skip

### ensure_gitignore(TARGET)

- **Post**: `TARGET/.gitignore` contains entries for `CLAUDE.local.md`, `.claude/settings.local.json`, `.claude/skills/`
- **Idempotent**: no duplicate entries on repeated calls

### launch(CLI, TARGET, [args...])

- **If inside tmux**: opens a new tmux window named after TARGET's basename, runs `cd TARGET && CLI [args...]` in it
- **If not inside tmux**: `cd TARGET && exec CLI [args...]` (replaces current process)
- **Caller's responsibility**: `--add-dir`, `--dangerously-skip-permissions`, and all other flags are passed by the launcher, not decided by this function

---

## Directory Conventions

### `modules/` — Behavior Context (source of truth)

Everything the agent needs to know (behavior rules, profile, goals) lives here as markdown files. This is the single source of truth — no other copy of this content should exist.

**Rules**:
- Each module is self-contained: understandable without reading other modules
- No duplication across modules: one concept lives in one file only
- Granularity = one independently toggleable capability
- Modules may use `{{ASSEMBLY_DIR}}` placeholder, replaced at assembly time with actual path
- Project-specific modules (workflows, directory maps) belong in the project, not here

**Naming**: `<slug>.md`, lowercase, hyphens. No enforced prefix taxonomy — `profile-*` is descriptive, not a classification rule.

### `hooks/` — Hook Scripts (source of truth)

Shell scripts that the CLI invokes at specific lifecycle events. This directory provides the mechanism to inject them into target projects.

**Rules**:
- Each hook is a standalone executable script
- Hooks receive input from CLI on stdin (JSON) and output JSON to stdout, or exit silently
- Hook scripts must handle their own path resolution (they may be invoked via absolute path from any working directory)

**Naming**: `<descriptive-slug>.sh`.

### `launchers/` — Project Launchers & Library

`launchers/lib.sh` implements the 5 pipeline functions (`assemble_modules`, `assemble_hooks`, `assemble_skills`, `ensure_gitignore`, `launch`). All other files in this directory are project launcher scripts that source `lib.sh` and call these functions.

**Rules**:
- `lib.sh` is the shared library — all pipeline functions live here
- Every launcher must `source "$(dirname "$0")/lib.sh"` as first action
- Every launcher follows the pipeline: assemble_modules → assemble_hooks → assemble_skills → ensure_gitignore → launch
- The launcher itself is the configuration — no separate config file needed

**Naming**: `<project>-<platform>-<cli>.sh` for launchers. Platform defaults to `mac`. Examples: `myapp-mac-claude.sh`, `docs-mac-claude.sh`. `lib.sh` is reserved for the shared library.

### `.claude/skills/` — Skills

Skill directories that can be symlinked into target projects via `assemble_skills`.

**Rules**:
- Each skill is a directory containing at minimum `SKILL.md`
- Skills are discovered by CLI from `.claude/skills/` in the working directory

**Naming**: `<skill-name>/` directory with `SKILL.md` inside.

---

## Generated Artifacts

These files are produced by the pipeline and written into the **target project directory**. They must never be hand-edited — they are overwritten on every launch.

| Artifact | Generated by | Must be gitignored |
|----------|-------------|-------------------|
| `CLAUDE.local.md` | `assemble_modules` | Yes |
| `.claude/settings.local.json` | `assemble_hooks` | Yes |
| `.claude/skills/*` (symlinks) | `assemble_skills` | Yes |

`ensure_gitignore` enforces the gitignore entries. The target project's `CLAUDE.md` and `.claude/settings.json` are **not** generated — they belong to the project.

---

## Invariants

| ID | Statement |
|----|-----------|
| INV-01 | Every launcher sources `lib.sh` and calls pipeline steps as needed |
| INV-02 | Generated artifacts are overwritten on every launch — never hand-edited |
| INV-03 | `assemble_hooks` overwrites `settings.local.json` entirely — no merge with prior content |
| INV-04 | `settings.json` (tracked) must NOT contain hooks — hooks are managed exclusively by launchers |
| INV-05 | Generated artifacts are gitignored in the target project |
| INV-06 | Hook commands in generated `settings.local.json` use absolute paths |
| INV-07 | `launch()` is generic — all flags and `--add-dir` are the launcher's decision |
| INV-08 | `{{ASSEMBLY_DIR}}` in module content is replaced at assembly time |

---

## Procedures

### Adding a module

1. Create `modules/<slug>.md` — self-contained, no duplication with existing modules
2. Add the filename to the desired launcher(s)' `assemble_modules` call
3. Run `bash tests/run.sh`

### Adding a hook

1. Create `hooks/<slug>.sh` (receives JSON on stdin, outputs JSON to stdout), add the filename to your launcher's `assemble_hooks` call.
2. Run `bash tests/run.sh`

### Adding a launcher (new project)

1. Create `launchers/<environment>-<platform>-<cli>.sh`
2. `source "$(dirname "$0")/lib.sh"`
3. Set `CLI` and `TARGET`
4. Call the pipeline functions, selecting modules/hooks/skills as needed
5. Run `bash tests/run.sh`

### Adding a skill

1. Create `.claude/skills/<name>/SKILL.md`
2. Add to desired launcher(s)' `assemble_skills` call
3. Run `bash tests/run.sh`

### Modifying lib.sh

1. Make the change
2. Update contracts in this SPEC if the interface changed
3. Run `bash tests/run.sh` — all must pass

---

## Verification

### Unit tests

```bash
bash tests/run.sh
```

Tests are split into two levels:

- **`tests/run.sh`** — Core tests (lib.sh functions, hooks, data consistency, documentation). Environment-independent.
- **`tests/test-<name>.sh`** — Per-launcher assembly tests. Each launcher can have its own test file verifying its module/hook/skill combination.

`run.sh` auto-discovers and runs all `tests/test-*.sh` files. Adding a new launcher? Create `tests/test-<name>.sh`.

### End-to-end testing

Unit tests verify pipeline functions in isolation. End-to-end testing verifies the full launcher → CLI → agent experience in a real session.

**When to do it**: after any change to modules, hooks, or launcher configuration. Unit tests alone cannot catch issues like hook double-firing, missing context in agent responses, or incorrect module content.

**How**:

1. Launch via the launcher: `bash launchers/<launcher>.sh`. This opens a new tmux window with the CLI running.
2. Send a message to the tmux window. CLI input requires **two Enters** — first Enter is a newline, second Enter submits:
   ```bash
   tmux send-keys -t "<window>" "<message>" Enter && sleep 1 && tmux send-keys -t "<window>" Enter
   ```
3. Wait for the agent to respond, then read output with `tmux capture-pane -t "<window>" -p -S -<lines>`.
4. Verify: profile recognized, hook content received (Action Check / Memory alarm), agent behavior matches module instructions.
