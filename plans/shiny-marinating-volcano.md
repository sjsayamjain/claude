# Plan: Restructure Claude Code Toolkit Repository

Transform the current project into a clean, shareable GitHub repository for Claude Code agents, commands, and skills.

## Current State

- **1 committed file**: `.gitattributes`
- **81 agent `.md` files** in `.claude/agents/` (sourced from [wshobson/agents](https://github.com/wshobson/agents), MIT)
- **63 command `.md` files** in `.claude/commands/` (sourced from [wshobson/commands](https://github.com/wshobson/commands), MIT)
- **7 skills** in `.agents/skills/` (5 from vercel-labs, 1 from Jeffallan, 1 custom)
- **Plugin config**: `frontend-design` enabled, 2 marketplaces registered
- Everything except `.gitattributes` is untracked

## Restructured Repository Layout

```
claude-code-toolkit/
├── .gitignore
├── .gitattributes              (exists)
├── LICENSE                     (new - MIT)
├── README.md                   (new - comprehensive)
├── ATTRIBUTION.md              (new - credits for sourced content)
├── CONTRIBUTING.md             (new - how to add agents/commands/skills)
├── install.sh                  (new - automated installer)
│
├── agents/                     (move from .claude/agents/)
│   ├── README.md               (adapt existing)
│   ├── LICENSE                 (preserve existing MIT from wshobson)
│   └── *.md                    (81 agent files, flat)
│
├── commands/                   (move from .claude/commands/)
│   ├── README.md               (adapt existing)
│   └── *.md                    (63 command files, flat)
│
├── skills/                     (move from .agents/skills/)
│   ├── README.md               (new - skill inventory table)
│   ├── skill-scout/            (custom)
│   ├── react-expert/           (MIT, Jeffallan)
│   ├── vercel-react-best-practices/  (MIT, vercel-labs)
│   ├── vercel-composition-patterns/  (MIT, vercel-labs)
│   ├── vercel-react-native-skills/   (MIT, vercel-labs)
│   ├── web-design-guidelines/  (MIT, vercel-labs)
│   └── find-skills/            (MIT, vercel-labs)
│
├── config/                     (new - example configs)
│   ├── README.md
│   └── settings.example.json
│
└── scripts/
    └── validate.sh             (new - structural validation)
```

**Key decisions:**
- Agent/command files stay **flat** (Claude Code loads from flat directories)
- No category subdirectories for agents/commands (would break loading)
- All external content is MIT-licensed, safe to redistribute with attribution
- Plugin runtime data (cache, marketplaces, lock files) excluded via `.gitignore`
- Remove `.claude/` and `.agents/` wrapper dirs -- top-level `agents/`, `commands/`, `skills/` are the source of truth

## Implementation Steps

### Step 1: Create `.gitignore`
Ignore macOS files, editor files, plugin caches, runtime state, lock files.

### Step 2: Create `LICENSE`
MIT license, copyright 2026 Sayam Jain.

### Step 3: Move content to top-level directories
- `mv .claude/agents/*.md agents/` (81 agent files + README + LICENSE)
- `mv .claude/commands/*.md commands/` (63 command files + README)
- `cp -r .agents/skills/* skills/` (7 skill directories)
- Remove the now-empty `.claude/` and `.agents/` directories from the repo

### Step 4: Create `README.md`
Comprehensive root README with:
- Overview (81 agents, 63 commands, 7 skills)
- Quick start (3 steps: clone, run install.sh, verify)
- Full agent inventory table grouped by category (Development, Languages, Infrastructure, Quality, Data/AI, Documentation, Business, SEO)
- Full command inventory grouped by namespace (/project, /dev, /test, /security, /performance, /deploy, /docs, /setup, /team, /simulation)
- Skills table with source attribution
- Installation methods (script, manual symlink, selective copy)
- Usage examples
- License

### Step 5: Create `ATTRIBUTION.md`
Credit wshobson/agents (81 agents), wshobson/commands (63 commands), vercel-labs/agent-skills (4 skills), vercel-labs/skills (1 skill), Jeffallan/claude-skills (1 skill).

### Step 6: Create `CONTRIBUTING.md`
Guide for adding new agents, commands, and skills with format templates and naming conventions.

### Step 7: Adapt `agents/README.md`
Update the existing README to reference this repo instead of wshobson/agents. Fix installation paths. Keep the comprehensive category listings and model assignments.

### Step 8: Adapt `commands/README.md`
Update to reference this repo instead of wshobson/commands.

### Step 9: Create `skills/README.md`
Table of all 7 skills with name, source, license, description, file count.

### Step 10: Create `install.sh`
Bash script that:
- Symlinks `agents/*.md` to `~/.claude/agents/`
- Symlinks `commands/*.md` to `~/.claude/commands/`
- Symlinks `skills/*/` to `~/.agents/skills/`
- Supports `--copy` flag for standalone copies
- Never overwrites existing files without confirmation
- Prints summary of installed items

### Step 11: Create `config/` examples
- `settings.example.json` -- sanitized settings template
- `config/README.md` -- explains what each config does

### Step 12: Create `scripts/validate.sh`
Checks that all agent/command files have YAML frontmatter, all skills have SKILL.md, no broken references.

### Step 13: Clean up and verify
- Remove any `.DS_Store` files
- Verify no absolute paths or user-specific data in committed files
- Run validation script
- Update all internal cross-references to use new paths

## Files to Create/Modify

| File | Action | Lines (est.) |
|------|--------|-------------|
| `.gitignore` | Create | ~25 |
| `LICENSE` | Create | ~21 |
| `README.md` | Create | ~350 |
| `ATTRIBUTION.md` | Create | ~60 |
| `CONTRIBUTING.md` | Create | ~100 |
| `install.sh` | Create | ~120 |
| `agents/README.md` | Edit | ~526 (adapt existing) |
| `commands/README.md` | Edit | ~73 (adapt existing) |
| `skills/README.md` | Create | ~40 |
| `config/README.md` | Create | ~30 |
| `config/settings.example.json` | Create | ~10 |
| `scripts/validate.sh` | Create | ~80 |

Plus **moving** 81 agent files, 63 command files, and 7 skill directories to their new locations.

## Verification

1. Run `scripts/validate.sh` to confirm structural integrity
2. Run `install.sh` on a clean machine (or after backing up `~/.claude/agents/` and `~/.agents/skills/`)
3. Open Claude Code and verify agents, commands, and skills are discoverable
4. Check `git status` confirms no untracked runtime files leak in
