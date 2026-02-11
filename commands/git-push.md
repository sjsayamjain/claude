# external:git-push — Commit & push changes via Claude

When you run this command, Claude should:

1. **Prompt for commit message**, using `$ARGUMENTS` if provided, else ask:
   > “What commit message should I use?”
2. **Stage all changes**, commit them with the message, and push to remote.
3. **Summarize** what was committed and pushed (e.g., which files were added or changed).
4. If `$ARGUMENTS` is empty, prompt the user for a commit message, otherwise use `$ARGUMENTS`.

Example usage:
- `/external:git-push “fix: resolve merge conflict in API handler”`
- `/external:git-push`

---

You could create similar commands for other tools:

- **Issue tracker** (`.claude/commands/linear-create-task.md`):
  ```markdown
  # external:linear-create-task — Create a Linear ticket from Claude

  Prompt: “Create a new task in Linear with title and description from `$ARGUMENTS`.”
  If `$ARGUMENTS` is empty, ask:
  > “Please provide the task title and description.”
