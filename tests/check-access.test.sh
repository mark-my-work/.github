#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
SCRIPT="$ROOT/bin/check-access"

# The organization as #926 configures it. Each case below changes one part of it with jq.
GRAPHQL=$(jq -c . <<'JSON'
{"data":{"organization":{
  "membersWithRole":{"pageInfo":{"hasNextPage":false},"edges":[
    {"role":"ADMIN","node":{"login":"dcherk"}},
    {"role":"ADMIN","node":{"login":"david-lorber"}},
    {"role":"MEMBER","node":{"login":"lanamitchell-create"}},
    {"role":"MEMBER","node":{"login":"mvajpey8"}},
    {"role":"MEMBER","node":{"login":"pbjr88"}}]},
  "projectsV2":{"pageInfo":{"hasNextPage":false},"nodes":[{"number":2,"closed":false}]},
  "teams":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"slug":"org-owners","parentTeam":null,
     "members":{"pageInfo":{"hasNextPage":false},"edges":[
       {"role":"MAINTAINER","node":{"login":"dcherk"}},
       {"role":"MEMBER","node":{"login":"david-lorber"}},
       {"role":"MAINTAINER","node":{"login":"lanamitchell-create"}}]},
     "write":{"nodes":[]},"admin":{"nodes":[]}},
    {"slug":"org-func-administrators","parentTeam":null,
     "members":{"pageInfo":{"hasNextPage":false},"edges":[
       {"role":"MAINTAINER","node":{"login":"dcherk"}},
       {"role":"MAINTAINER","node":{"login":"lanamitchell-create"}}]},
     "write":{"nodes":[{"number":2}]},"admin":{"nodes":[{"number":2}]}},
    {"slug":"mmw","parentTeam":null,
     "members":{"pageInfo":{"hasNextPage":false},"edges":[
       {"role":"MAINTAINER","node":{"login":"dcherk"}},
       {"role":"MEMBER","node":{"login":"david-lorber"}},
       {"role":"MAINTAINER","node":{"login":"lanamitchell-create"}},
       {"role":"MEMBER","node":{"login":"mvajpey8"}},
       {"role":"MEMBER","node":{"login":"pbjr88"}}]},
     "write":{"nodes":[{"number":2}]},"admin":{"nodes":[]}},
    {"slug":"mmw-dept-product","parentTeam":{"slug":"mmw"},
     "members":{"pageInfo":{"hasNextPage":false},"edges":[
       {"role":"MAINTAINER","node":{"login":"dcherk"}},
       {"role":"MEMBER","node":{"login":"david-lorber"}},
       {"role":"MAINTAINER","node":{"login":"lanamitchell-create"}},
       {"role":"MEMBER","node":{"login":"mvajpey8"}},
       {"role":"MEMBER","node":{"login":"pbjr88"}}]},
     "write":{"nodes":[]},"admin":{"nodes":[]}},
    {"slug":"mmw-func-developers","parentTeam":{"slug":"mmw"},
     "members":{"pageInfo":{"hasNextPage":false},"edges":[
       {"role":"MAINTAINER","node":{"login":"dcherk"}},
       {"role":"MAINTAINER","node":{"login":"lanamitchell-create"}}]},
     "write":{"nodes":[]},"admin":{"nodes":[]}}]}}}}
JSON
)
SETTINGS='{"default_repository_permission":"none","members_can_create_repositories":false,"members_can_create_teams":false,"members_can_invite_outside_collaborators":false}'
ROLES='{"total_count":4,"roles":[{"id":8136,"name":"all_repo_admin"},{"id":8135,"name":"all_repo_maintain"},{"id":8133,"name":"all_repo_triage"},{"id":8134,"name":"all_repo_write"}]}'

