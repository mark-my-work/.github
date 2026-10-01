#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
SCRIPT="$ROOT/bin/apply-rulesets"

stub_gh
reply 'api repos/mark-my-work/.github --jq .id' 0 '{"id":777}'
reply 'api orgs/mark-my-work/rulesets --paginate *' 0 '[{"name":"default-branch","id":11},{"name":"MAIN-old","id":12}]'
reply 'api -X PUT orgs/mark-my-work/rulesets/11 *' 0 '{}'
reply 'api -X POST orgs/mark-my-work/rulesets *' 0 '{}'
out=$("$SCRIPT" 2>&1); assert_eq "exits 0" "$?" 0
log=$(calls)
assert_contains "updates an existing ruleset by name" "$log" "api -X PUT orgs/mark-my-work/rulesets/11 --input -"
assert_contains "creates a missing one" "$log" "api -X POST orgs/mark-my-work/rulesets --input -"
assert_contains "reports a ruleset no file names" "$out" "Ruleset MAIN-old (12) is in the organization but in no file; left unchanged."
assert_absent "never deletes" "$log" "-X DELETE"
put=$(grep -n 'rulesets/11' "$STUB_DIR/calls.log" | cut -d: -f1)
bodies=$(grep -n -- '--input -' "$STUB_DIR/calls.log" | cut -d: -f1 | while read -r n; do input_of "$n"; done)
assert_eq "fills in .github's repository id" "$(jq -s '[.. | .repository_id? // empty] | unique' <<<"$bodies")" '[
  777
]'
assert_eq "no bypass" "$(input_of "$put" | jq -c .bypass_actors)" '[]'
assert_eq "merge commits only" "$(input_of "$put" | jq -c '.rules[] | select(.type == "pull_request") | .parameters.allowed_merge_methods')" '["merge"]'

for file in "$ROOT"/rulesets/*.json; do
  if jq -e . "$file" >/dev/null; then pass "$(basename "$file") is valid JSON"; else fail "$(basename "$file") is not valid JSON"; fi
  assert_eq "$(basename "$file"): active, on default branches, no bypass" \
    "$(jq -c '[.target, .enforcement, .conditions.ref_name.include, .bypass_actors]' "$file")" '["branch","active",["~DEFAULT_BRANCH"],[]]'
  while IFS= read -r path; do
    if [ -f "$ROOT/$path" ]; then pass "$(basename "$file"): requires $path, which exists"
    else fail "$(basename "$file"): requires $path, which is not in .github/workflows"; fi
  done < <(jq -r '.rules[] | select(.type == "workflows") | .parameters.workflows[].path' "$file")
  assert_eq "$(basename "$file"): required workflows run from .github's main" \
    "$(jq -c '[.rules[] | select(.type == "workflows") | .parameters | (.do_not_enforce_on_create, (.workflows[] | .repository_id, .ref))] | unique' "$file")" \
    "$(jq -c '[.rules[] | select(.type == "workflows")] | if length == 0 then [] else [true,"SETUP_REPO_ID","refs/heads/main"] end' "$file")"
done

db="$ROOT/rulesets/default-branch.json"
# Task 6 stages this file on mmw-scratch-* without its workflows rule; Task 14 restores ~ALL.
assert_contains "default-branch: every repository, or the staged scratch name" '["~ALL"] ["mmw-scratch-*"]' "$(jq -c .conditions.repository_name.include "$db")"
assert_contains "default-branch: blocks deletion, force-push, and needs a pull request" \
  "$(jq -c '[.rules[].type]' "$db")" '"deletion","non_fast_forward","pull_request"'
assert_eq "default-branch: no approval required, merge commits only" \
  "$(jq -c '.rules[] | select(.type == "pull_request") | .parameters | [.required_approving_review_count, .allowed_merge_methods]' "$db")" '[0,["merge"]]'
grc="$ROOT/rulesets/github-repo-checks.json"
assert_eq "github-repo-checks: .github only" "$(jq -c .conditions.repository_name.include "$grc")" '[".github"]'
assert_eq "github-repo-checks: requires check-triggers and test" \
  "$(jq -c '[.rules[] | select(.type == "workflows") | .parameters.workflows[].path] | sort' "$grc")" \
  '[".github/workflows/check-triggers.yml",".github/workflows/test.yml"]'

finish
