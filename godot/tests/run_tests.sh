#!/usr/bin/env bash
#
# Runs the checks CI runs, so a green local run means a green pull request.
#
#   tests/run_tests.sh              static checks only (no GPU needed)
#   tests/run_tests.sh --render     also render every demo
#   GODOT=/path/to/godot tests/run_tests.sh
#
# Exits non-zero if anything fails.
set -uo pipefail

GODOT="${GODOT:-godot}"
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS=0

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "Godot not found. Set GODOT to the executable, e.g."
	echo "  GODOT=/path/to/Godot_v4.7.1-stable_linux.x86_64 tests/run_tests.sh"
	exit 127
fi

echo "== static checks =="
OUTPUT="$("$GODOT" --headless --path "$PROJECT" --script res://tests/static_checks.gd 2>&1)"
GODOT_STATUS=$?
echo "$OUTPUT"
[ "$GODOT_STATUS" -ne 0 ] && STATUS=1

# A shader that fails to compile and a script that fails to parse are reported
# on stderr without failing the load, so they need a separate look.
echo
echo "== shader and script errors =="
ERRORS="$(echo "$OUTPUT" | grep -E "^(SHADER ERROR|SCRIPT ERROR)")"
if [ -n "$ERRORS" ]; then
	echo "$ERRORS"
	STATUS=1
else
	echo "none"
fi

if [ "${1:-}" = "--render" ]; then
	echo
	echo "== render checks =="
	# Needs a real driver: --headless draws nothing, so these would pass on a
	# completely broken project.
	"$GODOT" --path "$PROJECT" --rendering-driver opengl3 \
		--script res://tests/render_checks.gd || STATUS=1
fi

echo
if [ "$STATUS" -eq 0 ]; then
	echo "PASS"
else
	echo "FAIL"
fi
exit "$STATUS"
