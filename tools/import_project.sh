#!/usr/bin/env bash
# Import all assets so headless runs and exports see .import files.
# Godot 4.5 supports `--import`; the editor fallback covers older/newer builds
# where the flag is unavailable. See NOTES.md.
set -euo pipefail

if godot --headless --import >/tmp/godot_import.log 2>&1; then
  echo "imported with --import"
else
  echo "--import not available, falling back to --editor --quit"
  godot --headless --editor --quit >>/tmp/godot_import.log 2>&1
  echo "imported with --editor --quit"
fi

if [ -n "${SHOW_IMPORT_LOG:-}" ]; then
  cat /tmp/godot_import.log
fi
