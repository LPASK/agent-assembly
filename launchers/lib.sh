#!/bin/bash
# agent-assembly launcher library — shared functions for all launcher scripts.
# Source this from individual launchers: source "$(dirname "$0")/lib.sh"

set -euo pipefail

ASSEMBLY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES_DIR="$ASSEMBLY_DIR/modules"

# ── assemble_modules TARGET_DIR mod1.md mod2.md ... ─────────────────
# Concatenates selected modules into TARGET_DIR/CLAUDE.local.md
assemble_modules() {
  local target="$1"; shift
  local out="$target/CLAUDE.local.md"
  local first=true
  local count=0

  [[ -d "$target" ]] || { echo "Error: target directory does not exist: $target" >&2; return 1; }

  : > "$out"  # truncate

  for mod in "$@"; do
    local src="$MODULES_DIR/$mod"
    if [[ ! -f "$src" ]]; then
      echo "Warning: module not found: $src" >&2
      continue
    fi
    if [[ "$first" == true ]]; then
      first=false
    else
      printf '\n---\n\n' >> "$out"
    fi
    cat "$src" >> "$out"
    count=$((count + 1))
  done

  # Replace {{ASSEMBLY_DIR}} placeholder with actual path
  if [[ -f "$out" ]]; then
    local tmp_sed
    tmp_sed=$(mktemp)
    sed "s|{{ASSEMBLY_DIR}}|$ASSEMBLY_DIR|g" "$out" > "$tmp_sed" && mv "$tmp_sed" "$out"
  fi

  echo "Assembled $count modules → $out"
}

# ── ensure_gitignore TARGET_DIR ────────────────────────────────────
# Ensures CLAUDE.local.md and .claude/settings.local.json are in .gitignore.
ensure_gitignore() {
  local target="$1"
  local gi="$target/.gitignore"
  local entries=("CLAUDE.local.md" ".claude/settings.local.json" ".claude/skills/")

  for entry in "${entries[@]}"; do
    if [[ ! -f "$gi" ]] || ! grep -qxF "$entry" "$gi"; then
      echo "$entry" >> "$gi"
    fi
  done
}

# ── assemble_hooks TARGET_DIR hook1.sh hook2.sh ... ────────────────
# Generates .claude/settings.local.json with hook config.
# Each argument after TARGET_DIR is a script name in hooks/.
# All hooks are injected as UserPromptSubmit hooks.
# OVERWRITES the file entirely — no merge with existing content.
assemble_hooks() {
  local target="$1"; shift
  local settings_dir="$target/.claude"
  local settings_file="$settings_dir/settings.local.json"

  mkdir -p "$settings_dir"

  # Build hooks array from arguments
  local hooks_array="[]"
  for hook_name in "$@"; do
    local hook_path="$ASSEMBLY_DIR/hooks/$hook_name"
    if [[ ! -f "$hook_path" ]]; then
      echo "Warning: hook not found: $hook_path" >&2
      continue
    fi
    hooks_array=$(echo "$hooks_array" | jq --arg cmd "bash $hook_path" '. + [{"type": "command", "command": $cmd, "timeout": 5000}]')
  done

  # Generate complete settings file
  local settings_json
  if [[ "$hooks_array" == "[]" ]]; then
    settings_json='{"hooks": {}}'
  else
    settings_json=$(jq -n --argjson arr "$hooks_array" '{
      "hooks": {
        "UserPromptSubmit": [{
          "hooks": $arr
        }]
      }
    }')
  fi

  echo "$settings_json" > "$settings_file"
  echo "Generated $settings_file"
}

# ── assemble_skills TARGET_DIR skill1 skill2 ... ────────────────
# Symlinks skills into TARGET_DIR/.claude/skills/ for CLI discovery.
assemble_skills() {
  local target="$1"; shift
  local target_skills="$target/.claude/skills"
  mkdir -p "$target_skills"
  for skill in "$@"; do
    local src="$ASSEMBLY_DIR/.claude/skills/$skill"
    local dst="$target_skills/$skill"
    if [[ -d "$src" ]]; then
      ln -sfn "$src" "$dst"
    else
      echo "Warning: skill not found: $src" >&2
    fi
  done
}

# ── launch CLI TARGET_DIR [extra_args...] ─────────────────────────
# If inside tmux: opens a new tmux window named after the target directory.
# Otherwise: exec the CLI in the current shell.
# Caller controls --add-dir flags and all other CLI arguments.
launch() {
  local cli="$1"; shift
  local target="$1"; shift
  local win_name
  win_name="$(basename "$target")"

  if [[ -n "${TMUX:-}" ]]; then
    # Build a properly quoted command string for tmux
    local cmd="cd '${target}' && '${cli}'"
    local arg
    for arg in "$@"; do
      cmd+=" '${arg}'"
    done
    echo "Launching $cli in tmux window '$win_name' ..."
    tmux new-window -n "$win_name" "$cmd"
  else
    echo "Launching $cli in $target ..."
    cd "$target"
    exec "$cli" "$@"
  fi
}
