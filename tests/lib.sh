# shellcheck shell=bash
# Tiny assertion helpers shared by the A.T.L.A.S tests. Source it, call ok/eq/fails, end with finish.
PASS=0; FAIL=0
ok()    { local name=$1; shift; if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  ✗ $name"; fi; }
fails() { local name=$1; shift; if "$@" >/dev/null 2>&1; then FAIL=$((FAIL+1)); echo "  ✗ $name (expected failure)"; else PASS=$((PASS+1)); fi; }
eq()    { local name=$1 want=$2 got=$3; if [[ $got == "$want" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  ✗ $name: want [$want] got [$got]"; fi; }
finish() { echo "  $PASS passed, $FAIL failed"; [[ $FAIL -eq 0 ]]; }
# A throwaway HOME so tests never touch the real state files.
sandbox_home() { local h; h=$(mktemp -d); mkdir -p "$h/.local/state" "$h/.config"; echo "$h"; }
