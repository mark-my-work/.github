#!/usr/bin/env bash
# Keeps three labels correct on every open issue in every private repository of mark-my-work:
#   Epic           <=> the issue has at least one sub-issue
#   needs-priority <=> the issue has no Priority        (epics exempt)
#   needs-effort   <=> the issue has no Human Effort    (epics exempt)
# Usage: reconcile-issue-labels.sh [epics] [priority] [effort]   (no arguments: all three)
# Needs GH_TOKEN with Issues: write on every repository: the MMW Automation app's token.
#
# One failure never stops the rest: each repository and each reconcile is isolated, every
# failure is recorded, and the script exits 1 at the end if any happened.
set -uo pipefail

OWNER=mark-my-work
EPIC_LABEL=Epic
PRIORITY_FIELD=Priority
EFFORT_FIELD='Human Effort'
LIMIT=1000   # open issues read per repository by the Epic reconcile
export EPIC_LABEL

failures=()
record_failure() { failures+=("$1"); echo "::error::$1"; }

list_repos() {
  gh repo list "$OWNER" --visibility private --no-archived --limit 1000 \
    --json nameWithOwner,hasIssuesEnabled \
    --jq '.[] | select(.hasIssuesEnabled) | .nameWithOwner'
}

# Creates the label if the repository lacks it; never changes an existing one.
ensure_label() {
  local repo=$1 name=$2 color=$3 description=$4 resp
  if ! resp=$(gh api "repos/$repo/labels" -f name="$name" -f color="$color" -f description="$description" 2>/dev/null); then
    jq -e 'any(.errors[]?; .code == "already_exists")' <<<"$resp" >/dev/null 2>&1 && return 0
    echo "::warning::$repo: could not ensure label '$name': ${resp:0:300}"
    return 1
  fi
}

# edit_label <repo> <number> add|remove <label>. A removal that fails because someone
# removed the label in the meantime is the wanted end state, not a failure.
edit_label() {
  local repo=$1 number=$2 action=$3 label=$4 present
  if gh issue edit "$number" --repo "$repo" "--$action-label" "$label" >/dev/null; then
    echo "$repo#$number: ${action} $label"
    return 0
  fi
  if [ "$action" = remove ]; then
    present=$(gh issue view "$number" --repo "$repo" --json labels \
      --jq "any(.labels[].name; . == \"$label\")" 2>/dev/null || true)
    [ "$present" = true ] || return 0
  fi
  echo "::warning::$repo#$number: failed to $action $label"
  return 1
}

reconcile_epics() {
  local repo=$1 tsv scanned failed=0 number total has_epic
  if ! tsv=$(gh issue list --repo "$repo" --state open --limit "$((LIMIT + 1))" \
      --json number,labels,subIssuesSummary \
      --jq '.[] | [.number, (.subIssuesSummary.total // 0), ([.labels[].name] | index(env.EPIC_LABEL) != null)] | @tsv'); then
    echo "::warning::$repo: could not list open issues"
    return 1
  fi
  scanned=$(grep -c . <<<"$tsv" || true)
  if [ "$scanned" -gt "$LIMIT" ]; then
    echo "::warning::$repo: more than $LIMIT open issues; those past $LIMIT were not reconciled. Raise LIMIT."
  fi
  while IFS=$'\t' read -r number total has_epic; do
    [ -n "$number" ] || continue
    if [ "$total" -gt 0 ] && [ "$has_epic" != true ]; then
      edit_label "$repo" "$number" add "$EPIC_LABEL" || failed=1
    elif [ "$total" -eq 0 ] && [ "$has_epic" = true ]; then
      edit_label "$repo" "$number" remove "$EPIC_LABEL" || failed=1
    fi
  done < <(head -n "$LIMIT" <<<"$tsv")
  return "$failed"
}

