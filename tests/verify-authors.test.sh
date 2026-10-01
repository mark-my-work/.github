#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"

# A working clone whose origin/main has one accepted commit, and a feature branch on top.
repo=$(mktemp -d); origin=$(mktemp -d); ci=$(mktemp -d)
git init -q --bare -b main "$origin"
git -C "$repo" init -q -b main
git -C "$repo" -c user.name='Old Hand' -c user.email=old@gmail.com commit -q --allow-empty -m base
git -C "$repo" remote add origin "$origin"
git -C "$repo" push -q origin main
git -C "$repo" fetch -q origin
git -C "$repo" switch -q -c feature
commit_as() { git -C "$repo" -c user.name="$1" -c user.email="$2" commit -q --allow-empty -m "$3"; }
# Runs the check as CI does: a fresh clone at the head commit, detached, with no local base
# branch, so only origin/main can name the base.
run() {
  local sha; sha=$(git -C "$repo" rev-parse HEAD)
  git -C "$repo" push -q -f origin "$(git -C "$repo" branch --show-current)"
  rm -rf "$ci" && git clone -q "$origin" "$ci" 2>/dev/null
  git -C "$ci" checkout -q --detach "$sha" && git -C "$ci" branch -q -D main
  (cd "$ci" && "$ROOT/scripts/verify-authors.sh" main "$sha" 2>&1)
}

out=$(run); assert_eq "no new commits passes" "$?" 0
assert_contains "no new commits says so" "$out" "No new commits to verify."

commit_as 'Dave Cherkassky' dave@markmywork.ca ok1
out=$(run); assert_eq "corporate author passes" "$?" 0
assert_absent "history already on main is not re-checked" "$out" "old@gmail.com"

commit_as 'Dave Cherkassky' Dave@MarkMyWork.CA ok2
out=$(run); assert_eq "domain match is case-insensitive" "$?" 0

commit_as 'tinacloud-app[bot]' '58178390+tinacloud-app[bot]@users.noreply.github.com' cms
out=$(run); assert_eq "listed bot passes" "$?" 0
assert_contains "listed bot is named" "$out" "bot author 'tinacloud-app[bot]' accepted"

# bad_email <label> <email>: a commit from that address fails and is named.
bad_email() {
  git -C "$repo" switch -q feature && git -C "$repo" switch -q -C "bad-${1// /-}"
  commit_as 'Dave Cherkassky' "$2" bad
  out=$(run); assert_eq "$1 fails" "$?" 1
  assert_contains "$1 error names the address" "$out" "'$2' is not a @markmywork.ca address"
}
bad_email subdomain dave@evil.markmywork.ca
bad_email "domain as local part" markmywork.ca@evil.com
bad_email "empty local part" @markmywork.ca
bad_email "second @" evil@gmail.com@markmywork.ca

# bad_name <label> <name>: a commit by that name fails and is named.
bad_name() {
  git -C "$repo" switch -q feature && git -C "$repo" switch -q -C "bad-${1// /-}"
  commit_as "$2" x@markmywork.ca bad
  out=$(run); assert_eq "$1 fails" "$?" 1
  assert_contains "$1 error names the name" "$out" "author name '$2' must be a full name"
}
bad_name "single-word name" iruletheinternet
bad_name "one word and a digit" 'x 1'
bad_name "one word and a dot" 'dcherk .'
bad_name "no letters" '1 2'

git -C "$repo" switch -q feature && git -C "$repo" switch -q -c both-bad
commit_as 'handle' handle@gmail.com bad
out=$(run); assert_eq "both checks failing fails" "$?" 1
assert_contains "both checks failing names the address" "$out" "'handle@gmail.com' is not a @markmywork.ca address"
assert_contains "both checks failing names the name" "$out" "author name 'handle' must be a full name"

# main moves on with a commit from before the rule, and is merged into the branch
git -C "$repo" switch -q main
git -C "$repo" -c user.name='Old Hand' -c user.email=old@gmail.com commit -q --allow-empty -m later
git -C "$repo" push -q origin main && git -C "$repo" fetch -q origin
git -C "$repo" switch -q feature && git -C "$repo" switch -q -c merged-main
git -C "$repo" -c user.name='Dave Cherkassky' -c user.email=dave@markmywork.ca merge -q --no-edit main
out=$(run); assert_eq "merging main in re-checks none of main's commits" "$?" 0

git -C "$repo" switch -q feature && git -C "$repo" switch -q -c other-bot
commit_as 'dependabot[bot]' '49699333+dependabot[bot]@users.noreply.github.com' deps
out=$(run); assert_eq "unlisted bot fails" "$?" 1

finish
