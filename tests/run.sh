#!/bin/bash
# Core tests — lib.sh functions, hooks, data consistency, documentation.
# These tests are environment-independent and always pass regardless of which launchers are installed.
#
# Launcher-specific tests live in separate files: test-*.sh
# This script auto-discovers and runs any tests/test-*.sh files found.
#
# Run: bash tests/run.sh

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

HOOK="$ROOT_DIR/hooks/prompt-guard.sh"

# ══════════════════════════════════════════════════════════════════════
# lib.sh unit tests
# ══════════════════════════════════════════════════════════════════════

test_assemble_modules_basic() {
  CURRENT_TEST="assemble_modules_basic"
  local tmp=$(mktemp -d)
  echo "# Mod A" > "$MODULES_DIR/test_a.md"
  echo "# Mod B" > "$MODULES_DIR/test_b.md"

  assemble_modules "$tmp" test_a.md test_b.md >/dev/null

  assert_file_exists "$tmp/CLAUDE.local.md" || { rm -rf "$tmp" "$MODULES_DIR/test_a.md" "$MODULES_DIR/test_b.md"; return; }
  assert_file_contains "$tmp/CLAUDE.local.md" "# Mod A" || { rm -rf "$tmp" "$MODULES_DIR/test_a.md" "$MODULES_DIR/test_b.md"; return; }
  assert_file_contains "$tmp/CLAUDE.local.md" "# Mod B" || { rm -rf "$tmp" "$MODULES_DIR/test_a.md" "$MODULES_DIR/test_b.md"; return; }
  assert_file_contains "$tmp/CLAUDE.local.md" "---" || { rm -rf "$tmp" "$MODULES_DIR/test_a.md" "$MODULES_DIR/test_b.md"; return; }

  rm -rf "$tmp" "$MODULES_DIR/test_a.md" "$MODULES_DIR/test_b.md"
  pass "$CURRENT_TEST"
}

test_assemble_modules_missing() {
  CURRENT_TEST="assemble_modules_missing"
  local tmp=$(mktemp -d)
  echo "# Real" > "$MODULES_DIR/test_real.md"

  local stderr
  stderr=$(assemble_modules "$tmp" test_real.md nonexistent.md 2>&1 >/dev/null)

  assert_file_exists "$tmp/CLAUDE.local.md" || { rm -rf "$tmp" "$MODULES_DIR/test_real.md"; return; }
  assert_file_contains "$tmp/CLAUDE.local.md" "# Real" || { rm -rf "$tmp" "$MODULES_DIR/test_real.md"; return; }
  echo "$stderr" | grep -q "Warning" || { fail "$CURRENT_TEST" "expected warning on stderr"; rm -rf "$tmp" "$MODULES_DIR/test_real.md"; return; }

  rm -rf "$tmp" "$MODULES_DIR/test_real.md"
  pass "$CURRENT_TEST"
}

test_assemble_modules_bad_target() {
  CURRENT_TEST="assemble_modules_bad_target"
  local stderr exit_code
  stderr=$(assemble_modules "/nonexistent/path" core-behavior.md 2>&1); exit_code=$?

  [[ "$exit_code" -ne 0 ]] || { fail "$CURRENT_TEST" "expected non-zero exit"; return; }
  echo "$stderr" | grep -q "Error" || { fail "$CURRENT_TEST" "expected error on stderr"; return; }

  pass "$CURRENT_TEST"
}

test_assemble_modules_returns_not_exits() {
  CURRENT_TEST="assemble_modules_returns_not_exits"
  local result
  result=$(assemble_modules "/nonexistent/path" core-behavior.md 2>/dev/null; echo "SURVIVED")
  echo "$result" | grep -q "SURVIVED" || { fail "$CURRENT_TEST" "assemble_modules used exit instead of return"; return; }

  pass "$CURRENT_TEST"
}

