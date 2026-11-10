#!/usr/bin/env bash
# Runs the GUT suite headless and fails if any test fails OR any script
# fails to parse (GUT skips unparseable test files without failing the run).
#
# Usage: tools/run_tests.sh            (uses $GODOT, or `godot` on PATH)
#        GODOT=/path/to/Godot tools/run_tests.sh
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT:-godot}"
LOG="$(mktemp)"
"$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG"; then
	echo ""
	echo "run_tests.sh: script errors found (see above); failing the run."
	grep -E "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG" | sort -u
	STATUS=1
fi
rm -f "$LOG"
exit $STATUS
