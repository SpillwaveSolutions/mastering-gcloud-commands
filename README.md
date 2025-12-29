# Mastering Google Cloud CLI

Expert-level Google Cloud CLI (gcloud) skill for managing GCP resources.

## Overview

This skill provides comprehensive gcloud CLI patterns for:

- **Cross-platform installation** guides for macOS, Windows, and Linux
- **Multi-account management** with named configurations
- **Authentication patterns** including OAuth, service accounts, and Workload Identity Federation
- **IAM governance** with least-privilege patterns
- **Deployment workflows** for Cloud Run, Firebase, and containerized applications
- **CI/CD integration** with GitHub Actions and Cloud Build
- **Database management** for AlloyDB and Cloud SQL
- **VPC networking** including subnets, firewall rules, and VPC connectors
- **Secret management** with Secret Manager integration
- **Automation scripts** with error handling and idempotent patterns

## Installing with Skilz (Universal Installer)

The recommended way to install this skill across different AI coding agents is using the **skilz** universal installer.

### Install Skilz

```bash
pip install skilz
```

This skill supports [Agent Skill Standard](https://agentskills.io/) which means it supports 14 plus coding agents including Claude Code, OpenAI Codex, Cursor and Gemini.

### Git URL Options

You can use either `-g` or `--git` with HTTPS or SSH URLs:

```bash
# HTTPS URL
skilz install -g https://github.com/SpillwaveSolutions/mastering-gcloud-commands

# SSH URL
skilz install --git git@github.com:SpillwaveSolutions/mastering-gcloud-commands.git
```

### Claude Code

Install to user home (available in all projects):
```bash
skilz install -g https://github.com/SpillwaveSolutions/mastering-gcloud-commands
```

Install to current project only:
```bash
skilz install -g https://github.com/SpillwaveSolutions/mastering-gcloud-commands --project
```

### OpenCode

Install for [OpenCode](https://opencode.ai):
```bash
skilz install -g https://github.com/SpillwaveSolutions/mastering-gcloud-commands --agent opencode
```

Project-level install:
```bash
skilz install -g https://github.com/SpillwaveSolutions/mastering-gcloud-commands --project --agent opencode
```

### Gemini

Project-level install for Gemini:
```bash
skilz install -g https://github.com/SpillwaveSolutions/mastering-gcloud-commands --agent gemini
```

### OpenAI Codex

Install for OpenAI Codex:
```bash
skilz install -g https://github.com/SpillwaveSolutions/mastering-gcloud-commands --agent codex
```

Project-level install:
```bash
skilz install -g https://github.com/SpillwaveSolutions/mastering-gcloud-commands --project --agent codex
```

### Install from Skillzwave Marketplace

```bash
# Claude to user home dir ~/.claude/skills
skilz install SpillwaveSolutions_mastering-gcloud-commands/mastering-gcloud-commands

# Claude skill in project folder ./claude/skills
skilz install SpillwaveSolutions_mastering-gcloud-commands/mastering-gcloud-commands --project

# OpenCode install to user home dir ~/.config/opencode/skills
skilz install SpillwaveSolutions_mastering-gcloud-commands/mastering-gcloud-commands --agent opencode

# OpenCode project level
skilz install SpillwaveSolutions_mastering-gcloud-commands/mastering-gcloud-commands --agent opencode --project

# OpenAI Codex install to user home dir ~/.codex/skills
skilz install SpillwaveSolutions_mastering-gcloud-commands/mastering-gcloud-commands --agent codex

# OpenAI Codex project level ./.codex/skills
skilz install SpillwaveSolutions_mastering-gcloud-commands/mastering-gcloud-commands --agent codex --project

# Gemini CLI (project level) -- only works with project level
skilz install SpillwaveSolutions_mastering-gcloud-commands/mastering-gcloud-commands --agent gemini
```

See this site [skill Listing](https://skillzwave.ai/skill/SpillwaveSolutions__mastering-gcloud-commands__mastering-gcloud-commands__SKILL/) to see how to install this exact skill to 14+ different coding agents.

### Other Supported Agents

Skilz supports 14+ coding agents including Windsurf, Qwen Code, Aidr, and more.

For the full list of supported platforms, visit [SkillzWave.ai/platforms](https://skillzwave.ai/platforms/) or see the [skilz-cli GitHub repository](https://github.com/SpillwaveSolutions/skilz-cli)

## Manual Installation

Copy this skill to your Claude Code skills directory:

```bash
# User-level installation
cp -r mastering-gcloud-commands ~/.claude/skills/

# Or create a symlink
ln -s "$(pwd)" ~/.claude/skills/mastering-gcloud-commands
```

## Verify Installation

The skill activates automatically when you mention gcloud, GCP, Cloud Run, or related terms.

## Skill Structure

```
mastering-gcloud-commands/
├── SKILL.md                    # Main skill file with decision trees and workflows
├── references/                 # Detailed documentation (loaded on-demand)
│   ├── installation-macos.md   # macOS: Homebrew, Apple Silicon
│   ├── installation-windows.md # Windows: installer, PowerShell, silent
│   ├── installation-linux.md   # Linux: apt, dnf, Docker
│   ├── authentication.md       # OAuth, service accounts, WIF
│   ├── authentication-reset.md # Credential cleanup procedures
│   ├── multi-account-management.md
│   ├── iam-permissions.md      # Roles, custom roles, policies
│   ├── cloud-run-deployment.md # Source, container, traffic splitting
│   ├── cloud-scheduler.md      # Scheduled jobs with OIDC
│   ├── cloud-storage.md        # Bucket and object operations
│   ├── alloydb-management.md   # Cluster and instance management
│   ├── firebase-management.md  # Firebase CLI integration
│   ├── cicd-integration.md     # GitHub Actions, Cloud Build
│   ├── api-enablement.md       # Required APIs by category
│   ├── verification-patterns.md
│   ├── vpc-networking.md       # VPCs, subnets, firewall, connectors
│   ├── secret-manager.md       # Secrets, versions, IAM bindings
│   ├── troubleshooting.md      # Debug mode, common errors
│   └── scripting-patterns.md   # Error handling, batch ops, jq parsing
└── scripts/                    # Ready-to-use automation scripts
    ├── deploy-cloud-run.sh     # Deployment with common options
    ├── setup-wif-github.sh     # Workload Identity Federation setup
    ├── verify-gcp-setup.sh     # Comprehensive project verification
    ├── reset-gcloud-auth.sh    # Authentication cleanup
    ├── switch-gcloud-project.sh # Project switching helper
    └── setup-gcloud-configs.sh # Multi-config initialization
```

## Quick Reference

### Essential Commands

```bash
# Authentication
gcloud auth login                              # Browser-based user login
gcloud auth list                               # List authenticated accounts
gcloud auth activate-service-account --key-file=KEY.json

# Configuration Management
gcloud config configurations list              # List all configurations
gcloud config configurations create NAME       # Create new profile
gcloud config configurations activate NAME     # Switch active profile
gcloud config set project PROJECT_ID           # Set default project

# Common Operations
gcloud projects list                           # List accessible projects
gcloud run deploy SERVICE --source .           # Deploy to Cloud Run
gcloud storage cp FILE gs://BUCKET/            # Upload to Cloud Storage
```

### Example Prompts

When using Claude Code with this skill:

```
"Help me set up gcloud on my Mac"
"Configure Workload Identity Federation for GitHub Actions"
"Deploy my app to Cloud Run with traffic splitting"
"Set up a Cloud Scheduler job to trigger my Cloud Run service"
"Create IAM roles for my CI/CD pipeline"
"Switch between my dev and prod GCP projects"
```

## Scripts

### deploy-cloud-run.sh

Deploy to Cloud Run with common options:

```bash
./scripts/deploy-cloud-run.sh my-api --source . --allow-unauth
./scripts/deploy-cloud-run.sh my-api --image gcr.io/project/image:v1 --env API_KEY=abc
./scripts/deploy-cloud-run.sh my-api --source . --no-traffic --tag canary
```

### setup-wif-github.sh

Set up Workload Identity Federation for GitHub Actions (keyless authentication):

```bash
# Preview changes
./scripts/setup-wif-github.sh --dry-run my-project my-org my-repo

# Execute setup
./scripts/setup-wif-github.sh my-project my-org my-repo
```

### verify-gcp-setup.sh

Comprehensive verification of your GCP project:

```bash
./scripts/verify-gcp-setup.sh --project-id my-project --verbose
```

### reset-gcloud-auth.sh

Clean up authentication when troubleshooting:

```bash
./scripts/reset-gcloud-auth.sh              # Credentials only
./scripts/reset-gcloud-auth.sh --full-reset # Credentials + configurations
```

### switch-gcloud-project.sh

Efficient project switching:

```bash
./scripts/switch-gcloud-project.sh switch my-project
./scripts/switch-gcloud-project.sh list
./scripts/switch-gcloud-project.sh status
```

## Features by Category

### Installation & Setup
- Homebrew installation for macOS
- Interactive installer for Windows
- Package manager (apt/dnf) for Linux
- Docker-based installation
- Shell integration (bash, zsh, fish, PowerShell)

### Authentication
- Browser-based OAuth login
- Service account key authentication
- Service account impersonation (recommended)
- Workload Identity Federation (keyless CI/CD)
- Application Default Credentials (ADC)

### Multi-Account Management
- Named configurations for different projects/environments
- Quick context switching
- Per-command configuration override
- Environment variable configuration

### Deployment
- Cloud Run from source or container
- Traffic splitting and canary deployments
- Cloud Scheduler with OIDC authentication
- Firebase Hosting and Functions
- Artifact Registry integration

### Security & IAM
- Least-privilege role patterns
- Custom role creation
- Conditional IAM bindings
- Service account best practices
- Audit logging

### CI/CD
- GitHub Actions with WIF (keyless)
- GitHub Actions with service account keys
- Cloud Build triggers and configurations
- GitLab CI integration
- Jenkins pipelines

## Progressive Disclosure Architecture

This skill uses a three-level loading system for efficient context usage:

1. **Metadata** (~100 words) - Always loaded, triggers skill activation
2. **SKILL.md** (<5K words) - Quick reference workflows
3. **References** (unlimited) - Detailed docs loaded on-demand

When you ask about a specific topic, Claude loads only the relevant reference file.

## Version

- **Version:** 1.0.0
- **Author:** Richard Hightower / Spillwave Solutions
- **License:** MIT

## Contributing

1. Fork this repository
2. Add or update reference files in `references/`
3. Update `SKILL.md` navigation if adding new files
4. Submit a pull request

## Related Skills

- `mastering-aws-cli` - AWS CLI reference
- `mastering-github-cli` - GitHub CLI reference

---

<a href="https://skillzwave.ai/">Largest Agentic Marketplace for AI Agent Skills</a> and
<a href="https://spillwave.com/">SpillWave: Leaders in AI Agent Development.</a>