test_placeholder_replacement() {
  CURRENT_TEST="placeholder_replacement"
  local tmp=$(mktemp -d)
  echo 'Path is {{ASSEMBLY_DIR}}/memory/' > "$MODULES_DIR/test_placeholder.md"

  assemble_modules "$tmp" test_placeholder.md >/dev/null

  assert_file_contains "$tmp/CLAUDE.local.md" "$ASSEMBLY_DIR/memory/" || { rm -rf "$tmp" "$MODULES_DIR/test_placeholder.md"; return; }
  assert_file_not_contains "$tmp/CLAUDE.local.md" "{{ASSEMBLY_DIR}}" || { rm -rf "$tmp" "$MODULES_DIR/test_placeholder.md"; return; }

  rm -rf "$tmp" "$MODULES_DIR/test_placeholder.md"
  pass "$CURRENT_TEST"
}

test_assemble_hooks_new() {
  CURRENT_TEST="assemble_hooks_new"
  local tmp=$(mktemp -d)

  assemble_hooks "$tmp" prompt-guard.sh >/dev/null

  assert_file_exists "$tmp/.claude/settings.local.json" || { rm -rf "$tmp"; return; }
  assert_file_contains "$tmp/.claude/settings.local.json" "UserPromptSubmit" || { rm -rf "$tmp"; return; }
  assert_file_contains "$tmp/.claude/settings.local.json" "prompt-guard.sh" || { rm -rf "$tmp"; return; }

  rm -rf "$tmp"
  pass "$CURRENT_TEST"
}

test_assemble_hooks_overwrites_existing() {
  CURRENT_TEST="assemble_hooks_overwrites_existing"
  local tmp=$(mktemp -d)
  mkdir -p "$tmp/.claude"
  echo '{"permissions":{"allow":["Bash(git:*)"]}}' > "$tmp/.claude/settings.local.json"

  assemble_hooks "$tmp" prompt-guard.sh >/dev/null

  # Old permissions should be gone — overwrite, not merge
  assert_file_not_contains "$tmp/.claude/settings.local.json" "permissions" || { rm -rf "$tmp"; return; }
  assert_file_contains "$tmp/.claude/settings.local.json" "hooks" || { rm -rf "$tmp"; return; }

  rm -rf "$tmp"
  pass "$CURRENT_TEST"
}

test_assemble_hooks_corrupt_file() {
  CURRENT_TEST="assemble_hooks_corrupt_file"
  local tmp=$(mktemp -d)
  mkdir -p "$tmp/.claude"
  echo "{invalid json" > "$tmp/.claude/settings.local.json"

  assemble_hooks "$tmp" prompt-guard.sh >/dev/null

  # Overwrite semantics: corrupt file is simply replaced with valid JSON
  jq empty "$tmp/.claude/settings.local.json" 2>/dev/null || { fail "$CURRENT_TEST" "result not valid JSON"; rm -rf "$tmp"; return; }
  assert_file_contains "$tmp/.claude/settings.local.json" "prompt-guard.sh" || { rm -rf "$tmp"; return; }

  rm -rf "$tmp"
  pass "$CURRENT_TEST"
}

test_assemble_hooks_idempotent() {
  CURRENT_TEST="assemble_hooks_idempotent"
  local tmp=$(mktemp -d)

  assemble_hooks "$tmp" prompt-guard.sh >/dev/null
  local first=$(jq -S . "$tmp/.claude/settings.local.json")

  assemble_hooks "$tmp" prompt-guard.sh >/dev/null
  local second=$(jq -S . "$tmp/.claude/settings.local.json")

  [[ "$first" == "$second" ]] || { fail "$CURRENT_TEST" "results differ after second run"; rm -rf "$tmp"; return; }

  rm -rf "$tmp"
  pass "$CURRENT_TEST"
}

test_assemble_hooks_missing_hook() {
  CURRENT_TEST="assemble_hooks_missing_hook"
  local tmp=$(mktemp -d)

  local stderr
  stderr=$(assemble_hooks "$tmp" nonexistent-hook.sh 2>&1 >/dev/null)

  echo "$stderr" | grep -q "Warning" || { fail "$CURRENT_TEST" "expected warning for missing hook"; rm -rf "$tmp"; return; }
  jq empty "$tmp/.claude/settings.local.json" 2>/dev/null || { fail "$CURRENT_TEST" "result not valid JSON"; rm -rf "$tmp"; return; }

  rm -rf "$tmp"
  pass "$CURRENT_TEST"
}

