---
name: Implementation Issue
about: A single shippable unit of work under an epic (not the epic itself; not a data-modeling issue)
title: ''
---

<!-- Set the issue TYPE (not a label): **Feature** if this delivers a user-facing / UI change, or **Task**
     for a technical to-do with no UI component. (There is no `enhancement` label in mark-my-work repositories.) -->

<!-- AUTHORITY OF THE SECTIONS (issue mark-my-work/mmw#418): **Requirements** (+ the cited requirement documents)
     are BINDING — the agreed WHAT. **Implementation Notes** are ADVISORY — suggested HOW, which the plan
     may adopt, improve, or reject as a normal design choice. **Acceptance** restates the Requirements
     (outcomes) ONLY — never a mechanism that lives only in Implementation Notes. Keep the WHAT and the HOW
     from blurring: a suggested table/role/endpoint is a hint, not a requirement, unless it's the agreed
     behavior itself. -->

<!-- THE LINE BELOW IS PROSE — IT CREATES NOTHING. Writing "Part of mark-my-work/mmw#91" does not make this a sub-issue of
     mark-my-work/mmw#91, and "Depends on: mark-my-work/mmw#537" does not block anything; they are text a reader sees. Once the issue is
     open, set the real relationships in its sidebar — a sub-issue link to the epic, and a blocked-by entry
     per dependency. Only those drive the epic's sub-issue checklist, the `Epic` label automation, and the
     blocked/blocking indicators a groomer reads. Check each blocker is still OPEN and genuinely delivers
     what you are waiting on; a closed one marks this issue unblocked when it is not.

     Keep the prose line as well — it is what makes the issue readable on its own. -->

Part of #<epic> · Depends on: #<a>, #<b> · Design: <link to the design document>

## Overview

<!-- ≤2 sentences: what this builds and why / context. -->

## Requirements

<!-- What exactly is built: behavior, business rules, constraints, data shapes, error handling.
     Include where they apply:
       - observability: the OTEL span/attributes + Sentry on failure, with NO PII/content in telemetry
       - i18n: frontend user-facing strings via en.json (N/A for backend-only issues)
       - e2e: Playwright end-to-end tests for a new page
       - cross-page linking: a list row naming an entity with its own list page links there -->

<!-- Out of scope: ... (optional — bound the work) -->

## Implementation Notes

Advisory; the plan may adopt, improve, or reject any of it.

<!-- Optional, ADVISORY (not requirements): suggested technical direction — files to reuse, patterns,
     gotchas, a candidate data shape / endpoint. Phrase as options serving a Requirement ("a natural fit
     is X — but the requirement is only Y"), not as imperatives. The plan may improve on or reject these.
     Delete this section if unused. -->

## Acceptance

<!-- Checklist summarizing the REQUIREMENTS (outcomes), the acceptance criteria. Each item is a business
     OUTCOME a reviewer can verify — never a mechanism that appears only in Implementation Notes (issue
     mark-my-work/mmw#418). Write "one current PDF per kind, regenerated on change", NOT "linked via the <x> output role":
     check WHAT must be true, not HOW it was built. -->
- [ ] 
- [ ] Tests + lint pass
