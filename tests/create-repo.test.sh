#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
SCRIPT="$ROOT/bin/create-repo"

# owner [scopes]: signed in as an org owner whose token has these scopes.
owner() {
  stub_gh
  reply 'api user --jq .login' 0 '{"login":"dcherk"}'
  reply 'api orgs/mark-my-work/memberships/dcherk *' 0 '{"role":"admin"}'
  reply 'api -i user' 0 "HTTP/2.0 200 OK"$'\r\n'"X-Oauth-Scopes: ${1:-admin:org, repo, workflow}"$'\r\n\r\n{}'
}

# --- A new repository: every step runs, in order
owner
reply 'repo view mark-my-work/mmw-hr *' 1 '{"message":"Not Found"}'
reply 'repo create *' 0 ''
reply 'api repos/mark-my-work/mmw-hr --jq .id' 0 '{"id":42}'
reply 'api -X PATCH *' 0 '{}'
reply 'api orgs/mark-my-work/teams/hr *' 1 '{"message":"Not Found"}'
reply 'api -X POST orgs/mark-my-work/teams *' 0 '{}'
reply 'api -X PUT *' 0 ''
out=$("$SCRIPT" mmw-hr --team hr 2>&1); assert_eq "new: exits 0" "$?" 0
log=$(calls)
assert_contains "new: creates from the template" "$log" "repo create mark-my-work/mmw-hr --private --template mark-my-work/.github-template"
assert_contains "new: merge commits only" "$log" "-F allow_merge_commit=true -F allow_squash_merge=false -F allow_rebase_merge=false -F delete_branch_on_merge=true -F allow_auto_merge=false"
assert_contains "new: creates the team" "$log" "api -X POST orgs/mark-my-work/teams -f name=hr -f privacy=closed"
assert_contains "new: grants the team push" "$log" "api -X PUT orgs/mark-my-work/teams/hr/repos/mark-my-work/mmw-hr -f permission=push"
assert_contains "new: shares the app key" "$log" "api -X PUT orgs/mark-my-work/actions/secrets/MMW_AUTOMATION_PRIVATE_KEY/repositories/"
assert_contains "new: lists the manual steps" "$out" "Auto-add to project"

# --- Run again: nothing is created twice
owner
reply 'repo view mark-my-work/mmw-hr *' 0 '{"isArchived":false}'
reply 'api repos/mark-my-work/mmw-hr --jq .id' 0 '{"id":42}'
reply 'api -X PATCH *' 0 '{}'
reply 'api orgs/mark-my-work/teams/hr *' 0 '{"slug":"hr"}'
reply 'api -X PUT *' 0 ''
out=$("$SCRIPT" mmw-hr --team hr 2>&1); assert_eq "rerun: exits 0" "$?" 0
log=$(calls)
assert_absent "rerun: does not create the repository again" "$log" "repo create"
assert_absent "rerun: does not create the team again" "$log" "orgs/mark-my-work/teams -f name"
assert_contains "rerun: shares the key with the existing id" "$log" "secrets/MMW_AUTOMATION_PRIVATE_KEY/repositories/42"

# --- An archived repository of that name: stops, changing nothing
owner
reply 'repo view mark-my-work/mmw-hr *' 0 '{"isArchived":true}'
out=$("$SCRIPT" mmw-hr --team hr 2>&1); assert_eq "archived: exits 1" "$?" 1
assert_contains "archived: says why" "$out" "mark-my-work/mmw-hr exists and is archived"
assert_absent "archived: changes no setting" "$(calls)" "-X PATCH"

# --- Not an owner: stops before creating anything
stub_gh
reply 'api user --jq .login' 0 '{"login":"lana"}'
reply 'api orgs/mark-my-work/memberships/lana *' 0 '{"role":"member"}'
out=$("$SCRIPT" mmw-hr --team hr 2>&1); assert_eq "member: exits 1" "$?" 1
assert_contains "member: says why" "$out" "lana is not an owner of mark-my-work (role: member)"
assert_absent "member: creates nothing" "$(calls)" "repo create"

# --- Missing scope: names the command that adds it
owner repo
out=$("$SCRIPT" mmw-hr --team hr 2>&1); assert_eq "scope: exits 1" "$?" 1
assert_contains "scope: names the fix" "$out" "gh auth refresh -s admin:org"
assert_absent "scope: creates nothing" "$(calls)" "repo create"

# --- Missing --team is a usage error
stub_gh
out=$("$SCRIPT" mmw-hr 2>&1); assert_eq "usage: exits 1" "$?" 1
assert_contains "usage: prints usage" "$out" "usage: create-repo <name> --team <team-slug>"

finish
