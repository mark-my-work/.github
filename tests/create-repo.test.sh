#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
SCRIPT="$ROOT/bin/create-repo"
NOT_FOUND='gh: Not Found (HTTP 404)'
REPO_STATE='api repos/mark-my-work/mmw-hr --jq "*'

# owner [scopes]: signed in as an org owner whose token has these scopes.
owner() {
  stub_gh
  reply 'api user --jq .login' 0 '{"login":"dcherk"}'
  reply 'api orgs/mark-my-work/memberships/dcherk *' 0 '{"role":"admin"}'
  reply 'api -i user' 0 "HTTP/2.0 200 OK"$'\r\n'"X-Oauth-Scopes: ${1:-admin:org, repo, workflow}"$'\r\n\r\n{}'
}
# line_of <text>: the call-log line number of the first call containing text.
line_of() { grep -nF -- "$1" "$STUB_DIR/calls.log" | head -n 1 | cut -d: -f1; }

# --- A new repository: every step runs, in order
owner
reply "$REPO_STATE" 1 '{"message":"Not Found"}' "$NOT_FOUND"
reply 'repo create *' 0 ''
reply 'api repos/mark-my-work/mmw-hr --jq .id' 0 '{"id":42}'
reply 'api -X PATCH *' 0 '{}'
reply 'api orgs/mark-my-work/teams/hr *' 1 '{"message":"Not Found"}' "$NOT_FOUND"
reply 'api -X POST orgs/mark-my-work/teams *' 0 '{}'
reply 'api -X PUT *' 0 ''
out=$("$SCRIPT" mmw-hr --team hr 2>&1); assert_eq "new: exits 0" "$?" 0
log=$(calls)
assert_contains "new: creates from the template" "$log" "repo create mark-my-work/mmw-hr --private --template mark-my-work/.github-template"
assert_contains "new: sets merge commits only on the repository" "$log" "api -X PATCH repos/mark-my-work/mmw-hr -F allow_merge_commit=true -F allow_squash_merge=false -F allow_rebase_merge=false -F delete_branch_on_merge=true -F allow_auto_merge=false"
assert_contains "new: creates the team" "$log" "api -X POST orgs/mark-my-work/teams -f name=hr -f privacy=closed"
assert_contains "new: grants the team push" "$log" "api -X PUT orgs/mark-my-work/teams/hr/repos/mark-my-work/mmw-hr -f permission=push"
assert_contains "new: shares the app key" "$log" "api -X PUT orgs/mark-my-work/actions/secrets/MMW_AUTOMATION_PRIVATE_KEY/repositories/42"
create=$(line_of "repo create"); patch=$(line_of "-X PATCH"); team=$(line_of "-X POST orgs/mark-my-work/teams")
grant=$(line_of "teams/hr/repos"); share=$(line_of "actions/secrets")
if [ "$create" -lt "$patch" ] && [ "$patch" -lt "$team" ] && [ "$team" -lt "$grant" ] && [ "$grant" -lt "$share" ]; then
  pass "new: runs the steps in order"
else
  fail "new: runs the steps in order (create $create, patch $patch, team $team, grant $grant, share $share)"
fi
assert_contains "new: lists the board step" "$out" "Auto-add to project"
assert_absent "new: lists no plugin step" "$out" "Claude Code plugins"
assert_absent "new: lists no label step" "$out" "default labels"
assert_contains "new: lists completing the files" "$out" "Complete README.md and CLAUDE.md"
assert_contains "new: lists leaving the team" "$out" "Remove yourself from the team hr"

# --- Run again: nothing is created twice
owner
reply "$REPO_STATE" 0 '{"archived":false,"private":true,"template_repository":{"full_name":"mark-my-work/.github-template"}}'
reply 'api repos/mark-my-work/mmw-hr --jq .id' 0 '{"id":42}'
reply 'api -X PATCH *' 0 '{}'
reply 'api orgs/mark-my-work/teams/hr *' 0 '{"slug":"hr"}'
reply 'api -X PUT *' 0 ''
out=$("$SCRIPT" mmw-hr --team hr 2>&1); assert_eq "rerun: exits 0" "$?" 0
log=$(calls)
assert_absent "rerun: does not create the repository again" "$log" "repo create"
assert_absent "rerun: does not create the team again" "$log" "orgs/mark-my-work/teams -f name"
assert_contains "rerun: shares the key with the existing id" "$log" "secrets/MMW_AUTOMATION_PRIVATE_KEY/repositories/42"

