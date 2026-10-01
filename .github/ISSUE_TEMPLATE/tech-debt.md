---
name: Tech Debt
about: A low-priority DRY / cleanup / refactor item (often surfaced by code review); no behavior change
title: 'tech-debt: '
labels: tech-debt
---

<!-- One line of provenance + framing, e.g.:
     **Low-priority tech-debt / DRY** — surfaced by the `xhigh` code review of branch `<branch>` (finding #N).
     Backlog; no behavior change today. Part of #<epic>. -->

<!-- "Part of #<epic>" above is PROSE — it creates nothing. If this belongs to an epic, also add the real
     sub-issue link in the issue's sidebar once it is open; only that drives the epic's checklist and the
     `Epic` label automation. -->

## What

<!-- The duplication / smell, with concrete file:line refs and a short snippet if it helps.
     STAND ALONE: name the thing in plain words before criticising it. A reader who opens none of the links
     must understand this from the section's own words — "the exact declaration #N removed" explains nothing
     to someone who hasn't read #N. Cross-references go in Implementation Notes, not here. -->

## Why it matters

<!-- The drift / maintenance cost — what silently breaks if the two copies diverge.
     If a past failure is the evidence, RETELL it here rather than linking to it. -->

## Implementation Notes

Advisory; the doer may adopt, improve, or reject any of it.

<!-- ADVISORY (issue mark-my-work/mmw#418): the binding WHAT is the What / Why it matters above; this is suggested HOW the
     doer may improve on or reject. Lead with the **suggested fix** — the shared seam to reuse or extract;
     note shape mismatches that make reuse non-trivial. Cross-reference freely — this is the section a DOER
     reads ("#N is the reference implementation"). -->

<!-- Before filing: re-read What + Why it matters as if every link were dead. Still make sense? -->


## Scope / acceptance

<!-- Keep it light — single source of truth + "no behavior change". -->
- [ ] 
- [ ] No user-visible change; tests + lint stay green
