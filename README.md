# Claude Code Toolkit

A comprehensive collection of 81 specialized agents, 63 productivity commands, and 7 skills for Claude Code. This toolkit transforms Claude Code into a powerful development platform with domain experts, automation workflows, and best practices built-in.

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Agents](https://img.shields.io/badge/Agents-81-green.svg)
![Commands](https://img.shields.io/badge/Commands-63-orange.svg)
![Skills](https://img.shields.io/badge/Skills-7-purple.svg)

## Quick Start

Get started in 3 simple steps:

```bash
# 1. Clone the repository
git clone https://github.com/sjsayamjain/claude.git
cd claude

# 2. Copy toolkit to your home directory
cp -r .claude/ .agents/ ~/

# 3. Start Claude Code
# The agents, commands, and skills are now available
```



## What's Included

### Agents (81)

Specialized AI agents organized by domain expertise, each optimized with the appropriate Claude model (Haiku, Sonnet, or Opus) for performance and capability.

| Agent | Category | Model | Description |
|-------|----------|-------|-------------|
| **Development & Architecture** |
| fullstack-developer | Development | Sonnet 4.5 | End-to-end feature development from database to UI |
| backend-architect | Development | Opus 4.5 | Enterprise backend system design and architecture |
| backend-typescript-architect | Development | Opus 4.5 | TypeScript backend architecture and best practices |
| frontend-developer | Development | Sonnet 4.5 | Modern frontend development with React, Vue, Angular |
| ui-engineer | Development | Sonnet 4.5 | Component library development and design systems |
| ui-ux-designer | Development | Sonnet 3.7 | User interface and experience design |
| ui-visual-validator | Development | Sonnet 4.5 | Visual regression testing and UI validation |
| mobile-developer | Development | Sonnet 4.5 | iOS, Android, and cross-platform mobile apps |
| graphql-architect | Development | Opus 4.5 | GraphQL schema design and API architecture |
| architect-review | Development | Opus 4.5 | Architecture review and technical decision validation |
| **Language Specialists** |
| python-pro | Languages | Sonnet 4.5 | Python development with modern best practices |
| python-backend-engineer | Languages | Sonnet 4.5 | Python backend services (FastAPI, Django, Flask) |
| typescript-pro | Languages | Sonnet 4.5 | TypeScript expert for type-safe development |
| javascript-pro | Languages | Sonnet 4.5 | JavaScript development across all environments |
| rust-pro | Languages | Sonnet 4.5 | Rust systems programming and safety |
| golang-pro | Languages | Sonnet 4.5 | Go development for scalable services |
| java-pro | Languages | Sonnet 4.5 | Java enterprise application development |
| csharp-pro | Languages | Sonnet 4.5 | C# and .NET development |
| php-pro | Languages | Sonnet 4.5 | PHP web development and frameworks |
| ruby-pro | Languages | Sonnet 4.5 | Ruby and Rails development |
| scala-pro | Languages | Sonnet 4.5 | Scala functional programming |
| elixir-pro | Languages | Sonnet 4.5 | Elixir and Phoenix framework |
| c-pro | Languages | Sonnet 4.5 | C systems programming |
| cpp-pro | Languages | Sonnet 4.5 | C++ modern development |
| sql-pro | Languages | Sonnet 4.5 | SQL query optimization and database design |
| flutter-expert | Languages | Sonnet 4.5 | Flutter cross-platform development |
| unity-developer | Languages | Sonnet 4.5 | Unity game development |
| minecraft-bukkit-pro | Languages | Sonnet 4.5 | Minecraft plugin development with Bukkit/Spigot |
| ios-developer | Languages | Sonnet 4.5 | iOS app development with Swift and SwiftUI |
| **Infrastructure & Operations** |
| devops-troubleshooter | Infrastructure | Sonnet 4.5 | CI/CD pipeline debugging and DevOps solutions |
| deployment-engineer | Infrastructure | Sonnet 4.5 | Production deployment and release management |
| cloud-architect | Infrastructure | Opus 4.5 | Cloud infrastructure design (AWS, Azure, GCP) |
| hybrid-cloud-architect | Infrastructure | Opus 4.5 | Multi-cloud and hybrid infrastructure |
| kubernetes-architect | Infrastructure | Opus 4.5 | Kubernetes cluster design and orchestration |
| database-optimizer | Infrastructure | Sonnet 4.5 | Database performance tuning and optimization |
| database-admin | Infrastructure | Sonnet 4.5 | Database administration and maintenance |
| terraform-specialist | Infrastructure | Sonnet 4.5 | Infrastructure as Code with Terraform |
| incident-responder | Infrastructure | Sonnet 4.5 | Production incident response and resolution |
| network-engineer | Infrastructure | Sonnet 4.5 | Network architecture and troubleshooting |
| dx-optimizer | Infrastructure | Sonnet 4.5 | Developer experience optimization |
| **Quality & Security** |
| code-reviewer | Quality | Sonnet 4.5 | Code review with best practices enforcement |
| senior-code-reviewer | Quality | Opus 4.5 | Senior-level architectural code reviews |
| security-auditor | Security | Opus 4.5 | Security vulnerability assessment and remediation |
| test-automator | Quality | Sonnet 4.5 | Automated testing strategy and implementation |
| performance-engineer | Quality | Sonnet 4.5 | Application performance optimization |
| debugger | Quality | Sonnet 4.5 | Bug investigation and resolution |
| error-detective | Quality | Sonnet 4.5 | Error trace analysis and root cause detection |
| **Data & AI** |
| data-scientist | Data | Sonnet 4.5 | Statistical analysis and machine learning |
| data-engineer | Data | Sonnet 4.5 | Data pipeline and ETL development |
| ai-engineer | AI | Opus 4.5 | AI system design and implementation |
| ml-engineer | AI | Sonnet 4.5 | Machine learning model development |
| mlops-engineer | AI | Sonnet 4.5 | ML pipeline and model deployment |
| prompt-engineer | AI | Sonnet 4.5 | LLM prompt optimization and engineering |
| **Documentation** |
| docs-architect | Documentation | Sonnet 4.5 | Documentation strategy and structure |
| mermaid-expert | Documentation | Haiku 3.5 | Mermaid diagram creation and visualization |
| reference-builder | Documentation | Sonnet 4.5 | API reference and technical documentation |
| tutorial-engineer | Documentation | Sonnet 4.5 | Tutorial and guide creation |
| **Business & Marketing** |
| business-analyst | Business | Sonnet 4.5 | Business requirements and process analysis |
| content-marketer | Marketing | Sonnet 4.5 | Marketing content strategy and creation |
| hr-pro | Business | Sonnet 4.5 | HR processes and documentation |
| sales-automator | Business | Sonnet 4.5 | Sales automation and CRM integration |
| customer-support | Business | Sonnet 4.5 | Customer support workflow automation |
| legal-advisor | Business | Opus 4.5 | Legal compliance and documentation review |
| search-specialist | Marketing | Sonnet 4.5 | Search optimization and strategy |
| **SEO & Content** |
| seo-content-auditor | SEO | Sonnet 4.5 | Content SEO analysis and recommendations |
| seo-meta-optimizer | SEO | Haiku 3.5 | Meta tag optimization for search |
| seo-keyword-strategist | SEO | Sonnet 4.5 | Keyword research and strategy |
| seo-structure-architect | SEO | Sonnet 4.5 | Site structure and information architecture |
| seo-snippet-hunter | SEO | Haiku 3.5 | Featured snippet optimization |
| seo-content-refresher | SEO | Sonnet 4.5 | Content update and refresh strategy |
| seo-cannibalization-detector | SEO | Sonnet 4.5 | Keyword cannibalization detection |
| seo-authority-builder | SEO | Sonnet 4.5 | Authority building and link strategy |
| seo-content-writer | SEO | Sonnet 4.5 | SEO-optimized content creation |
| seo-content-planner | SEO | Sonnet 4.5 | Content calendar and planning |
| **Specialized & Orchestration** |
| quant-analyst | Finance | Opus 4.5 | Quantitative analysis and financial modeling |
| risk-manager | Finance | Opus 4.5 | Risk assessment and mitigation |
| payment-integration | Integration | Sonnet 4.5 | Payment gateway integration |
| legacy-modernizer | Modernization | Opus 4.5 | Legacy system modernization strategy |
| context-manager | Orchestration | Sonnet 4.5 | Project context and knowledge management |
| supreme-orchestrator | Orchestration | Opus 4.5 | Multi-agent workflow coordination |

### Commands (63)

Productivity commands organized by namespace for quick automation and workflow execution.

#### Project Management (`/project:*`)
- `/project:init` - Initialize new project with templates
- `/project:audit` - Comprehensive project health check
- `/project:dependencies` - Dependency analysis and updates
- `/project:structure` - Analyze and optimize project structure
- `/project:clean` - Clean build artifacts and temporary files

#### Development Tools (`/dev:*`)
- `/dev:scaffold` - Generate code scaffolding
- `/dev:refactor` - Automated refactoring suggestions
- `/dev:migrate` - Database and code migration tools
- `/dev:api-client` - Generate API client code
- `/dev:swagger` - Generate OpenAPI/Swagger documentation

#### Testing Suite (`/test:*`)
- `/test:generate` - Generate test cases from code
- `/test:coverage` - Analyze test coverage
- `/test:e2e` - End-to-end test setup and execution
- `/test:integration` - Integration test generation
- `/test:snapshot` - Snapshot testing for UI components

#### Security & Compliance (`/security:*`)
- `/security:scan` - Security vulnerability scanning
- `/security:audit` - Full security audit
- `/security:secrets` - Detect hardcoded secrets
- `/security:dependencies` - Check for vulnerable dependencies
- `/security:compliance` - Compliance checklist (GDPR, SOC2, etc.)

#### Performance Optimization (`/performance:*`)
- `/performance:profile` - Performance profiling analysis
- `/performance:bundle` - Bundle size optimization
- `/performance:lighthouse` - Lighthouse audit automation
- `/performance:db-query` - Database query optimization
- `/performance:memory` - Memory leak detection

#### Deployment & Release (`/deploy:*`)
- `/deploy:preview` - Generate deployment preview
- `/deploy:rollback` - Rollback to previous version
- `/deploy:canary` - Canary deployment setup
- `/deploy:blue-green` - Blue-green deployment
- `/deploy:checklist` - Pre-deployment checklist

#### Documentation (`/docs:*`)
- `/docs:generate` - Auto-generate documentation
- `/docs:api` - API documentation from code
- `/docs:readme` - Generate comprehensive README
- `/docs:changelog` - Generate changelog from commits
- `/docs:architecture` - Architecture diagram generation

#### Configuration (`/setup:*`)
- `/setup:env` - Environment configuration wizard
- `/setup:docker` - Docker configuration generation
- `/setup:ci` - CI/CD pipeline setup
- `/setup:linter` - Linting and formatting setup
- `/setup:pre-commit` - Git hooks configuration

#### Team Collaboration (`/team:*`)
- `/team:onboard` - New team member onboarding
- `/team:standup` - Generate standup report
- `/team:review` - Code review checklist
- `/team:retro` - Sprint retrospective template
- `/team:rfc` - Request for Comments template

#### AI Simulators (`/simulation:*`)
- `/simulation:user` - Simulate user behavior
- `/simulation:load` - Load testing simulation
- `/simulation:attack` - Security attack simulation
- `/simulation:feedback` - Generate user feedback scenarios
- `/simulation:ab-test` - A/B test scenario generation

### Skills (7)

Specialized skill modules with reference documentation and context.

| Skill | Source | Description |
|-------|--------|-------------|
| skill-scout | Custom | Search and discover Claude Code skills on GitHub |
| react-expert | Jeffallan/claude-skills | React 19 specialist with 7 reference documentation files |
| vercel-react-best-practices | vercel-labs | 57 React and Next.js performance optimization rules |
| vercel-composition-patterns | vercel-labs | React composition patterns and best practices |
| vercel-react-native-skills | vercel-labs | 35+ React Native development best practices |
| web-design-guidelines | vercel-labs | UI compliance review and accessibility guidelines |
| find-skills | vercel-labs | Skill discovery CLI for community skills |

## Installation

### Method 1: Quick Copy

The simplest installation method copies all files directly to your home directory:

```bash
cd claude-code-toolkit
cp -r .claude/ .agents/ ~/
```

This will place:
- Agents in `~/.claude/agents/`
- Commands in `~/.claude/commands/`
- Skills in `~/.claude/skills/` and `~/.agents/skills/`

The install script:
- Checks for existing files and prompts for conflicts
- Creates symlinks to preserve updates
- Provides rollback capability
- Validates installation success

### Verification

After installation, verify the toolkit is available:

```bash
# Start Claude Code in any project
claude

# List available agents
/agents

# List available commands
/help

# Test a skill
/skill:find-skills
```

## Model Assignments

Agents are assigned to Claude models based on task complexity and required capabilities:

### Haiku 3.5 (15 agents)
Fast, efficient agents for straightforward tasks:
- SEO optimization (meta tags, snippets)
- Diagram generation
- Simple content tasks

### Sonnet 4.5 (45 agents)
Balanced performance for most development tasks:
- Language specialists
- Development workflows
- Infrastructure operations
- Quality assurance
- Data engineering

### Opus 4.5 (15 agents)
Advanced reasoning for complex architecture and strategy:
- System architecture
- Security auditing
- Legal compliance
- Cloud infrastructure design
- Senior code reviews
- Multi-agent orchestration

## Usage Examples

### Single Agent Workflows

Ask a specific agent to handle a task:

```bash
# Backend architecture design
@backend-architect Design a microservices architecture for an e-commerce platform

# Security audit
@security-auditor Review this authentication implementation for vulnerabilities

# Performance optimization
@performance-engineer Optimize this React component rendering
```

### Multi-Agent Workflows

Combine agents for complex projects:

```bash
# Full feature development
@supreme-orchestrator Build a user authentication system with:
- @backend-architect: Design the auth service
- @frontend-developer: Build login/register UI
- @security-auditor: Review implementation
- @test-automator: Create test suite
- @docs-architect: Document the flow

# Infrastructure setup
@cloud-architect Design AWS infrastructure for high-traffic app
@kubernetes-architect Create K8s deployment configs
@terraform-specialist Generate IaC code
@devops-troubleshooter Set up CI/CD pipeline
```

### Command Workflows

Chain commands for automated workflows:

```bash
# Pre-deployment workflow
/security:scan
/test:coverage
/performance:bundle
/deploy:checklist
/deploy:preview

# New project setup
/project:init
/setup:env
/setup:docker
/setup:ci
/setup:pre-commit
```

### Skill Usage

Leverage skills for specialized knowledge:

```bash
# React development with best practices
/skill:react-expert Build a data table with pagination

# Discover new skills
/skill:find-skills search react testing

# Apply Vercel patterns
/skill:vercel-composition-patterns Show me compound component pattern
```

## Repository Structure

```
claude-code-toolkit/
├── .agents/
│   └── skills/
│       ├── skill-scout/
│       ├── react-expert/
│       ├── vercel-react-best-practices/
│       ├── vercel-composition-patterns/
│       ├── vercel-react-native-skills/
│       ├── web-design-guidelines/
│       └── find-skills/
├── .claude/
│   ├── agents/          # 81 agent .md files
│   ├── commands/        # 63 command .md files
│   └── skills/          # Symlinks to .agents/skills/
├── .gitignore
├── .gitattributes
├── LICENSE
├── README.md
├── ATTRIBUTION.md
├── CONTRIBUTING.md
```

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Areas for contribution:
- New specialized agents
- Additional productivity commands
- Skill modules with reference docs
- Documentation improvements
- Bug fixes and optimizations

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Attribution

This toolkit includes components from multiple sources. See [ATTRIBUTION.md](ATTRIBUTION.md) for complete attribution and licensing information.

Key sources:
- Custom agents and commands (MIT License)
- Skills from Jeffallan/claude-skills
- Skills from vercel-labs/ai-sdk-skills
- Community contributions

## Support

- Issues: [GitHub Issues](https://github.com/yourusername/claude-code-toolkit/issues)
- Discussions: [GitHub Discussions](https://github.com/yourusername/claude-code-toolkit/discussions)
- Documentation: [Wiki](https://github.com/yourusername/claude-code-toolkit/wiki)

---

Built with Claude Code for Claude Code developers.
