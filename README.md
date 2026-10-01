# mark-my-work/.github

The GitHub setup every `mark-my-work` repository shares. The design of record is [`docs/plans/876-standard-github-repo-setup.md`](https://github.com/mark-my-work/mmw/blob/main/docs/plans/876-standard-github-repo-setup.md) in `mark-my-work/mmw`; creating a repository is covered by `docs/guides/Creating an MMW GitHub Repository.md` there.

| Path | What it is |
|---|---|
| `.github/ISSUE_TEMPLATE/` | the issue templates GitHub offers in every repository without its own |
| `.github/workflows/assign-branch-issue.yml`, `.github/workflows/mmw-board-*.yml` | the board workflows every repository calls at `@main` from its own caller files |
| `.github/workflows/reconcile-issue-labels.yml` | the label reconcile, run here for every repository |
| `.github/workflows/verify-authors.yml` | the authorship check the `default-branch` ruleset requires on every pull request |
| `.github/workflows/check-triggers.yml`, `.github/workflows/test.yml` | the checks the `github-repo-checks` ruleset requires on this repository's pull requests |
| `rulesets/`, `bin/apply-rulesets` | the organization rulesets, applied with `bin/apply-rulesets` |
| `bin/create-repo` | creates a repository with the standard setup |
| `scripts/`, `tests/` | the scripts the workflows run, and their tests (`tests/run.sh`) |

A change to a shared workflow reaches every repository the moment it merges. Test it first from a scratch repository whose caller file points at the change's branch.

Every workflow here may use only the triggers `scripts/check_triggers.py` allows, because this repository is public and its workflows can read the MMW Automation app's private key.
