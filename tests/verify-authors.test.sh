#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"

# A clone whose origin/main has one accepted commit, and a feature branch on top.
repo=$(mktemp -d); origin=$(mktemp -d)
git init -q --bare "$origin"
git -C "$repo" init -q -b main
git -C "$repo" -c user.name='Old Hand' -c user.email=old@gmail.com commit -q --allow-empty -m base
git -C "$repo" remote add origin "$origin"
git -C "$repo" push -q origin main
git -C "$repo" fetch -q origin
git -C "$repo" switch -q -c feature
commit_as() { git -C "$repo" -c user.name="$1" -c user.email="$2" commit -q --allow-empty -m "$3"; }
run() { (cd "$repo" && "$ROOT/scripts/verify-authors.sh" main "$(git rev-parse HEAD)" 2>&1); }

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

git -C "$repo" switch -q -c bad-domain
commit_as 'Dave Cherkassky' dave@evil.markmywork.ca bad
out=$(run); assert_eq "subdomain fails" "$?" 1
assert_contains "subdomain error names the address" "$out" "dave@evil.markmywork.ca' is not a @markmywork.ca address"

git -C "$repo" switch -q feature && git -C "$repo" switch -q -c bad-name
commit_as 'iruletheinternet' x@markmywork.ca bad
out=$(run); assert_eq "single-word name fails" "$?" 1
assert_contains "name error names the name" "$out" "author name 'iruletheinternet' must be a full name"

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
