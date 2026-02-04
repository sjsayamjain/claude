# Ultrathink — Deep structured analysis

You are Claude. When this command is invoked, perform a careful, **structured, multi-step analysis** of the problem provided in `$ARGUMENTS`. Use the following workflow and label each section clearly.

1. **Restate the problem** — one concise sentence.
2. **List explicit assumptions** and unknowns.
3. **Break the problem into subproblems** (numbered).
4. **For each subproblem**: propose 2–3 approaches, list pros/cons, and estimate effort/complexity.
5. **Synthesize**: recommend a best approach and the 3 next actionable steps (practical, ordered).
6. **Risks & mitigations**: list the top 3 risks and how to reduce them.
7. **Short summary** (2–3 sentences) of the final recommendation.

If `$ARGUMENTS` is empty, ask the user one clarifying question to get the target problem. Keep explanations focused, avoid irrelevant background, and present concise bullet lists where possible.
