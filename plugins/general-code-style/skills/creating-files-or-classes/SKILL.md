---
name: creating-files-or-classes
description: Caps source files at ~200 lines, splits oversized files into focused child classes, requires class and file names that describe their single purpose without a comment, and fixes the order members are declared in — properties, then constructors, then methods, each block ordered public before private. Use when creating a new file or class, splitting a file that has grown too large, naming either, or deciding where a property or method goes inside a type. Applies to every new file however it was created — including one written by a shell command, a generator script, or another tool rather than the file editor, and one created while carrying out an already-approved plan.
---

**Scope.** These rules apply to every file, whatever wrote it. A file created by a shell
command (a heredoc, `sed -i`, a generator script) or by another tool is held to them exactly as
one written with the file editor, and an already-approved plan that fixed the shapes in advance
does not exempt the code it produces — if the plan conflicts with a rule here, say so rather
than following it silently.

When creating any file or class, always take into account these guidelines:

1. **Keep files short**: Limit file length to ~200 lines (with a maximum of +50 lines spare). Import statements do not count toward this limit.
2. **Split when approaching the limit**: If a file is approaching the limit, subdivide it into child classes or subfiles with focused responsibilities.
3. **Keep names simple and self-describing**: A class or file name should clearly express its single purpose. If it needs a comment to explain what it does, the name is wrong — rename it rather than documenting it.
4. **Declare members in a fixed order**: Properties first, then constructors, then methods — never a property between two methods. Within each block, order by visibility: public, then internal, then protected, then private. A private backing property directly above the public one that exposes it is the intended shape, not an exception to it.