# good_org [scopes]: signed in as an owner, with every read answering as #926 configures it.
good_org() {
  stub_gh
  reply 'api user --jq .login' 0 '{"login":"dcherk"}'
  reply 'api orgs/mark-my-work/memberships/dcherk *' 0 '{"role":"admin"}'
  reply 'api -i user' 0 "HTTP/2.0 200 OK"$'\r\n'"X-Oauth-Scopes: ${1:-admin:org, repo, workflow}"$'\r\n\r\n{}'
  reply 'api orgs/mark-my-work --jq *' 0 "$SETTINGS"
  reply 'api graphql *' 0 "$GRAPHQL"
  reply 'api orgs/mark-my-work/outside_collaborators *' 0 '[]'
  reply 'api orgs/mark-my-work/repos *' 0 '[{"name":"mmw"},{"name":".github"}]'
  reply 'api repos/mark-my-work/*/collaborators?affiliation=direct *' 0 '[]'
  reply 'api repos/mark-my-work/mmw/teams *' 0 '[{"slug":"mmw-dept-product","permission":"push"}]'
  reply 'api repos/mark-my-work/.github/teams *' 0 '[]'
  reply 'api orgs/mark-my-work/organization-roles --jq *' 0 "$ROLES"
  reply 'api orgs/mark-my-work/organization-roles/8136/teams *' 0 '[{"slug":"org-func-administrators","assignment":"direct"}]'
  reply 'api orgs/mark-my-work/organization-roles/8135/teams *' 0 '[]'
  reply 'api orgs/mark-my-work/organization-roles/8133/teams *' 0 '[{"slug":"mmw","assignment":"direct"},{"slug":"mmw-dept-product","assignment":"indirect"},{"slug":"mmw-func-developers","assignment":"indirect"}]'
  reply 'api orgs/mark-my-work/organization-roles/8134/teams *' 0 '[{"slug":"mmw-func-developers","assignment":"direct"}]'
  reply 'api orgs/mark-my-work/organization-roles/*/users *' 0 '[{"login":"dcherk","assignment":"indirect"}]'
}
# graphql <jq filter>: answers the GraphQL query with the good organization changed by the filter.
graphql() { reply_first 'api graphql *' 0 "$(jq -c "$1" <<<"$GRAPHQL")"; }
# a jq path to one team, by slug
T='.data.organization.teams.nodes'
team() { printf '%s[] | select(.slug == "%s")' "$T" "$1"; }

# violation <case> <expected line>: runs the check and asserts it fails with that line.
violation() {
  local out status
  out=$("$SCRIPT" 2>&1); status=$?
  assert_eq "$1: exits 1" "$status" 1
  assert_contains "$1: reports it" "$out" "$2"
}

# --- The organization as #926 configures it: no violations
good_org
out=$("$SCRIPT" 2>&1); assert_eq "good: exits 0" "$?" 0
assert_contains "good: says so" "$out" "No violations."
assert_absent "good: changes nothing" "$(calls)" "-X "

# --- Owners and org-owners
good_org
graphql '(.data.organization.membersWithRole.edges[] | select(.node.login == "mvajpey8") | .role) = "ADMIN"'
violation "extra owner" "owner mvajpey8 is not in org-owners"
good_org
graphql "($(team org-owners) | .members.edges) += [{\"role\":\"MEMBER\",\"node\":{\"login\":\"pbjr88\"}}]"
violation "org-owners non-owner" "pbjr88 is in org-owners but is neither an owner nor an administrator"
good_org
graphql "del($(team org-owners))"
violation "no org-owners" "the team org-owners does not exist"

# --- Organization settings
for setting in \
    'default_repository_permission|"read"|the base repository permission is read, not none' \
    'members_can_create_repositories|true|members can create repositories' \
    'members_can_create_teams|true|members can create teams' \
    'members_can_invite_outside_collaborators|true|members can invite outside collaborators'; do
  IFS='|' read -r key value message <<<"$setting"
  good_org
  reply_first 'api orgs/mark-my-work --jq *' 0 "$(jq -c ".$key = $value" <<<"$SETTINGS")"
  violation "setting $key" "$message"
done

# --- Collaborators outside teams
good_org
reply_first 'api orgs/mark-my-work/outside_collaborators *' 0 '[{"login":"contractor"}]'
violation "outside collaborator" "contractor is an outside collaborator"
good_org
reply_first 'api repos/mark-my-work/mmw/collaborators?affiliation=direct *' 0 '[{"login":"david-lorber"}]'
violation "direct collaborator" "david-lorber has direct access to mark-my-work/mmw"

