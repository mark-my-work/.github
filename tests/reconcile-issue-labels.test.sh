#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
SCRIPT="$ROOT/scripts/reconcile-issue-labels.sh"

# issues_json <number>:<sub-issues>:<labels comma-separated> ... -> `gh issue list` JSON
issues_json() {
  local spec items=() n s l
  for spec in "$@"; do
    IFS=: read -r n s l <<<"$spec"
    items+=("{\"number\":$n,\"subIssuesSummary\":{\"total\":$s},\"labels\":$(jq -cn --arg l "$l" '$l | split(",") | map(select(. != "")) | map({name: .})')}")
  done
  printf '[%s]' "$(IFS=,; echo "${items[*]}")"
}
# fields_json <number>:<labels comma-separated>:<fields comma-separated> ... -> GraphQL page
fields_json() {
  local spec nodes=() n l f
  for spec in "$@"; do
    IFS=: read -r n l f <<<"$spec"
    nodes+=("$(jq -cn --argjson n "$n" --arg l "$l" --arg f "$f" '{number: $n,
      labels: {totalCount: 0, nodes: ($l | split(",") | map(select(. != "")) | map({name: .}))},
      issueFieldValues: {totalCount: 0, nodes: ($f | split(",") | map(select(. != "")) | map({field: {name: .}}))}}')")
  done
  printf '{"data":{"repository":{"issues":{"pageInfo":{"hasNextPage":false},"nodes":[%s]}}}}' "$(IFS=,; echo "${nodes[*]}")"
}
DEFINED='{"data":{"repository":{"issueFields":{"nodes":[{"name":"Priority"},{"name":"Human Effort"}]}}}}'
EXISTS='{"errors":[{"code":"already_exists"}]}'

common() {
  stub_gh
  reply 'repo list mark-my-work *' 0 '[{"nameWithOwner":"mark-my-work/mmw","hasIssuesEnabled":true},{"nameWithOwner":"mark-my-work/mmw-hr","hasIssuesEnabled":true},{"nameWithOwner":"mark-my-work/.github-template","hasIssuesEnabled":false}]'
  reply 'api repos/*/labels *' 1 "$EXISTS"
  reply 'issue edit *' 0 ''
  reply 'api graphql -f owner=mark-my-work -f repo=* issueFields*' 0 "$DEFINED"
}

# --- Epic: added where sub-issues exist, removed where none, in two repositories
common
reply 'issue list --repo mark-my-work/mmw *' 0 "$(issues_json 1:2: 2:0:Epic 3:1:Epic)"
reply 'issue list --repo mark-my-work/mmw-hr *' 0 "$(issues_json 7:3:)"
out=$("$SCRIPT" epics 2>&1); assert_eq "epics: exits 0" "$?" 0
log=$(calls)
assert_contains "epics: adds Epic in mmw" "$log" "issue edit 1 --repo mark-my-work/mmw --add-label Epic"
assert_contains "epics: removes Epic in mmw" "$log" "issue edit 2 --repo mark-my-work/mmw --remove-label Epic"
assert_absent  "epics: leaves a correct Epic alone" "$log" "issue edit 3 "
assert_contains "epics: reaches the second repository" "$log" "issue edit 7 --repo mark-my-work/mmw-hr --add-label Epic"
assert_absent  "epics: skips a repository with issues off" "$log" ".github-template"

# --- Priority: counted across the organization, so a repository with no Priority yet is flagged
common
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 0 "$(fields_json 1::Priority 2:needs-priority:Priority)"
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw-hr *' 0 "$(fields_json 5:: 6:Epic:)"
out=$("$SCRIPT" priority 2>&1); assert_eq "priority: exits 0" "$?" 0
log=$(calls)
assert_contains "priority: flags an unprioritized issue in a new repository" "$log" "issue edit 5 --repo mark-my-work/mmw-hr --add-label needs-priority"
assert_contains "priority: clears the flag once Priority is set" "$log" "issue edit 2 --repo mark-my-work/mmw --remove-label needs-priority"
assert_absent  "priority: exempts an epic" "$log" "issue edit 6 "

# --- Priority: no value anywhere means the field is unreadable, so nothing changes
common
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 0 "$(fields_json 1:: 2::)"
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw-hr *' 0 "$(fields_json 5::)"
out=$("$SCRIPT" priority 2>&1); assert_eq "priority guard: exits 1" "$?" 1
assert_contains "priority guard: says why" "$out" "none has a 'Priority' value"
assert_absent  "priority guard: changes no label" "$(calls)" "issue edit"

# --- Effort: one repository failing does not stop the others, and the run fails
common
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 1 '{"message":"boom"}'
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw-hr *' 0 "$(fields_json 5::Priority)"
out=$("$SCRIPT" effort 2>&1); assert_eq "isolation: exits 1" "$?" 1
assert_contains "isolation: names the failed repository" "$out" "mark-my-work/mmw: Human Effort read"
assert_contains "isolation: still reconciles the other" "$(calls)" "issue edit 5 --repo mark-my-work/mmw-hr --add-label needs-effort"

# --- Effort: a repository that cannot see the field is left alone
common
reply 'api graphql -f owner=mark-my-work -f repo=mmw-hr issueFields*' 0 '{"data":{"repository":{"issueFields":{"nodes":[]}}}}'
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 0 "$(fields_json 1::)"
out=$("$SCRIPT" effort 2>&1); assert_eq "effort guard: exits 1" "$?" 1
assert_absent "effort guard: changes nothing where the field is invisible" "$(calls)" "--repo mark-my-work/mmw-hr --add-label"

# --- A removal that fails because the label is already gone is not a failure
common
reply 'issue list --repo mark-my-work/mmw *' 0 "$(issues_json 2:0:Epic)"
reply 'issue list --repo mark-my-work/mmw-hr *' 0 '[]'
reply 'issue edit 2 *' 1 ''
reply 'issue view 2 *' 0 '{"labels":[]}'
out=$("$SCRIPT" epics 2>&1); assert_eq "concurrent removal: exits 0" "$?" 0

# --- A new repository with no open issues reconciles cleanly and changes nothing there
common
reply 'issue list --repo mark-my-work/mmw *' 0 "$(issues_json 1:1:Epic)"
reply 'issue list --repo mark-my-work/mmw-hr *' 0 '[]'
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 0 "$(fields_json 1:Epic:Priority)"
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw-hr *' 0 "$(fields_json)"
out=$("$SCRIPT" 2>&1); assert_eq "empty repository: exits 0" "$?" 0
assert_absent "empty repository: changes nothing" "$(calls)" "issue edit"

# --- No repositories listed is a failure, not a clean run
stub_gh
reply 'repo list mark-my-work *' 0 '[]'
out=$("$SCRIPT" 2>&1); assert_eq "empty listing: exits 1" "$?" 1

finish
