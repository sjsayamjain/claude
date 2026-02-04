---
description: Load context files or documentation to prime Claude for focused discussion
argument-hint: [file paths or module names]
---

When invoked, do the following:

1. **Interpret `$ARGUMENTS`** as file paths or module identifiers (e.g., "docs/architecture.md", "services/auth", "lib/helpers.md").
2. **Echo what will be loaded**, for clarity:
   > “Loading context from: <list_of_files_or_modules>”
3. **Load each specified file** using `@` notation:
@<file-path>

4. **Optionally**, if `$ARGUMENTS` refers to a module (like a directory), load its `CLAUDE.md` and a summary:
Provide a brief summary (1–2 sentences) of the loaded context.

5. **Prompt** the user to confirm readiness:
> “I’ve loaded the context from these files. How would you like to proceed?”

If `$ARGUMENTS` is empty, respond:
> “Which context files or module(s) should I load? For example: `docs/architecture.md` or `backend/CLAUDE.md`.”