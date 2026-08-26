---
name: updating-docs
description: When a code change is complete and the project has a docs/ directory — every change ends with a documentation update, including sweeping sibling docs for claims the change made stale.
---

A change is not finished when the code works. It is finished when the documentation matches
the code again.

## After every change that alters behaviour

1. **Update the doc that covers the thing you changed.** Find it first — `docs/` is usually
   organised by feature or subsystem. If no doc covers it and the change is substantial
   enough that someone will look for one, create it in the style of its siblings.

2. **Sweep sibling docs for claims your change made stale.** This is the step that gets
   skipped, and it is the one that matters — a doc that is confidently wrong costs more than
   a doc that is missing. Grep `docs/` for the names of things you touched: the class, the
   table, the flag, the endpoint, the setting. Fix every description that no longer holds.

3. **Check the numbers.** Schema versions, dependency versions, counts, limits, and defaults
   quoted in prose go stale silently. If your change moved one, find every place it is
   written down.

## What does not need a doc update

Internal refactors that change no behaviour, no interface, and no operational procedure.
Tests. Formatting. If you cannot name what a reader would now believe that is wrong, there is
nothing to update.

## Scope

Update documentation for what you changed. Do not rewrite unrelated docs you happen to notice
are imperfect — mention them to the user instead and let them decide.
