#!/usr/bin/env bash
# Keeps three labels correct on every open issue in every private repository of mark-my-work:
#   Epic           <=> the issue has at least one sub-issue
#   needs-priority <=> the issue has no Priority        (epics exempt)
#   needs-effort   <=> the issue has no Human Effort    (epics exempt)
# Usage: reconcile-issue-labels.sh [epics] [priority] [effort]   (no arguments: all three)
# Needs GH_TOKEN with Issues: write on every repository: the MMW Automation app's token.
#
# One failure never stops the rest: each repository and each reconcile is isolated, every
# failed read or write is recorded, and the script exits 1 at the end if any happened. A
# read that may be incomplete (over LIMIT open issues, fewer issues read than exist, or an
# issue with over 100 labels or field values) is warned and not recorded.
# Label names are compared without regard to case, as GitHub compares them.
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

# The repository's label names, lower-cased and newline-delimited, read once per repository.
declare -A LABELS=()
read_labels() {
  local repo=$1 names
  [ -z "${LABELS[$repo]+set}" ] || return 0
  names=$(gh api "repos/$repo/labels" --paginate --jq '.[].name | ascii_downcase') || return 1
  LABELS[$repo]=$'\n'"$names"$'\n'
}

# Creates the label if the repository lacks it; never changes an existing one.
ensure_label() {
  local repo=$1 name=$2 color=$3 description=$4 resp err
  if read_labels "$repo" && [[ ${LABELS[$repo]} == *$'\n'"${name,,}"$'\n'* ]]; then
    return 0
  fi
  err=$(mktemp)
  if ! resp=$(gh api "repos/$repo/labels" -f name="$name" -f color="$color" -f description="$description" 2>"$err"); then
    if jq -e 'any(.errors[]?; .code == "already_exists")' <<<"$resp" >/dev/null 2>&1; then
      rm -f "$err"
      return 0
    fi
    echo "::warning::$repo: could not ensure label '$name': ${resp:0:300} $(head -c 300 "$err")"
    rm -f "$err"
    return 1
  fi
  rm -f "$err"
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
    present=$(LABEL=$label gh issue view "$number" --repo "$repo" --json labels \
      --jq 'any(.labels[].name; ascii_downcase == (env.LABEL | ascii_downcase))' 2>/dev/null || true)
    if [ "$present" != true ]; then
      echo "$repo#$number: $label no longer present (concurrent removal, or state unreadable) -- treating removal as done."
      return 0
    fi
  fi
  echo "::warning::$repo#$number: failed to $action $label"
  return 1
}

