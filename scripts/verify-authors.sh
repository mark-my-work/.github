#!/usr/bin/env bash
# Checks the author of every commit a pull request adds: a @markmywork.ca address and a name
# of at least two words, unless the author is a bot on BOT_AUTHORS.
# Usage: verify-authors.sh <base-branch> <head-sha>, run inside a full-history checkout.
# Commits already on origin/<base-branch> are accepted history and are not re-checked.
set -euo pipefail

CORP_DOMAIN=markmywork.ca
# Bot authors accepted as they are, matched on the exact author email (case-insensitive).
BOT_AUTHORS=(
  "58178390+tinacloud-app[bot]@users.noreply.github.com"   # TinaCloud, the website's CMS (#690)
)

base=${1:?usage: verify-authors.sh <base-branch> <head-sha>}
head=${2:?usage: verify-authors.sh <base-branch> <head-sha>}

if ! commits=$(git rev-list "$head" --not "origin/$base"); then
  echo "::error::Could not list the commits $head adds to origin/$base (is fetch-depth: 0 set?)."
  exit 1
fi
if [ -z "$commits" ]; then
  echo "No new commits to verify."
  exit 0
fi

is_bot() {
  local email_lc=$1 bot
  for bot in "${BOT_AUTHORS[@]}"; do
    [ "$email_lc" = "$(printf '%s' "$bot" | tr '[:upper:]' '[:lower:]')" ] && return 0
  done
  return 1
}

fail=0
while IFS= read -r sha; do
  email=$(git show -s --format='%ae' "$sha")
  name=$(git show -s --format='%an' "$sha")
  short=$(git show -s --format='%h' "$sha")
  email_lc=$(printf '%s' "$email" | tr '[:upper:]' '[:lower:]')
  if is_bot "$email_lc"; then
    echo "Commit $short: bot author '$name' accepted."
    continue
  fi
  # Quoting $CORP_DOMAIN keeps the dot literal, so x@evil.markmywork.ca and
  # markmywork.ca@evil.com are both rejected.
  case "$email_lc" in
    *@"$CORP_DOMAIN") : ;;
    *) echo "::error::Commit $short: author email '$email' is not a @$CORP_DOMAIN address."; fail=1 ;;
  esac
  if ! grep -qE '[[:alpha:]]' <<<"$name" || [ "$(wc -w <<<"$name" | tr -d '[:space:]')" -lt 2 ]; then
    echo "::error::Commit $short: author name '$name' must be a full name like 'Dave Cherkassky', not a single-word handle."
    fail=1
  fi
done <<<"$commits"

if [ "$fail" -ne 0 ]; then
  echo "Fix your identity, then rewrite the listed commits: git config user.email you@$CORP_DOMAIN && git config user.name 'First Last'"
  exit 1
fi
echo "All new commits have a @$CORP_DOMAIN author with a full name."
