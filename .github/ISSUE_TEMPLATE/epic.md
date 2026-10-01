---
name: Epic
about: A feature or initiative decomposed into sub-issues (not the shippable units themselves)
title: ''
---

<!-- TITLE: name the thing being built, as a noun phrase, and nothing else — "Test Master Generation
     Engine", "Public marketing site at markmywork.ca". No actor, no verb, no property. An epic outlives
     the details of who uses it and how it behaves, and a title carrying either goes stale while still
     reading correctly. No issue-number prefix. -->

<!-- Set the issue TYPE (not a label): **Feature** if the initiative delivers user-facing capability,
     **Task** if it is entirely technical. (There is no `enhancement` label in this repo.) -->

<!-- LEAVE Priority, Human Effort, Implementation Risk and Milestone BLANK. Those rank shippable work, and
     an epic's is ranked on its sub-issues. The `Epic` LABEL is applied by reconcile-issue-labels.yml once
     this has at least one sub-issue; do not add it by hand. Until then that same workflow will flag this
     issue with needs-priority and needs-effort, which is expected and clears when it is decomposed. -->

<!-- AN EPIC IS NOT A BIG IMPLEMENTATION ISSUE. It carries no Requirements, no Acceptance checklist and no
     Implementation Notes — those belong to the sub-issues, which is where the work is agreed and verified.
     What an epic owes its reader is the SHAPE: what this is, where its edges are, the decisions every
     sub-issue inherits, and how it breaks down. If a paragraph would still be true of one sub-issue alone,
     it belongs in that sub-issue. -->

<!-- DEPENDENCIES BELONG ON THE SUB-ISSUES, never on the epic. "Blocked by" on an epic is almost always
     wrong: the epic is not a unit of work, and blocking it says nothing about which part is actually
     stuck. Link the specific sub-issue that is blocked, and create the real GitHub relationship - the
     prose line below creates nothing. -->

Design: <link to the design document> · Sibling epic: #<n> · Parent epic: #<n>

## Overview

Two or three paragraphs. What this initiative is, in the words of someone who will use it, and why it
exists. A reader who opens none of the links must finish this section knowing what is being built.

## Why this is its own epic

Where the edges are, and what sits just outside them. Name the sibling that owns the neighbouring work, and
the seam between them — the row, the contract, the interface at which one hands off to the other. This is
the section that stops two epics growing into each other, and it is worth more than any amount of detail.

## Architecture principles

The decisions every sub-issue inherits and none may quietly reverse. One bullet each: the choice, and the
reason it was made, in a sentence.

State a principle, not an implementation. *"Each ingestion mechanism is a pluggable producer of `Response`
rows, so adding one never touches the marking engine"* constrains ten future issues. *"Use `create-subnet`
with a `/20`"* constrains nothing and belongs in a sub-issue or a runbook.

- **<Principle>.** <Why.>

## Out of scope

What a reader would reasonably expect here and will not find, each with the issue that owns it. An item
nobody owns yet says so plainly rather than being left unmentioned.

- **<Thing>** — #<n>.

## Sub-issues

How this decomposes, in dependency order, grouped when the groups mean something. This is what makes the
document an epic rather than an essay, so write it even when the issues do not exist yet — a named piece
with no number is more useful than an unnamed one.

Tick a box only when its issue is merged, so the list doubles as progress.

**<Group — e.g. Foundation, or the first shippable slice>**
- [ ] #<n> — <what it delivers>
- [ ] <what it delivers> *(issue to be created)*

**Future (no issue yet)**
- <Thing this epic will eventually need, named so it is not forgotten.>
