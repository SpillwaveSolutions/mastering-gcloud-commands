# Multi-Account and Configuration Management

This guide covers managing multiple GCP accounts and projects using gcloud configurations,
enabling seamless context switching between environments.

## Understanding Configurations

A **configuration** is a named profile storing:
- Active account (user or service account)
- Default project
- Default compute region and zone
- Service-specific settings (Cloud Run region, etc.)

Configurations are stored in `~/.config/gcloud/configurations/`.

## Configuration Lifecycle

### List Configurations

```bash
gcloud config configurations list

# OUTPUT:
# NAME          IS_ACTIVE  ACCOUNT                PROJECT           REGION
# default       False      user@example.com       my-project-123    us-east1
# development   True       dev@example.com        dev-project       us-west1
# production    False      sa@prod.iam.gserv...   prod-project      us-central1
```

### Create Configuration

```bash
# Create and automatically activate
gcloud config configurations create development

# Create without activating
gcloud config configurations create staging --no-activate
```

### Activate Configuration

```bash
gcloud config configurations activate production

# Verify
gcloud config configurations list
```

### Delete Configuration

```bash
gcloud config configurations delete old-config

# Cannot delete active configuration - switch first
gcloud config configurations activate default
gcloud config configurations delete old-config
```

### Describe Configuration

```bash
gcloud config configurations describe development
```

## Setting Configuration Properties

### Core Properties

```bash
# Set default project
gcloud config set project PROJECT_ID

# Set default account
gcloud config set account user@example.com

# Set default output format
gcloud config set core/format json
```

### Compute Properties

```bash
# Set default region
gcloud config set compute/region us-central1

# Set default zone
gcloud config set compute/zone us-central1-a
```

### Service-Specific Properties

```bash
# Cloud Run
gcloud config set run/region us-central1
gcloud config set run/platform managed

# Cloud Functions
gcloud config set functions/region us-central1

# GKE
gcloud config set container/cluster my-cluster
```

### View All Properties

```bash
# Current configuration
gcloud config list

# All properties with values
gcloud config list --all

# Specific property
gcloud config get-value project
gcloud config get-value compute/region
```

### Unset Properties

```bash
gcloud config unset compute/region
gcloud config unset auth/impersonate_service_account
```

## Multi-Environment Strategy

### Recommended Configuration Structure

| Configuration | Account | Project | Region | Use Case |
|--------------|---------|---------|--------|----------|
| default | (empty) | (empty) | (empty) | Clean fallback |
| personal | user@gmail.com | personal-sandbox | us-west2 | Learning/testing |
| work-dev | dev@company.com | company-dev | us-central1 | Development |
| work-staging | dev@company.com | company-staging | us-east1 | Staging tests |
| work-prod | sa@prod.iam... | company-prod | us-central1 | Production ops |

### Setup Script

```bash
#!/bin/bash
# setup-gcloud-configs.sh

# Development configuration
gcloud config configurations create work-dev
gcloud auth login  # Authenticate with dev account
gcloud config set project company-dev
gcloud config set compute/region us-central1
gcloud config set run/region us-central1

# Staging configuration
gcloud config configurations create work-staging
gcloud config set account dev@company.com  # Reuse existing auth
gcloud config set project company-staging
gcloud config set compute/region us-east1

# Production configuration (with service account)
gcloud config configurations create work-prod
gcloud auth activate-service-account \
  --key-file=~/keys/prod-sa.json
gcloud config set project company-prod
gcloud config set compute/region us-central1

# Return to dev
gcloud config configurations activate work-dev
```

## Context Switching Patterns

### Manual Switching

```bash
# Switch to production
gcloud config configurations activate work-prod

# Verify before dangerous operations
gcloud config configurations list
gcloud config get-value project
```

### Per-Command Override

Without changing active configuration:

```bash
# Use specific configuration
gcloud --configuration=work-prod compute instances list

# Override project only
gcloud storage buckets list --project=different-project

# Override multiple properties
gcloud run deploy my-service \
  --project=staging-project \
  --region=europe-west1 \
  --account=other@example.com
```

### Environment Variable Override

