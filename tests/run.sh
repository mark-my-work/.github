#!/usr/bin/env bash
# Runs every test in this repository. Exits 1 if any fails.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
status=0
for t in tests/*.test.sh; do
  echo "== $t"; bash "$t" || status=1
done
echo "== tests/test_*.py"
python3 -m unittest discover -s tests -p 'test_*.py' || status=1
exit "$status"
