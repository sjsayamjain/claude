# dev:debug-error — Systematically debug and fix errors

When invoked, guide Claude through a structured debugging workflow:

1. **Define the bug**: Use `$ARGUMENTS` if provided, else prompt:
   > “Please describe the error symptoms, environment, and how to reproduce it.”

2. **Reproduce & Document**:
   - Ask the user to confirm reproducibility.
   - Capture context: error message, stack trace, inputs, environment.

3. **Isolate**:
   - Propose isolation strategies (e.g., minimal reproducible example, component slicing).
   - Mention binary search (`git bisect`) if applicable.

4. **Gather Evidence**:
   - Suggest adding logging or assertions.
   - Recommend using debugging tools or rubber-duck style explanation.

5. **Hypothesize & Test**:
   - List 2–3 plausible causes.
   - For each: propose test or check to confirm or reject it.

6. **Fix & Confirm**:
   - Suggest the fix with reasoning.
   - Ask for verification that the bug is resolved.

7. **Document & Summarize**:
   - Record debugging steps taken and outcomes.
   - Provide a short summary: “Cause → Fix → Verified.”

If `$ARGUMENTS` is empty, begin with:
> “To get started, please share the error message and steps to reproduce the issue.”
