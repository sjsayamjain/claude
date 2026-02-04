# Contributing

How to add new agents, commands, and skills to this toolkit.

## Adding an Agent

1. Create a new `.md` file in `.claude/agents/`
2. Use lowercase hyphen-separated naming (e.g., `my-agent.md`)
3. Required YAML frontmatter format:

```markdown
---
name: my-agent
description: When this agent should be invoked
model: sonnet  # haiku, sonnet, or opus
---

System prompt defining the agent's role and capabilities.
```

4. Model selection guidelines:
   - `haiku` - Simple/fast tasks (data lookup, template generation, content formatting)
   - `sonnet` - Standard development work (coding, review, testing, debugging)
   - `opus` - Complex analysis (security audits, architecture review, incident response)

## Adding a Command

1. Create a new `.md` file in `.claude/commands/`
2. Use lowercase hyphen-separated naming
3. Format:

```markdown
---
name: my-command
description: What this command does
---

Instructions for Claude to follow when this command is invoked.

Use $ARGUMENTS to reference user-provided input.
```

## Adding a Skill

1. Create a directory in `.agents/skills/my-skill/`
2. Add a `SKILL.md` with required frontmatter:

```markdown
---
name: my-skill
description: When this skill should activate and what it does
metadata:
  author: your-name
  version: "1.0.0"
---

# Skill Name

Instructions and reference content.
```

3. Add a symlink in `.claude/skills/`:
   `ln -s ../../.agents/skills/my-skill .claude/skills/my-skill`
4. Optional: add `references/` directory for supporting docs

## Naming Conventions

- Agents: `domain-role.md` (e.g., `python-pro.md`, `backend-architect.md`)
- Commands: `action-noun.md` (e.g., `smart-debug.md`, `code-explain.md`)
- Skills: `topic-scope/` (e.g., `react-expert/`, `skill-scout/`)

## Pull Request Guidelines

1. One agent/command/skill per PR
2. Include a clear description of what it does and when it should be used
3. Test that the agent/command/skill activates correctly in Claude Code
4. Ensure no conflicts with existing names
