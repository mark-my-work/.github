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
# fields_json <number>:<labels comma-separated>:<fields comma-separated> ... -> one GraphQL page
fields_json() {
  local spec nodes=() n l f
  for spec in "$@"; do
    IFS=: read -r n l f <<<"$spec"
    nodes+=("$(jq -cn --argjson n "$n" --arg l "$l" --arg f "$f" '{number: $n,
      labels: {totalCount: 0, nodes: ($l | split(",") | map(select(. != "")) | map({name: .}))},
      issueFieldValues: {totalCount: 0, nodes: ($f | split(",") | map(select(. != "")) | map({field: {name: .}}))}}')")
  done
  printf '{"data":{"repository":{"issues":{"totalCount":%s,"pageInfo":{"hasNextPage":false},"nodes":[%s]}}}}' "${TOTAL:-${#nodes[@]}}" "$(IFS=,; echo "${nodes[*]}")"
}
DEFINED='{"data":{"repository":{"issueFields":{"nodes":[{"name":"Priority"},{"name":"Human Effort"}]}}}}'
EXISTS='{"errors":[{"code":"already_exists"}]}'
HAS_LABELS='[{"name":"Epic"},{"name":"needs-priority"},{"name":"needs-effort"}]'

common() {
  stub_gh
  reply 'repo list mark-my-work *' 0 '[{"nameWithOwner":"mark-my-work/mmw","hasIssuesEnabled":true},{"nameWithOwner":"mark-my-work/mmw-hr","hasIssuesEnabled":true},{"nameWithOwner":"mark-my-work/.github-template","hasIssuesEnabled":false}]'
  reply 'api repos/*/labels --paginate *' 0 "$HAS_LABELS"
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
assert_contains "epics: lists private, unarchived repositories" "$log" "repo list mark-my-work --visibility private --no-archived"
assert_contains "epics: adds Epic in mmw" "$log" "issue edit 1 --repo mark-my-work/mmw --add-label Epic"
assert_contains "epics: removes Epic in mmw" "$log" "issue edit 2 --repo mark-my-work/mmw --remove-label Epic"
assert_absent  "epics: leaves a correct Epic alone" "$log" "issue edit 3 "
assert_contains "epics: reaches the second repository" "$log" "issue edit 7 --repo mark-my-work/mmw-hr --add-label Epic"
assert_absent  "epics: skips a repository with issues off" "$log" ".github-template"
assert_absent  "epics: creates no label a repository already has" "$log" "-f name=Epic"

# --- Epic: a label that differs only in case is the same label
common
reply_first 'api repos/*/labels --paginate *' 0 '[{"name":"epic"}]'
reply 'issue list --repo mark-my-work/mmw *' 0 "$(issues_json 4:0:epic 5:1:epic)"
reply 'issue list --repo mark-my-work/mmw-hr *' 0 '[]'
out=$("$SCRIPT" epics 2>&1); assert_eq "case: exits 0" "$?" 0
log=$(calls)
assert_contains "case: removes a lower-case epic from an issue with no sub-issues" "$log" "issue edit 4 --repo mark-my-work/mmw --remove-label Epic"
assert_absent  "case: leaves a lower-case epic on an issue with sub-issues" "$log" "issue edit 5 "
assert_absent  "case: does not create Epic beside epic" "$log" "-f name=Epic"

# --- Epic: more than LIMIT open issues is warned
common
reply 'issue list --repo mark-my-work/mmw *' 0 "$(jq -cn '[range(1; 1003) | {number: ., subIssuesSummary: {total: 0}, labels: []}]')"
reply 'issue list --repo mark-my-work/mmw-hr *' 0 '[]'
out=$("$SCRIPT" epics 2>&1); assert_eq "limit: exits 0" "$?" 0
assert_contains "limit: warns" "$out" "more than 1000 open issues"

# --- Priority: counted across the organization, so a repository with no Priority yet is flagged
common
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 0 "$(fields_json 1::Priority 2:needs-priority:Priority 6:Epic,needs-priority:)"
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw-hr *' 0 "$(fields_json 5:: 6:Epic:)"
out=$("$SCRIPT" priority 2>&1); assert_eq "priority: exits 0" "$?" 0
log=$(calls)
assert_contains "priority: flags an unprioritized issue in a new repository" "$log" "issue edit 5 --repo mark-my-work/mmw-hr --add-label needs-priority"
assert_contains "priority: clears the flag once Priority is set" "$log" "issue edit 2 --repo mark-my-work/mmw --remove-label needs-priority"
assert_absent  "priority: exempts an epic" "$log" "issue edit 6 --repo mark-my-work/mmw-hr"
assert_contains "priority: clears a stale flag from an epic" "$log" "issue edit 6 --repo mark-my-work/mmw --remove-label needs-priority"

# --- Priority: no value anywhere means the field is unreadable, so nothing changes
common
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 0 "$(fields_json 1:: 2::)"
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw-hr *' 0 "$(fields_json 5::)"
out=$("$SCRIPT" priority 2>&1); assert_eq "priority guard: exits 1" "$?" 1
assert_contains "priority guard: says why" "$out" "none has a 'Priority' value"
assert_absent  "priority guard: changes no label" "$(calls)" "issue edit"

# --- Priority and Human Effort share one read per repository
common
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 0 "$(fields_json 1::Priority)"
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw-hr *' 0 "$(fields_json 5::Priority)"
out=$("$SCRIPT" priority effort 2>&1); assert_eq "one read: exits 0" "$?" 0
assert_eq "one read: each repository is read once" "$(grep -c 'graphql --paginate' "$STUB_DIR/calls.log")" 2

# --- Two pages of issues are both reconciled
common
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 0 "$(TOTAL=2 fields_json 1::Priority)$(TOTAL=2 fields_json 9::)"
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw-hr *' 0 "$(fields_json)"
out=$("$SCRIPT" effort 2>&1); assert_eq "pages: exits 0" "$?" 0
log=$(calls)
assert_contains "pages: reconciles the first page" "$log" "issue edit 1 --repo mark-my-work/mmw --add-label needs-effort"
assert_contains "pages: reconciles the second page" "$log" "issue edit 9 --repo mark-my-work/mmw --add-label needs-effort"
assert_absent  "pages: no short-read warning" "$out" "open issues; the rest"

# --- Fewer issues read than exist is warned
common
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 0 "$(TOTAL=5 fields_json 1::Priority,'Human Effort')"
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw-hr *' 0 "$(fields_json)"
out=$("$SCRIPT" effort 2>&1)
assert_contains "short read: warns" "$out" "read 1 of 5 open issues"

# --- An issue with over 100 labels or field values is warned
common
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 0 '{"data":{"repository":{"issues":{"totalCount":1,"pageInfo":{"hasNextPage":false},"nodes":[{"number":3,"labels":{"totalCount":101,"nodes":[]},"issueFieldValues":{"totalCount":0,"nodes":[{"field":{"name":"Human Effort"}}]}}]}}}}'
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw-hr *' 0 "$(fields_json)"
out=$("$SCRIPT" effort 2>&1)
assert_contains "over 100: warns" "$out" "issue(s) #3 have over 100 labels or field values"

# --- Effort: one repository failing does not stop the others, and the run fails
common
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 1 '{"message":"boom"}'
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw-hr *' 0 "$(fields_json 5::Priority)"
out=$("$SCRIPT" effort 2>&1); assert_eq "isolation: exits 1" "$?" 1
assert_contains "isolation: names the failed repository" "$out" "mark-my-work/mmw: Human Effort read"
assert_contains "isolation: still reconciles the other" "$(calls)" "issue edit 5 --repo mark-my-work/mmw-hr --add-label needs-effort"

# --- Effort: a repository that cannot see the field is left alone
common
reply_first 'api graphql -f owner=mark-my-work -f repo=mmw-hr *issueFields*' 0 '{"data":{"repository":{"issueFields":{"nodes":[]}}}}'
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 0 "$(fields_json 1::)"
out=$("$SCRIPT" effort 2>&1); assert_eq "effort guard: exits 1" "$?" 1
assert_contains "effort guard: says the field is not visible" "$out" "mark-my-work/mmw-hr: no issue field named 'Human Effort' is visible"
assert_absent "effort guard: reads nothing there" "$(calls)" "graphql --paginate -f owner=mark-my-work -f repo=mmw-hr"

# --- Effort: an unreadable field list is reported as that, not as a missing field
common
reply_first 'api graphql -f owner=mark-my-work -f repo=mmw-hr *issueFields*' 1 '{"message":"Bad gateway"}'
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 0 "$(fields_json 1::)"
out=$("$SCRIPT" effort 2>&1); assert_eq "field read: exits 1" "$?" 1
assert_contains "field read: says the read failed" "$out" "mark-my-work/mmw-hr: could not read the issue field definitions"
assert_absent "field read: does not blame the field" "$out" "mmw-hr: no issue field named"

# --- A failed add is a failure
common
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw *' 0 "$(fields_json 1::Priority)"
reply 'api graphql --paginate -f owner=mark-my-work -f repo=mmw-hr *' 0 "$(fields_json 5::)"
reply_first 'issue edit 5 *' 1 ''
out=$("$SCRIPT" effort 2>&1); assert_eq "failed add: exits 1" "$?" 1
assert_contains "failed add: is recorded" "$out" "mark-my-work/mmw-hr: needs-effort reconcile"

# --- A removal that fails because the label is already gone is not a failure, and says so
common
reply 'issue list --repo mark-my-work/mmw *' 0 "$(issues_json 2:0:Epic)"
reply 'issue list --repo mark-my-work/mmw-hr *' 0 '[]'
reply_first 'issue edit 2 *' 1 ''
reply_first 'issue view 2 *' 0 '{"labels":[]}'
out=$("$SCRIPT" epics 2>&1); assert_eq "concurrent removal: exits 0" "$?" 0
assert_contains "concurrent removal: re-reads the issue" "$(calls)" "issue view 2 --repo mark-my-work/mmw --json labels"
assert_contains "concurrent removal: says so" "$out" "mark-my-work/mmw#2: Epic no longer present"

# --- A missing label is created; a failure to create it is reported with gh's reason
common
reply_first 'api repos/*/labels --paginate *' 0 '[]'
reply_first 'api repos/mark-my-work/mmw/labels -f *' 0 '{}'
reply_first 'api repos/mark-my-work/mmw-hr/labels -f *' 1 '' 'Post "https://api.github.com/x": proxyconnect tcp: connection refused'
reply 'issue list --repo *' 0 '[]'
out=$("$SCRIPT" epics 2>&1); assert_eq "labels: exits 1" "$?" 1
assert_contains "labels: creates a missing label" "$(calls)" "api repos/mark-my-work/mmw/labels -f name=Epic"
assert_contains "labels: reports the failure" "$out" "mark-my-work/mmw-hr: Epic label"
assert_contains "labels: keeps gh's reason" "$out" "connection refused"

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

# --- An unknown argument is a usage error, not a run that does nothing
stub_gh
out=$("$SCRIPT" epic 2>&1); assert_eq "unknown argument: exits 2" "$?" 2
assert_contains "unknown argument: names it" "$out" "unknown argument 'epic'"
assert_absent "unknown argument: lists nothing" "$(calls)" "repo list"

# --- The workflow passes each ticked input as its argument
wf="$ROOT/.github/workflows/reconcile-issue-labels.yml"
for pair in EPICS:epics PRIORITY:priority EFFORT:effort; do
  assert_contains "workflow: maps ${pair%%:*}" "$(cat "$wf")" "if [ \"\$${pair%%:*}\" = true ]; then selected+=(${pair#*:}); fi"
done

finish
