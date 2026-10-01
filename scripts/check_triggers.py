#!/usr/bin/env python3
"""Fail when a workflow in mark-my-work/.github has a trigger outside ALLOWED.

.github is public and its workflows can read the MMW Automation app's private key. An outsider can start a
workflow that runs with the repository's secrets through several triggers
(pull_request_target, workflow_run, issue_comment, watch, fork, ...), so this lists the
triggers that are safe rather than the ones that are not: a trigger GitHub adds later
fails until someone reviews it and adds it here.

Usage: check_triggers.py <workflows-dir>
"""
import sys
from pathlib import Path

import yaml

# pull_request gives an outsider's run no secrets; only members can push, dispatch or edit a
# schedule; a workflow_call workflow runs in the repository that calls it.
ALLOWED = {"workflow_call", "schedule", "workflow_dispatch", "push", "pull_request", "issue_comment"}


def triggers(workflow: dict) -> set[str]:
    # YAML 1.1 reads a bare `on:` key as the boolean True.
    on = workflow.get("on", workflow.get(True))
    if on is None:
        return set()
    if isinstance(on, str):
        return {on}
    if isinstance(on, list):
        return set(on)
    return set(on.keys())


def main(directory: str) -> int:
    files = sorted(p for p in Path(directory).iterdir() if p.suffix in {".yml", ".yaml"})
    failed = False
    for path in files:
        try:
            workflow = yaml.safe_load(path.read_text()) or {}
        except yaml.YAMLError as exc:
            print(f"::error file={path}::cannot parse: {exc}")
            failed = True
            continue
        found = triggers(workflow)
        if not found:
            print(f"::error file={path}::no `on:` trigger found")
            failed = True
        for trigger in sorted(found - ALLOWED):
            print(f"::error file={path}::trigger `{trigger}` is not allowed in mark-my-work/.github, "
                  f"whose workflows can read the MMW Automation app's key; allowed: {', '.join(sorted(ALLOWED))}")
            failed = True
    if not failed:
        print(f"{len(files)} workflow(s) use only allowed triggers.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
