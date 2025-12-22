# gcloud-expert

A comprehensive Claude Code skill for expert-level Google Cloud CLI (gcloud) management.

## Overview

This skill transforms Claude into a GCP infrastructure expert, providing:

- **Cross-platform installation** guides for macOS, Windows, and Linux
- **Multi-account management** with named configurations
- **Authentication patterns** including OAuth, service accounts, and Workload Identity Federation
- **IAM governance** with least-privilege patterns
- **Deployment workflows** for Cloud Run, Firebase, and containerized applications
- **CI/CD integration** with GitHub Actions and Cloud Build
- **Database management** for AlloyDB and Cloud SQL
- **Automation scripts** for common operations

## Installation

### For Claude Code Users

Copy the `gcloud` folder to your Claude Code skills directory:

```bash
# macOS/Linux
cp -r gcloud ~/.claude/skills/

# Or clone directly
git clone https://github.com/SpillwaveSolutions/gcloud_skill.git ~/.claude/skills/gcloud
```

### Verify Installation

The skill activates automatically when you mention gcloud, GCP, Cloud Run, or related terms.

## Skill Structure

```
gcloud/
├── SKILL.md                    # Main skill file with workflows
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
│   └── verification-patterns.md
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

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add or improve documentation/scripts
4. Submit a pull request

## License

MIT License - See LICENSE file for details.

## Author

Created by Richard Hightower / Spillwave Solutions

---

*This skill was created using the [skill-creator](https://github.com/anthropics/claude-code) pattern for Claude Code.*
