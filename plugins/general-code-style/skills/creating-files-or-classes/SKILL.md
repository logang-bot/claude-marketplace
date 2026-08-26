---
name: creating-files-or-classes
description: Caps source files at ~200 lines, splits oversized files into focused child classes, and requires class and file names that describe their single purpose without a comment. Use when creating a new file or class, splitting a file that has grown too large, or naming either.
---

When creating any file or class, always take into account these guidelines:

1. **Keep files short**: Limit file length to ~200 lines (with a maximum of +50 lines spare). Import statements do not count toward this limit.
2. **Split when approaching the limit**: If a file is approaching the limit, subdivide it into child classes or subfiles with focused responsibilities.
3. **Keep names simple and self-describing**: A class or file name should clearly express its single purpose. If it needs a comment to explain what it does, the name is wrong — rename it rather than documenting it.