# --- An existing repository not made from the template, or not private: stops, changing nothing
for state in \
    'not from the template|{"archived":false,"private":true,"template_repository":null}' \
    'public|{"archived":false,"private":false,"template_repository":{"full_name":"mark-my-work/.github-template"}}'; do
  owner
  reply "$REPO_STATE" 0 "${state#*|}"
  out=$("$SCRIPT" mmw-hr --team hr 2>&1); assert_eq "adopt ${state%%|*}: exits 1" "$?" 1
  assert_contains "adopt ${state%%|*}: says why" "$out" "mark-my-work/mmw-hr exists and was not created by create-repo"
  assert_absent "adopt ${state%%|*}: changes no setting" "$(calls)" "-X P"
done

# --- An archived repository of that name: stops, changing nothing
owner
reply "$REPO_STATE" 0 '{"archived":true,"private":true,"template_repository":{"full_name":"mark-my-work/.github-template"}}'
out=$("$SCRIPT" mmw-hr --team hr 2>&1); assert_eq "archived: exits 1" "$?" 1
assert_contains "archived: says why" "$out" "mark-my-work/mmw-hr exists and is archived"
assert_absent "archived: changes no setting" "$(calls)" "-X PATCH"

# --- A lookup that fails for any reason but 404 stops with gh's reason, not a guess
owner
reply "$REPO_STATE" 1 '' 'gh: Server Error (HTTP 502)'
out=$("$SCRIPT" mmw-hr --team hr 2>&1); assert_eq "lookup error: exits 1" "$?" 1
assert_contains "lookup error: shows gh's reason" "$out" "HTTP 502"
assert_absent "lookup error: creates nothing" "$(calls)" "repo create"
stub_gh
reply 'api user --jq .login' 0 '{"login":"dcherk"}'
reply 'api orgs/mark-my-work/memberships/dcherk *' 1 '' 'gh: Server Error (HTTP 500)'
out=$("$SCRIPT" mmw-hr --team hr 2>&1); assert_eq "membership error: exits 1" "$?" 1
assert_contains "membership error: shows gh's reason" "$out" "HTTP 500"
assert_absent "membership error: does not call it a non-owner" "$out" "not an owner"

# --- Not an owner: stops before creating anything
stub_gh
reply 'api user --jq .login' 0 '{"login":"lana"}'
reply 'api orgs/mark-my-work/memberships/lana *' 0 '{"role":"member"}'
out=$("$SCRIPT" mmw-hr --team hr 2>&1); assert_eq "member: exits 1" "$?" 1
assert_contains "member: says why" "$out" "lana is not an owner of mark-my-work (role: member)"
assert_absent "member: creates nothing" "$(calls)" "repo create"

# --- Missing scope: names the command that adds it, for each scope
for missing in admin:org repo; do
  if [ "$missing" = repo ]; then owner 'admin:org, workflow'; else owner 'repo, workflow'; fi
  out=$("$SCRIPT" mmw-hr --team hr 2>&1); assert_eq "scope $missing: exits 1" "$?" 1
  assert_contains "scope $missing: names the fix" "$out" "gh auth refresh -s $missing"
  assert_absent "scope $missing: creates nothing" "$(calls)" "repo create"
done

# --- Arguments that are not a name and a team slug are usage errors, before any call
for args in "mmw-hr" "mmw-hr --team" "mmw-hr --team --foo" "mmw-hr --team Data\ Science" "mmw-hr --team HR" \
    "mmw\ hr --team hr" "mark-my-work/mmw-hr --team hr" "mmw-hr extra --team hr" "mmw-hr --bogus --team hr"; do
  stub_gh
  eval "set -- $args"
  out=$("$SCRIPT" "$@" 2>&1); assert_eq "usage [$args]: exits 1" "$?" 1
  assert_contains "usage [$args]: prints usage" "$out" "usage: create-repo <name> --team <team-slug>"
  assert_absent "usage [$args]: calls nothing" "$(calls)" "api"
done

finish