# --- Team names and nesting
good_org
graphql "$T += [{\"slug\":\"marketing\",\"parentTeam\":{\"slug\":\"mmw\"},\"members\":{\"pageInfo\":{\"hasNextPage\":false},\"edges\":[{\"role\":\"MAINTAINER\",\"node\":{\"login\":\"dcherk\"}},{\"role\":\"MAINTAINER\",\"node\":{\"login\":\"lanamitchell-create\"}}]},\"write\":{\"nodes\":[]},\"admin\":{\"nodes\":[]}}]"
violation "child name" "the team marketing is inside mmw but is not named mmw-dept-<department> or mmw-func-<function>"
good_org
graphql "$T += [{\"slug\":\"org-owners-dept-x\",\"parentTeam\":{\"slug\":\"org-owners\"},\"members\":{\"pageInfo\":{\"hasNextPage\":false},\"edges\":[{\"role\":\"MAINTAINER\",\"node\":{\"login\":\"dcherk\"}},{\"role\":\"MAINTAINER\",\"node\":{\"login\":\"lanamitchell-create\"}}]},\"write\":{\"nodes\":[]},\"admin\":{\"nodes\":[]}}]"
violation "parent not a company" "the team org-owners-dept-x is inside org-owners, which is not a company team"

# --- Company teams
good_org
graphql "($(team mmw) | .members.edges) |= map(select(.node.login != \"pbjr88\"))"
violation "no company" "pbjr88 is in no company team"
BUD="{\"slug\":\"bud\",\"parentTeam\":null,\"members\":{\"pageInfo\":{\"hasNextPage\":false},\"edges\":[{\"role\":\"MAINTAINER\",\"node\":{\"login\":\"dcherk\"}},{\"role\":\"MAINTAINER\",\"node\":{\"login\":\"lanamitchell-create\"}},{\"role\":\"MEMBER\",\"node\":{\"login\":\"mvajpey8\"}}]},\"write\":{\"nodes\":[]},\"admin\":{\"nodes\":[]}}"
good_org
graphql "$T += [$BUD]"
out=$("$SCRIPT" 2>&1); assert_eq "two companies: exits 1" "$?" 1
assert_contains "two companies: reports the member" "$out" "mvajpey8 is in more than one company team: bud, mmw"
assert_absent "two companies: allows an administrator" "$out" "lanamitchell-create is in more than one company team"
good_org
graphql "$T += [$BUD] | ($(team mmw) | .members.edges) |= map(select(.node.login != \"mvajpey8\"))"
violation "child outside its company" "mvajpey8 is in mmw-dept-product but not in its company team mmw"

# --- Administrators maintain every team
good_org
graphql "($(team mmw-dept-product) | .members.edges[] | select(.node.login == \"lanamitchell-create\") | .role) = \"MEMBER\""
violation "administrator not maintainer" "administrator lanamitchell-create is not a maintainer of mmw-dept-product"
good_org
graphql "del($(team org-func-administrators))"
violation "no administrators team" "the team org-func-administrators does not exist"

# --- Organization roles
good_org
reply_first 'api orgs/mark-my-work/organization-roles/8136/teams *' 0 '[{"slug":"org-func-administrators","assignment":"direct"},{"slug":"mmw","assignment":"direct"}]'
violation "admin role elsewhere" "the team mmw holds all_repo_admin"
good_org
reply_first 'api orgs/mark-my-work/organization-roles/8136/teams *' 0 '[]'
violation "admin role missing" "org-func-administrators does not hold all_repo_admin"
good_org
reply_first 'api orgs/mark-my-work/organization-roles/8135/teams *' 0 '[{"slug":"mmw-func-developers","assignment":"direct"}]'
violation "maintain role" "the team mmw-func-developers holds all_repo_maintain"
good_org
reply_first 'api orgs/mark-my-work/organization-roles/8134/users *' 0 '[{"login":"pbjr88","assignment":"direct"}]'
violation "role to a person" "pbjr88 is assigned all_repo_write directly"
good_org
reply_first 'api orgs/mark-my-work/organization-roles/8134/users *' 0 '[{"login":"pbjr88","assignment":"mixed"}]'
violation "role to a person and a team" "pbjr88 is assigned all_repo_write directly"
good_org
reply_first 'api orgs/mark-my-work/organization-roles/8133/teams *' 0 '[]'
violation "triage missing" "mmw does not hold all_repo_triage"
good_org
reply_first 'api orgs/mark-my-work/organization-roles/8134/teams *' 0 '[]'
violation "write missing" "mmw-func-developers does not hold all_repo_write"

