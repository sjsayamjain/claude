---
description: Analyze and explain the functionality of a code snippet or file
argument-hint: [filename or snippet]
allowed-tools: Bash(cat *)
---

When invoked, perform the following:

1. If $ARGUMENTS refers to an existing file (recognized via `@filename`), load its content using:

@${ARGUMENTS}


Otherwise, treat `$ARGUMENTS` directly as an inline code snippet.

2. **Explain the code**: Provide a clear, structured breakdown that covers:
- High-level purpose
- Core logic flow (step-by-step)
- Key functions, classes, or modules involved
- Any assumptions or dependencies
- Potential pitfalls or edge cases

3. **Additional context** (optional):
- Suggest possible improvements or refactors
- Note any notable patterns or antipatterns

4. **Summary**: Conclude with a 2–3 sentence plain-language overview for quick comprehension.
