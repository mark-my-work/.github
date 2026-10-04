# mark-my-work/.github

The GitHub setup every `mark-my-work` repository shares. The design of record is [`docs/plans/876-standard-github-repo-setup.md`](https://github.com/mark-my-work/mmw/blob/main/docs/plans/876-standard-github-repo-setup.md) in `mark-my-work/mmw`, and the teams and access are designed in [`docs/plans/926-github-access-through-teams.md`](https://github.com/mark-my-work/mmw/blob/main/docs/plans/926-github-access-through-teams.md). Creating a repository is covered by `docs/guides/Creating an MMW GitHub Repository.md` there, and teams and access by `docs/guides/Managing MMW GitHub Teams and Access.md`.

| Path | What it is |
|---|---|
| `.github/ISSUE_TEMPLATE/` | the issue templates GitHub offers in every repository without its own |
| `.github/workflows/mmw-board-*.yml` | the MMW board workflows every repository calls at `@main` from its own caller files |
| `.github/workflows/assign-branch-issue.yml` | assigns an issue to whoever pushes a branch named for it; every repository calls it at `@main` |
| `.github/workflows/reconcile-issue-labels.yml` | the label reconcile, run here for every repository |
| `.github/workflows/verify-authors.yml` | the authorship check the `default-branch` ruleset requires on every pull request |
| `.github/workflows/check-triggers.yml`, `.github/workflows/test.yml` | the checks the `github-repo-checks` ruleset requires on this repository's pull requests |
| `rulesets/`, `bin/apply-rulesets` | the organization rulesets, applied with `bin/apply-rulesets` |
| `bin/create-repo` | creates a repository with the standard setup and gives an existing team write access; it never creates a team |
| `bin/check-access` | reports where the organization's teams, roles and settings break the access rules, apart from who was given the MMW project directly, which GitHub's API does not show; run by an owner, it changes nothing |
| `scripts/`, `tests/` | the scripts the workflows run, and their tests (`tests/run.sh`) |

A change to a shared workflow reaches every repository the moment it merges. Test it first from a scratch repository whose caller file points at the change's branch.

Every workflow here may use only the triggers `scripts/check_triggers.py` allows, because this repository is public and its workflows can read the MMW Automation app's private key.

Issues are turned off here and in `mark-my-work/.github-template`. File an issue about either repository in [`mark-my-work/mmw`](https://github.com/mark-my-work/mmw/issues), where the MMW board tracks it, and start the pull request's description with `Closes mark-my-work/mmw#<n>`, which closes the issue when the pull request merges. For work split over several pull requests, start all but the last with `Part of mark-my-work/mmw#<n>`. The board workflows move only an issue in the pull request's own repository, so move the issue to In progress and In review by hand.
