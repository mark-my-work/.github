# shellcheck shell=bash
# Shared by every tests/*.test.sh. Source it; call `finish` last.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FAILS=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; FAILS=$((FAILS + 1)); }
assert_eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1: expected [$3], got [$2]"; fi; }
assert_contains() { if grep -qF -- "$3" <<<"$2"; then pass "$1"; else fail "$1: [$3] not in output:"; printf '%s\n' "$2" | sed 's/^/     | /'; fi; }
assert_absent() { if grep -qF -- "$3" <<<"$2"; then fail "$1: [$3] unexpectedly present"; else pass "$1"; fi; }
# A fake `gh` on PATH. It logs each call to $STUB_DIR/calls.log and replies from
# $STUB_DIR/rules.tsv: <glob over the joined args> TAB <exit status> TAB <response file>.
# The first matching rule wins; --jq is applied to the response as real gh would.
stub_gh() {
  STUB_DIR=$(mktemp -d); export STUB_DIR
  : > "$STUB_DIR/calls.log"; : > "$STUB_DIR/rules.tsv"
  PATH="$ROOT/tests/stub:$PATH"; export PATH
}
reply() { # reply <glob> <status> <body>
  local f; f=$(mktemp -p "$STUB_DIR" resp.XXXX)
  printf '%s' "$3" > "$f"
  printf '%s\t%s\t%s\n' "$1" "$2" "$(basename "$f")" >> "$STUB_DIR/rules.tsv"
}
calls() { cat "$STUB_DIR/calls.log"; }
finish() { if [ "$FAILS" -eq 0 ]; then echo "all passed"; else echo "$FAILS failed"; exit 1; fi; }
# The request body of the Nth gh call (1-based), for calls made with --input -.
input_of() { cat "$STUB_DIR/input.$1"; }