```bash
# For current shell session
export CLOUDSDK_ACTIVE_CONFIG_NAME=work-prod
gcloud projects list  # Uses work-prod

# For single command
CLOUDSDK_ACTIVE_CONFIG_NAME=work-prod gcloud storage buckets list
```

### Separate Configuration Directories

For complete isolation (useful in CI/CD):

```bash
# Create isolated config directory
export CLOUDSDK_CONFIG=/tmp/gcloud-prod
gcloud auth activate-service-account --key-file=prod-key.json
gcloud config set project prod-project

# Another isolated directory
export CLOUDSDK_CONFIG=/tmp/gcloud-dev
gcloud auth login
gcloud config set project dev-project

# Use specific directory
CLOUDSDK_CONFIG=/tmp/gcloud-prod gcloud compute instances list
```

## Shell Integration

### Zsh/Bash Functions

Add to `~/.zshrc` or `~/.bashrc`:

```bash
# Quick switch functions
gdev() { gcloud config configurations activate work-dev; }
gstg() { gcloud config configurations activate work-staging; }
gprod() { gcloud config configurations activate work-prod; }

# Show current context in prompt
gcloud_prompt() {
  local project=$(gcloud config get-value project 2>/dev/null)
  local config=$(gcloud config configurations list --filter="is_active=true" --format="value(name)" 2>/dev/null)
  if [[ -n "$project" ]]; then
    echo " ☁️ ${config}:${project}"
  fi
}

# For Zsh
PROMPT='%n@%m %~$(gcloud_prompt) $ '

# For Bash
PS1='\u@\h \w$(gcloud_prompt) $ '
```

### Starship Prompt Integration

Add to `~/.config/starship.toml`:

```toml
[gcloud]
format = '[$symbol($project)]($style) '
style = 'blue bold'
symbol = '☁️ '
```

## Configuration File Structure

Configurations are stored as INI files:

```
~/.config/gcloud/configurations/
├── config_default
├── config_work-dev
├── config_work-staging
└── config_work-prod
```

Example `config_work-dev`:

```ini
[core]
account = dev@company.com
project = company-dev

[compute]
region = us-central1
zone = us-central1-a

[run]
region = us-central1
platform = managed
```

## Best Practices

### 1. Always Verify Before Destructive Operations

```bash
# Before delete/update operations
echo "Current config: $(gcloud config configurations list --filter='is_active=true' --format='value(name)')"
echo "Project: $(gcloud config get-value project)"
read -p "Continue? (y/n) " confirm
```

### 2. Use Descriptive Configuration Names

- `work-prod` not `config1`
- `personal-sandbox` not `default2`
- `client-acme-staging` for client-specific

### 3. Set Reasonable Defaults

```bash
# Prevent accidental global changes
gcloud config set core/disable_prompts false
```

### 4. Document Configuration Purpose

Create a README in your notes:

```markdown
## My gcloud Configurations

- **work-dev**: Daily development on company-dev project
- **work-staging**: Testing before production releases
- **work-prod**: Production operations (use with caution!)
- **personal**: Personal GCP sandbox for learning
```

### 5. Use Service Accounts for Production

```bash
# Production config should use service account
gcloud config configurations activate work-prod
gcloud auth activate-service-account --key-file=prod-sa.json
# Or use impersonation
gcloud config set auth/impersonate_service_account prod-sa@project.iam.gserviceaccount.com
```

## Troubleshooting

### Configuration Not Switching

```bash
# Check for env variable override
echo $CLOUDSDK_ACTIVE_CONFIG_NAME

# Unset if present
unset CLOUDSDK_ACTIVE_CONFIG_NAME

# Then switch
gcloud config configurations activate desired-config
```

### Properties Not Taking Effect

```bash
# Check if command-line flag overrides
gcloud config list

# Some commands have their own caching
gcloud auth revoke --all
gcloud auth login
```

### Corrupted Configuration

```bash
# View raw config file
cat ~/.config/gcloud/configurations/config_broken

# Delete and recreate
gcloud config configurations delete broken
gcloud config configurations create broken
# Reconfigure...
```
