import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "check_triggers.py"


def run(files: dict[str, str]) -> subprocess.CompletedProcess:
    with tempfile.TemporaryDirectory() as d:
        for name, text in files.items():
            Path(d, name).write_text(text)
        return subprocess.run([sys.executable, SCRIPT, d], capture_output=True, text=True)


class CheckTriggersTests(unittest.TestCase):
    def test_allowed_triggers_pass(self):
        result = run({
            "a.yml": "on: workflow_call\njobs: {}\n",
            "b.yml": "on:\n  schedule:\n    - cron: '0 */6 * * *'\n  workflow_dispatch:\njobs: {}\n",
            "c.yaml": "on: [push, pull_request]\njobs: {}\n",
        })
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_each_outsider_trigger_fails(self):
        for trigger in ["pull_request_target", "workflow_run", "issue_comment",
                        "pull_request_review_comment", "watch", "fork", "issues"]:
            with self.subTest(trigger=trigger):
                result = run({"x.yml": f"on:\n  {trigger}:\njobs: {{}}\n"})
                self.assertEqual(result.returncode, 1)
                self.assertIn(f"trigger `{trigger}` is not allowed", result.stdout)

    def test_one_bad_trigger_among_good_ones_fails(self):
        result = run({"x.yml": "on: [pull_request, issue_comment]\njobs: {}\n"})
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("`pull_request`", result.stdout)

    def test_missing_on_fails(self):
        result = run({"x.yml": "jobs: {}\n"})
        self.assertEqual(result.returncode, 1)
        self.assertIn("no `on:` trigger found", result.stdout)

    def test_unparseable_file_fails(self):
        result = run({"x.yml": "on: [unclosed\n"})
        self.assertEqual(result.returncode, 1)
        self.assertIn("cannot parse", result.stdout)

    def test_non_workflow_files_are_ignored(self):
        result = run({"README.md": "on: issue_comment\n"})
        self.assertEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main()
