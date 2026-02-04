# Skill Scout

A meta-skill for discovering, evaluating, and installing other Claude Code skills from the web.

## Usage
- "Scout for a skill that handles Kubernetes deployments."
- "Find and install a skill for generating unit tests from GitHub."
- "Search for new skills in the community repository and list what they do."

## Instructions
1. **Search**: Use `curl` or `gh search` (if GitHub CLI is available) to find repositories or directories containing `SKILL.md` files.
2. **Evaluate**: Read the `SKILL.md` of found skills to ensure they are safe and compatible.
3. **Download**: Use `git clone` or `curl` to pull the skill files into a temporary directory.
4. **Install**: Move the validated skill directory to the user's active skills folder (default: `~/.claude/skills/`).
5. **Reload**: Remind the user that the new skill is now available for sub-agents to use.

## Safety Guidelines
- Never install a skill without summarizing its capabilities to the user first.
- Check for malicious shell scripts within the skill's directory before moving it to the permanent skills folder.
