#!/usr/bin/env bash
# Headless suite runner — every tests/*.tscn that uses harness.gd
# prints "=== ALL CHECKS PASS ===" or XX lines; exit = #failures.
#   GODOT=/path/to/Godot_v4.7.2.exe tools/run_tests.sh [test_name...]
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/../game" || exit 2
# daily_check is a >120s solver sweep — run it explicitly, not by default
tests="${*:-$(ls tests/*.tscn 2>/dev/null | xargs -n1 basename | sed 's/\.tscn//' | grep -v daily_check)}"
fails=0
for t in $tests; do
    out=$(timeout 120 "$GODOT" --headless --path . "res://tests/$t.tscn" 2>&1)
    ok=$(echo "$out" | grep -c '  OK')
    xx=$(echo "$out" | grep -c '  XX')
    if [ "$xx" -gt 0 ] || ! echo "$out" | grep -q 'ALL CHECKS PASS\|ALL BRIEFS\|=== done\|---.*dailies'; then
        echo "FAIL $t (ok=$ok xx=$xx)"
        echo "$out" | grep '  XX' | head -8
        fails=$((fails + 1))
    else
        echo "PASS $t ($ok checks)"
    fi
done
echo "---"
[ "$fails" -eq 0 ] && echo "ALL SUITES PASS" || echo "$fails SUITE(S) FAILED"
exit "$fails"