# Prints one TSV row per open issue: <number> <is epic> <has the field> <has the flag>.
read_field_state() {
  local repo=$1 field=$2 flag=$3 raw truncated
  # shellcheck disable=SC2016  # $owner, $repo and $endCursor are GraphQL variables
  if ! raw=$(gh api graphql --paginate -f owner="${repo%/*}" -f repo="${repo#*/}" -f query='
      query($owner: String!, $repo: String!, $endCursor: String) {
        repository(owner: $owner, name: $repo) {
          issues(first: 100, states: OPEN, after: $endCursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              number
              labels(first: 100) { totalCount nodes { name } }
              issueFieldValues(first: 100) {
                totalCount
                nodes { ... on IssueFieldSingleSelectValue { field { ... on IssueFieldSingleSelect { name } } } }
              }
            }
          }
        }
      }'); then
    echo "::warning::$repo: could not read open issues and their '$field' values" >&2
    return 1
  fi
  truncated=$(jq -r '.data.repository.issues.nodes[]
    | select(.labels.totalCount > 100 or .issueFieldValues.totalCount > 100) | .number' <<<"$raw" | paste -sd, -)
  [ -z "$truncated" ] || echo "::warning::$repo: issue(s) #$truncated have over 100 labels or field values; their $flag state may be misread." >&2
  FIELD=$field FLAG=$flag jq -r '.data.repository.issues.nodes[]
    | [ .number,
        ([.labels.nodes[].name] | index(env.EPIC_LABEL) != null),
        ([.issueFieldValues.nodes[] | select(.field.name == env.FIELD)] | length > 0),
        ([.labels.nodes[].name] | index(env.FLAG) != null) ] | @tsv' <<<"$raw"
}

apply_flag() {
  local repo=$1 flag=$2 tsv=$3 failed=0 number is_epic has_field has_flag
  while IFS=$'\t' read -r number is_epic has_field has_flag; do
    [ -n "$number" ] || continue
    if [ "$is_epic" != true ] && [ "$has_field" != true ]; then
      [ "$has_flag" = true ] || edit_label "$repo" "$number" add "$flag" || failed=1
    elif [ "$has_flag" = true ]; then
      edit_label "$repo" "$number" remove "$flag" || failed=1
    fi
  done <<<"$tsv"
  return "$failed"
}

field_defined() {
  local repo=$1 field=$2 fields
  # shellcheck disable=SC2016  # GraphQL variables
  fields=$(gh api graphql -f owner="${repo%/*}" -f repo="${repo#*/}" -f query='
      query($owner: String!, $repo: String!) {
        repository(owner: $owner, name: $repo) { issueFields(first: 100) { nodes { ... on IssueFieldSingleSelect { name } } } }
      }') || return 1
  jq -e --arg f "$field" 'any(.data.repository.issueFields.nodes[]?; .name == $f)' <<<"$fields" >/dev/null
}

main() {
  local want=("$@") repos repo tsv scanned=0 priced=0
  [ "${#want[@]}" -gt 0 ] || want=(epics priority effort)
  local wants=" ${want[*]} "

  if ! repos=$(list_repos) || [ -z "$repos" ]; then
    echo "::error::could not list $OWNER's repositories, or found none."
    exit 1
  fi
  echo "Repositories: $(paste -sd' ' <<<"$repos")"

  if [[ $wants == *" epics "* ]]; then
    while read -r repo; do
      ensure_label "$repo" "$EPIC_LABEL" 00ff00 "Has sub-issues (auto-managed by reconcile-issue-labels in mark-my-work/.github)" \
        || record_failure "$repo: Epic label"
      reconcile_epics "$repo" || record_failure "$repo: Epic reconcile"
    done <<<"$repos"
  fi

  if [[ $wants == *" priority "* ]]; then
    # Read every repository first: the check that the Priority field is readable counts
    # across the organization, so a new repository whose few issues have no Priority yet
    # is flagged rather than stopping the run.
    declare -A states=()
    while read -r repo; do
      ensure_label "$repo" needs-priority D93F0B "Open issue has no Priority set (auto-managed by reconcile-issue-labels in mark-my-work/.github)" \
        || record_failure "$repo: needs-priority label"
      if tsv=$(read_field_state "$repo" "$PRIORITY_FIELD" needs-priority); then
        states[$repo]=$tsv
        scanned=$((scanned + $(grep -c . <<<"$tsv" || true)))
        priced=$((priced + $(awk -F'\t' '$3 == "true"' <<<"$tsv" | grep -c . || true)))
      else
        record_failure "$repo: Priority read"
      fi
    done <<<"$repos"
    if [ "$scanned" -gt 0 ] && [ "$priced" -eq 0 ]; then
      record_failure "read $scanned open issues across the organization and none has a '$PRIORITY_FIELD' value; the field is almost certainly unreadable (renamed, or the token cannot see it). No needs-priority label was changed."
    else
      for repo in "${!states[@]}"; do
        apply_flag "$repo" needs-priority "${states[$repo]}" || record_failure "$repo: needs-priority reconcile"
      done
    fi
  fi

  if [[ $wants == *" effort "* ]]; then
    while read -r repo; do
      ensure_label "$repo" needs-effort FBCA04 "Open issue has no Human Effort set (auto-managed by reconcile-issue-labels in mark-my-work/.github)" \
        || record_failure "$repo: needs-effort label"
      if ! field_defined "$repo" "$EFFORT_FIELD"; then
        record_failure "$repo: no issue field named '$EFFORT_FIELD' is visible; needs-effort left unchanged there."
        continue
      fi
      if tsv=$(read_field_state "$repo" "$EFFORT_FIELD" needs-effort); then
        apply_flag "$repo" needs-effort "$tsv" || record_failure "$repo: needs-effort reconcile"
      else
        record_failure "$repo: Human Effort read"
      fi
    done <<<"$repos"
  fi

  if [ "${#failures[@]}" -gt 0 ]; then
    echo "::error::${#failures[@]} reconcile failure(s): $(printf '%s; ' "${failures[@]}")"
    exit 1
  fi
  echo "All reconciles succeeded."
}

main "$@"
