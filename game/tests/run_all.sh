#!/usr/bin/env bash
# Syntax-check every script, then run every suite with a hard timeout. Exit code = number of failing suites.
cd "$(dirname "$0")/.." || exit 1
fail=0
for f in $(find scripts tests -name '*.gd' | sort); do
  out=$(timeout 60 godot --headless --path . --check-only -s "$f" 2>&1 | grep -E "SCRIPT ERROR|Parse Error" | head -2)
  if [ -n "$out" ]; then echo "SYNTAX: $f"; echo "$out"; fail=$((fail+1)); fi
done
for t in run_tests dialogue_tests dental_tests board_tests rhythm_tests day23_tests day45_tests sim_tests investigation_tests cause_tests persona_tests reactions_tests casefile_tests population_tests town_game_tests save_tests life_tests town_ui_tests art_tests town3d_tests history_tests case_tests procedure_tests narrator_tests detective_game_tests detective3d_tests tutorial_tests town_tests smoke; do
  [ -f tests/$t.gd ] || continue
  res=$(timeout 300 godot --headless --path . -s tests/$t.gd 2>&1 | grep -E "checks|smoke:|FAIL" | tail -3)
  echo "$t: ${res:-TIMEOUT/NO OUTPUT}"
  echo "$res" | grep -qE "FAIL|failed$|[1-9][0-9]* failed" && fail=$((fail+1))
  [ -z "$res" ] && fail=$((fail+1))
done
exit $fail