test_assemble_hooks_no_args() {
  CURRENT_TEST="assemble_hooks_no_args"
  local tmp=$(mktemp -d)

  assemble_hooks "$tmp" >/dev/null

  assert_file_exists "$tmp/.claude/settings.local.json" || { rm -rf "$tmp"; return; }
  jq -e '.hooks == {}' "$tmp/.claude/settings.local.json" >/dev/null 2>&1 || { fail "$CURRENT_TEST" "expected empty hooks object"; rm -rf "$tmp"; return; }

  rm -rf "$tmp"
  pass "$CURRENT_TEST"
}

# ══════════════════════════════════════════════════════════════════════
# gitignore tests
# ══════════════════════════════════════════════════════════════════════

test_ensure_gitignore_creates() {
  CURRENT_TEST="ensure_gitignore_creates"
  local tmp=$(mktemp -d)

  ensure_gitignore "$tmp"

  assert_file_exists "$tmp/.gitignore" || { rm -rf "$tmp"; return; }
  assert_file_contains "$tmp/.gitignore" "CLAUDE.local.md" || { rm -rf "$tmp"; return; }
  assert_file_contains "$tmp/.gitignore" ".claude/settings.local.json" || { rm -rf "$tmp"; return; }

  rm -rf "$tmp"
  pass "$CURRENT_TEST"
}

test_ensure_gitignore_idempotent() {
  CURRENT_TEST="ensure_gitignore_idempotent"
  local tmp=$(mktemp -d)

  ensure_gitignore "$tmp"
  local first=$(cat "$tmp/.gitignore")
  ensure_gitignore "$tmp"
  local second=$(cat "$tmp/.gitignore")

  [[ "$first" == "$second" ]] || { fail "$CURRENT_TEST" "file changed on second run"; rm -rf "$tmp"; return; }

  rm -rf "$tmp"
  pass "$CURRENT_TEST"
}

# ══════════════════════════════════════════════════════════════════════
# Hook tests
# ══════════════════════════════════════════════════════════════════════

test_hook_long_message() {
  CURRENT_TEST="hook_long_message"
  local output
  output=$(echo '{"prompt":"Please help me refactor this authentication module completely"}' | bash "$HOOK" 2>/dev/null)

  [[ -n "$output" ]] || { fail "$CURRENT_TEST" "expected output"; return; }
  echo "$output" | jq -e '.hookSpecificOutput' >/dev/null 2>&1 || { fail "$CURRENT_TEST" "invalid JSON"; return; }
  echo "$output" | grep -q '\[Action Check\]' || { fail "$CURRENT_TEST" "missing [Action Check]"; return; }

  pass "$CURRENT_TEST"
}

test_hook_short_message_no_action_check() {
  CURRENT_TEST="hook_short_message_no_action_check"
  local output
  output=$(echo '{"prompt":"ok"}' | bash "$HOOK" 2>/dev/null)

  if [[ -n "$output" ]]; then
    echo "$output" | grep -q '\[Action Check\]' && { fail "$CURRENT_TEST" "short message should not get [Action Check]"; return; }
  fi

  pass "$CURRENT_TEST"
}

test_hook_skip_check() {
  CURRENT_TEST="hook_skip_check"
  local output
  output=$(echo '{"prompt":"skip check please do this long task for me now"}' | bash "$HOOK" 2>/dev/null)

  [[ -z "$output" ]] || { fail "$CURRENT_TEST" "skip check should produce no output"; return; }

  pass "$CURRENT_TEST"
}

test_hook_invalid_json() {
  CURRENT_TEST="hook_invalid_json"
  local exit_code
  echo 'not json' | bash "$HOOK" 2>/dev/null; exit_code=$?

  [[ "$exit_code" -eq 0 ]] || { fail "$CURRENT_TEST" "should exit 0 on invalid input"; return; }

  pass "$CURRENT_TEST"
}