# --- Repository grants that change settings
for perm in maintain admin; do
  good_org
  reply_first 'api repos/mark-my-work/mmw/teams *' 0 "[{\"slug\":\"mmw-dept-product\",\"permission\":\"$perm\"}]"
  violation "grant $perm" "the team mmw-dept-product has $perm on mark-my-work/mmw"
done
good_org
reply_first 'api repos/mark-my-work/mmw/teams *' 0 '[{"slug":"org-func-administrators","permission":"admin"}]'
out=$("$SCRIPT" 2>&1); assert_eq "administrators' grant: exits 0" "$?" 0

# --- The MMW project
good_org
graphql '.data.organization.projectsV2.nodes += [{"number":3,"closed":false},{"number":4,"closed":true}]'
out=$("$SCRIPT" 2>&1); assert_eq "extra project: exits 1" "$?" 1
assert_contains "extra project: reports the open one" "$out" "project 3 is open; the MMW project (2) must be the only one"
assert_absent "extra project: ignores a closed one" "$out" "project 4"
good_org
graphql "($(team mmw) | .write.nodes) = []"
violation "mmw not writer" "mmw does not have Write on the MMW project"
good_org
graphql "($(team org-func-administrators) | .admin.nodes) = []"
violation "administrators not admin" "org-func-administrators does not have Admin on the MMW project"
good_org
graphql "($(team mmw) | .admin.nodes) = [{\"number\":2}]"
violation "other project admin" "the team mmw has Admin on the MMW project"

# --- Several violations are all reported and counted
good_org
reply_first 'api orgs/mark-my-work/outside_collaborators *' 0 '[{"login":"a"},{"login":"b"}]'
out=$("$SCRIPT" 2>&1); assert_eq "count: exits 1" "$?" 1
assert_contains "count: reports the first" "$out" "a is an outside collaborator"
assert_contains "count: reports the second" "$out" "b is an outside collaborator"
assert_contains "count: totals them" "$out" "2 violations."

# --- Cannot check: exits 2, reports no result
stub_gh
reply 'api user --jq .login' 0 '{"login":"lanamitchell-create"}'
reply 'api orgs/mark-my-work/memberships/lanamitchell-create *' 0 '{"role":"member"}'
out=$("$SCRIPT" 2>&1); assert_eq "member: exits 2" "$?" 2
assert_contains "member: says why" "$out" "lanamitchell-create is not an owner of mark-my-work (role: member)"
assert_absent "member: reads nothing else" "$(calls)" "graphql"
good_org 'repo, read:org'
out=$("$SCRIPT" 2>&1); assert_eq "scope: exits 2" "$?" 2
assert_contains "scope: names the fix" "$out" "gh auth refresh -s admin:org"
good_org
reply_first 'api orgs/mark-my-work/repos *' 1 '' 'gh: Server Error (HTTP 502)'
out=$("$SCRIPT" 2>&1); assert_eq "read error: exits 2" "$?" 2
assert_contains "read error: shows gh's reason" "$out" "HTTP 502"
assert_absent "read error: reports no result" "$out" "No violations."
good_org
graphql '.data.organization.teams.pageInfo.hasNextPage = true'
out=$("$SCRIPT" 2>&1); assert_eq "truncated: exits 2" "$?" 2
assert_contains "truncated: says why" "$out" "more than 100"
assert_absent "truncated: reports no result" "$out" "No violations."

# --- Arguments are a usage error, before any call
stub_gh
out=$("$SCRIPT" extra 2>&1); assert_eq "usage: exits 2" "$?" 2
assert_contains "usage: prints usage" "$out" "usage: check-access"
assert_absent "usage: calls nothing" "$(calls)" "api"

finish
