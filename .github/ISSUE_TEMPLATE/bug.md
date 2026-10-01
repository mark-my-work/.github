---
name: Bug
about: A defect or gap in behavior — described business-first, with technical detail in Implementation Notes
title: ''
---

<!-- Set the issue TYPE to **Bug** in the issue UI (a Type chosen in the sidebar, NOT a label — there is no
     `bug` label in mark-my-work repositories). Write the report BUSINESS-FIRST: what the user experiences and why it
     matters. Keep code, file:line refs, stack traces, and fix mechanics OUT of the top sections — group
     them under Implementation Notes. The title names the user-facing problem, with no number prefix. -->

<!-- AUTHORITY OF THE SECTIONS (issue mark-my-work/mmw#418): the **Expected** behavior is the BINDING requirement — the
     agreed WHAT. **Implementation Notes** (Evidence / Root cause / Suggested direction) are ADVISORY —
     the plan may adopt, improve, or reject the suggested direction. **Acceptance** restates the Expected
     OUTCOME, never a mechanism (a specific table/root-cause fix) that lives only in Implementation Notes. -->

<!-- Optional first line: provenance — where this surfaced, e.g. "Surfaced while testing mark-my-work/mmw#265." -->

## Overview

<!-- ≤2 sentences, plain language: what's wrong from the user's point of view and why it's a problem. No code. -->

## What happens today

### Steps to reproduce

<!-- The business steps to hit the bug — what the user does, as a user (not API calls / internals). -->
1.
2.
3.

### Expected

<!-- What the user SHOULD experience instead. -->

### Actual

<!-- What the user experiences today, and the gap it leaves them in. -->

## Why it matters

<!-- The user / business cost — transparency, trust, wasted effort or spend, safety, or real problems hidden
     as noise. Tie to a principle where one applies (e.g. "UX is load-bearing"). -->

-

## Implementation Notes

Evidence and root cause are findings; the suggested direction is advisory.

<!-- ALL the technical detail lives here. Respect the repo conventions: backend emits codes, the frontend
     owns prose (codes-not-prose); NO PII / model content in the UI or telemetry. Delete a subsection if unused. -->

**Evidence.** <!-- Concrete occurrence: ids, the logged error / stack trace, the exact message the user saw. -->

**Root cause.** <!-- Where and why, with file:line refs. -->

**Suggested direction.** <!-- Optional: the seam to change; note any cross-stack contract to extend (e.g. a `*ContractTests`). -->

## Out of scope

<!-- Optional: related problems this issue deliberately does NOT fix — link the owning / follow-up issue. Delete if unused. -->

## Acceptance

<!-- Outcome-based checklist, business-facing where possible; pin any i18n / cross-stack contract, and that
     no PII / content leaks to the UI or telemetry where relevant. -->
- [ ] The user experiences the Expected behavior above (a regression test pins it)
- [ ] Tests + lint pass
