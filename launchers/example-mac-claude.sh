#!/bin/bash
# ⚠️ SAMPLE LAUNCHER — DO NOT USE AS-IS
# Copy this file, rename it for your project, and adjust TARGET + module list.
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
