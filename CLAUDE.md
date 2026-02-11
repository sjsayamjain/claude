# User Preferences

## Communication
- Be direct and concise. Skip preamble.
- When unsure, investigate first rather than guessing.
- Show file paths with line numbers when referencing code.
- Use plan mode (Shift+Tab) for tasks touching 3+ files.

## Code Style
- Prefer functional patterns over class-based when practical.
- Use early returns to reduce nesting.
- Name variables descriptively; avoid abbreviations except common ones (e.g., idx, ctx, req, res).
- Keep functions under 50 lines. Extract when logic is reusable.
- No dead code, commented-out code, or TODO comments in final output.

## Git
- Commit messages: imperative mood, explain WHY not WHAT.
- Never force push to main/master.
- Always confirm before pushing to remote.

## Testing
- Write tests for non-trivial logic.
- Prefer integration tests over unit tests for API endpoints.
- Test edge cases and error paths, not just happy paths.

## Security
- Never hardcode secrets, API keys, or credentials.
- Validate all external input at system boundaries.
- Use parameterized queries for database operations.

## Context Management
- Use /compact aggressively when context grows large.
- Prefer subagents for research-heavy tasks to preserve main context.
- Start fresh sessions for unrelated tasks.