test_hook_memory_alarm_independent_of_length() {
  CURRENT_TEST="hook_memory_alarm_independent_of_length"
  local today=$(date +%Y-%m-%d)
  local mem_file="$ASSEMBLY_DIR/memory/${today}.md"
  local had_mem=false

  if [[ -f "$mem_file" ]]; then
    had_mem=true
    mv "$mem_file" "${mem_file}.bak"
  fi

  local output
  output=$(echo '{"prompt":"ok"}' | bash "$HOOK" 2>/dev/null)

  if [[ "$had_mem" == true ]]; then
    mv "${mem_file}.bak" "$mem_file"
  fi

  [[ -n "$output" ]] || { fail "$CURRENT_TEST" "expected [!Memory] even for short message"; return; }
  echo "$output" | grep -q '\[!Memory\]' || { fail "$CURRENT_TEST" "missing [!Memory] for short message"; return; }

  pass "$CURRENT_TEST"
}

test_hook_absolute_path() {
  CURRENT_TEST="hook_absolute_path"
  local tmp=$(mktemp -d)

  assemble_hooks "$tmp" prompt-guard.sh >/dev/null

  local cmd
  cmd=$(jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' "$tmp/.claude/settings.local.json")

  [[ "$cmd" == /* || "$cmd" == "bash /"* ]] || { fail "$CURRENT_TEST" "hook command not absolute: $cmd"; rm -rf "$tmp"; return; }
  local script_path
  script_path=$(echo "$cmd" | sed 's/^bash //')
  [[ -f "$script_path" ]] || { fail "$CURRENT_TEST" "hook script not found: $script_path"; rm -rf "$tmp"; return; }

  rm -rf "$tmp"
  pass "$CURRENT_TEST"
}

# ══════════════════════════════════════════════════════════════════════
# Documentation consistency tests
# ══════════════════════════════════════════════════════════════════════

test_spec_exists() {
  CURRENT_TEST="spec_exists"
  assert_file_exists "$ROOT_DIR/SPEC.md" || return
  assert_file_contains "$ROOT_DIR/SPEC.md" "Pipeline" || return
  assert_file_contains "$ROOT_DIR/SPEC.md" "Invariants" || return
  assert_file_contains "$ROOT_DIR/SPEC.md" "Component Contracts" || return

  pass "$CURRENT_TEST"
}

test_claude_md_points_to_spec() {
  CURRENT_TEST="claude_md_points_to_spec"
  assert_file_contains "$ROOT_DIR/CLAUDE.md" "SPEC.md" || return

  pass "$CURRENT_TEST"
}

# ══════════════════════════════════════════════════════════════════════
# Run core tests
# ══════════════════════════════════════════════════════════════════════

echo "Running core tests..."
echo ""

# lib.sh
test_assemble_modules_basic
test_assemble_modules_missing
test_assemble_modules_bad_target
test_assemble_modules_returns_not_exits
test_placeholder_replacement
test_assemble_hooks_new
test_assemble_hooks_overwrites_existing
test_assemble_hooks_corrupt_file
test_assemble_hooks_idempotent
test_assemble_hooks_missing_hook
test_assemble_hooks_no_args
test_ensure_gitignore_creates
test_ensure_gitignore_idempotent

# hooks
test_hook_long_message
test_hook_short_message_no_action_check
test_hook_skip_check
test_hook_invalid_json
test_hook_memory_alarm_independent_of_length
test_hook_absolute_path

# documentation
test_spec_exists
test_claude_md_points_to_spec

report

# ══════════════════════════════════════════════════════════════════════
# Auto-discover and run launcher-specific tests
# ══════════════════════════════════════════════════════════════════════

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for test_file in "$TESTS_DIR"/test-*.sh; do
  [[ -f "$test_file" ]] || continue
  echo ""
  bash "$test_file"
done