reconcile_epics() {
  local repo=$1 tsv scanned failed=0 number total has_epic
  if ! tsv=$(gh issue list --repo "$repo" --state open --limit "$((LIMIT + 1))" \
      --json number,labels,subIssuesSummary \
      --jq '.[] | [.number, (.subIssuesSummary.total // 0), ([.labels[].name | ascii_downcase] | index(env.EPIC_LABEL | ascii_downcase) != null)] | @tsv'); then
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

# Reads every open issue's labels and field values, once per repository, into ISSUES.
# Call it directly, never in $(...), or the cache is lost with the subshell.
declare -A ISSUES=()
read_issue_state() {
  local repo=$1 raw total read truncated
  [ -z "${ISSUES[$repo]+set}" ] || return 0
  # shellcheck disable=SC2016  # $owner, $repo and $endCursor are GraphQL variables
  if ! raw=$(gh api graphql --paginate -f owner="${repo%/*}" -f repo="${repo#*/}" -f query='
      query($owner: String!, $repo: String!, $endCursor: String) {
        repository(owner: $owner, name: $repo) {
          issues(first: 100, states: OPEN, after: $endCursor) {
            totalCount
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
    echo "::warning::$repo: could not read open issues and their field values"
    return 1
  fi
  total=$(jq -s '.[0].data.repository.issues.totalCount // 0' <<<"$raw")
  read=$(jq -s '[.[].data.repository.issues.nodes[]] | length' <<<"$raw")
  [ "$read" -ge "$total" ] || echo "::warning::$repo: read $read of $total open issues; the rest were not reconciled this run."
  truncated=$(jq -r '.data.repository.issues.nodes[]
    | select(.labels.totalCount > 100 or .issueFieldValues.totalCount > 100) | .number' <<<"$raw" | paste -sd, -)
  [ -z "$truncated" ] || echo "::warning::$repo: issue(s) #$truncated have over 100 labels or field values; their labels may be misread."
  ISSUES[$repo]=$raw
}

# Prints one TSV row per open issue in ISSUES[repo]: <number> <is epic> <has the field> <has the flag>.
field_rows() {
  local repo=$1 field=$2 flag=$3
  FIELD=$field FLAG=$flag jq -r '.data.repository.issues.nodes[]
    | ([.labels.nodes[].name | ascii_downcase]) as $labels
    | [ .number,
        ($labels | index(env.EPIC_LABEL | ascii_downcase) != null),
        ([.issueFieldValues.nodes[] | select(.field.name == env.FIELD)] | length > 0),
        ($labels | index(env.FLAG | ascii_downcase) != null) ] | @tsv' <<<"${ISSUES[$repo]}"
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

# Returns 0 when the repository can see the field, 1 when it cannot, 2 when the read failed.
field_defined() {
  local repo=$1 field=$2 fields
  # shellcheck disable=SC2016  # GraphQL variables
  fields=$(gh api graphql -f owner="${repo%/*}" -f repo="${repo#*/}" -f query='
      query($owner: String!, $repo: String!) {
        repository(owner: $owner, name: $repo) { issueFields(first: 100) { nodes { ... on IssueFieldSingleSelect { name } } } }
      }') || return 2
  jq -e --arg f "$field" 'any(.data.repository.issueFields.nodes[]?; .name == $f)' <<<"$fields" >/dev/null || return 1
}

main() {
  local arg want=() repos repo tsv scanned=0 priced=0 read_ok=() rc
  for arg in "$@"; do
    case $arg in
      epics|priority|effort) want+=("$arg") ;;
      *) echo "usage: reconcile-issue-labels.sh [epics] [priority] [effort] -- unknown argument '$arg'" >&2; exit 2 ;;
    esac
  done
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
    while read -r repo; do
      ensure_label "$repo" needs-priority D93F0B "Open issue has no Priority set (auto-managed by reconcile-issue-labels in mark-my-work/.github)" \
        || record_failure "$repo: needs-priority label"
      if read_issue_state "$repo"; then
        read_ok+=("$repo")
        tsv=$(field_rows "$repo" "$PRIORITY_FIELD" needs-priority)
        scanned=$((scanned + $(grep -c . <<<"$tsv" || true)))
        priced=$((priced + $(awk -F'\t' '$3 == "true"' <<<"$tsv" | grep -c . || true)))
      else
        record_failure "$repo: Priority read"
      fi
    done <<<"$repos"
    if [ "$scanned" -gt 0 ] && [ "$priced" -eq 0 ]; then
      record_failure "read $scanned open issues across the organization and none has a '$PRIORITY_FIELD' value; the field is almost certainly unreadable (renamed, or the token cannot see it). No needs-priority label was changed."
    else
      for repo in "${read_ok[@]}"; do
        apply_flag "$repo" needs-priority "$(field_rows "$repo" "$PRIORITY_FIELD" needs-priority)" \
          || record_failure "$repo: needs-priority reconcile"
      done
    fi
  fi

  if [[ $wants == *" effort "* ]]; then
    while read -r repo; do
      ensure_label "$repo" needs-effort FBCA04 "Open issue has no Human Effort set (auto-managed by reconcile-issue-labels in mark-my-work/.github)" \
        || record_failure "$repo: needs-effort label"
      field_defined "$repo" "$EFFORT_FIELD"; rc=$?
      if [ "$rc" -eq 2 ]; then
        record_failure "$repo: could not read the issue field definitions; needs-effort left unchanged there."
        continue
      elif [ "$rc" -eq 1 ]; then
        record_failure "$repo: no issue field named '$EFFORT_FIELD' is visible; needs-effort left unchanged there."
        continue
      fi
      if read_issue_state "$repo"; then
        apply_flag "$repo" needs-effort "$(field_rows "$repo" "$EFFORT_FIELD" needs-effort)" \
          || record_failure "$repo: needs-effort reconcile"
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
