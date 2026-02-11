# dev:refactor-code — Intelligent code refactoring based on best practices

When this command is invoked, do the following:

1. **Receive input** via `$ARGUMENTS`, which should specify:
   - Target file path (e.g., `src/app.js`)
   - Refactoring criteria (e.g., `extract method`, `simplify logic`, `remove duplication`)

2. **Explain your approach**:
   - Summarize in one sentence the goal of the refactoring (e.g., “Extract repeated logic into reusable function”).
   - List assumptions.

3. **Propose 2–3 micro-refactorings**, with pros and cons for each, and an estimate of complexity or effort (e.g., low, medium).

4. **Select the best approach** and describe the steps clearly:
   - Step 1: Locate occurrence(s)
   - Step 2: Extract method or rename variable
   - Step 3: Replace duplicates
   - Step 4: Update tests or add new ones

5. **Output actual code changes** (diff-style, in markdown code fences).

6. **Wrap up** with:
   - **Risks & mitigations** (e.g., “ensure tests exist; run tests after each change”)
   - **Short summary** (2–3 sentences describing the result and next actions)

If `$ARGUMENTS` is missing:
> “Please provide the file path and desired refactoring goal (e.g., `src/utils.js extract duplication`).”
