---
name: gcloud-expert
description: |
  Expert-level Google Cloud CLI (gcloud) skill for managing GCP resources. This skill should be
  used when working with gcloud commands, gcp, google cloud, cloud run, cloud scheduler, alloydb,
  cloud storage, gcs buckets, firebase deploy, gcloud auth, gcloud config, service accounts,
  workload identity federation, iam permissions, or artifact registry. Use this to install gcloud
  on macOS, Windows, or Linux. Use this to manage multi-account configuration of GCP with gcloud.
  Use this to configure authentication on GCP with gcloud for OAuth, service accounts, and
  Workload Identity Federation (WIF). Use this to set up IAM roles, permissions, and governance.
  Use this to deploy applications to Cloud Run or Firebase. Use this to manage database instances
  including AlloyDB and Cloud SQL. Use this to configure GitHub Actions or Cloud Build CI/CD
  pipelines. Use this to set up Docker container deployments. Use this to write bash scripts for
  GCP automation. Use this to manage git-triggered deployments or configure API authentication.
version: 1.0.0
category: cloud-infrastructure
author: Richard Hightower
license: MIT
metadata:
  triggers:
    - gcloud
    - gcp
    - google cloud
    - cloud run
    - cloud scheduler
    - alloydb
    - cloud storage
    - firebase deploy
    - github actions
    - docker
    - deploy
tags:
  - gcloud
  - gcp
  - cloud-run
  - firebase
  - cloud-storage
  - iam
  - ci-cd
  - devops
---

# Google Cloud CLI Expert Skill

This skill provides comprehensive guidance for the Google Cloud CLI (gcloud) ecosystem on macOS,
covering installation, multi-account management, authentication, IAM governance, and deployment
of applications across GCP services.

## Quick Reference

### Essential Commands

```bash
# Authentication
gcloud auth login                              # Browser-based user login
gcloud auth list                               # List authenticated accounts
gcloud auth activate-service-account --key-file=KEY.json  # Service account auth

# Configuration Management
gcloud config configurations list              # List all configurations
gcloud config configurations create NAME       # Create new profile
gcloud config configurations activate NAME     # Switch active profile
gcloud config set project PROJECT_ID           # Set default project
gcloud config set compute/region REGION        # Set default region

# Common Operations
gcloud projects list                           # List accessible projects
gcloud run deploy SERVICE --source .           # Deploy to Cloud Run
gcloud storage cp FILE gs://BUCKET/            # Upload to Cloud Storage
gcloud scheduler jobs list --location=REGION   # List scheduler jobs
```

## Workflow: Initial Setup on macOS

To set up gcloud CLI on a new macOS system:

1. **Install via Homebrew** (recommended):
   ```bash
   brew install --cask google-cloud-sdk
   ```

2. **Initialize**:
   ```bash
   gcloud init
   ```

3. **Verify installation**:
   ```bash
   gcloud --version
   gcloud config list
   ```

For detailed installation instructions:
- macOS: `references/installation-macos.md` (Homebrew, Apple Silicon)
- Windows: `references/installation-windows.md` (installer, PowerShell, silent install)
- Linux: `references/installation-linux.md` (apt, dnf/yum, Docker)

## Workflow: Multi-Account Configuration

To manage multiple GCP accounts and projects efficiently:

1. **Create named configurations** for each environment:
   ```bash
   gcloud config configurations create dev
   gcloud config configurations create staging
   gcloud config configurations create prod
   ```

2. **Configure each profile**:
   ```bash
   gcloud config configurations activate dev
   gcloud auth login  # Authenticate with dev account
   gcloud config set project dev-project-123
   gcloud config set compute/region us-west1
   ```

3. **Switch contexts**:
   ```bash
   gcloud config configurations activate prod
   ```

4. **Override for single command** (without switching):
   ```bash
   gcloud --configuration=prod compute instances list
   ```

For comprehensive multi-account patterns, see `references/multi-account-management.md`.

## Workflow: Authentication

### User Authentication (Interactive)

```bash
gcloud auth login                    # Opens browser for OAuth
gcloud auth login --no-launch-browser  # For remote/SSH sessions
```

### Service Account Authentication (Automation)

```bash
# Create service account
gcloud iam service-accounts create my-sa \
  --display-name="My Service Account"

# Download key (use sparingly - prefer Workload Identity)
gcloud iam service-accounts keys create key.json \
  --iam-account=my-sa@PROJECT.iam.gserviceaccount.com

# Activate
gcloud auth activate-service-account --key-file=key.json
```

### Service Account Impersonation (Recommended)

```bash
# Grant token creator role
gcloud iam service-accounts add-iam-policy-binding \
  my-sa@PROJECT.iam.gserviceaccount.com \
  --member="user:developer@example.com" \
  --role="roles/iam.serviceAccountTokenCreator"

# Use impersonation
gcloud config set auth/impersonate_service_account my-sa@PROJECT.iam.gserviceaccount.com
```

For detailed authentication patterns including Workload Identity Federation,
see `references/authentication.md`.

## Workflow: IAM Permissions

### Grant Project-Level Roles

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:user@example.com" \
  --role="roles/viewer"
```

### Grant Resource-Level Roles

```bash
# Cloud Run service
gcloud run services add-iam-policy-binding SERVICE \
  --region=REGION \
  --member="serviceAccount:sa@PROJECT.iam.gserviceaccount.com" \
  --role="roles/run.invoker"

# Cloud Storage bucket
gcloud storage buckets add-iam-policy-binding gs://BUCKET \
  --member="serviceAccount:sa@PROJECT.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"
```

For complete IAM reference including custom roles, see `references/iam-permissions.md`.

## Workflow: Cloud Run Deployment

### Deploy from Source

```bash
gcloud run deploy SERVICE_NAME \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```

### Deploy from Container Image

```bash
# Configure Docker auth
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build and push
docker build -t us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE:TAG .
docker push us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE:TAG

# Deploy
gcloud run deploy SERVICE \
  --image us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE:TAG \
  --region us-central1 \
  --service-account=runtime-sa@PROJECT.iam.gserviceaccount.com
```

### Traffic Splitting (Canary Deployments)

```bash
# Deploy with no traffic
gcloud run deploy SERVICE --image IMAGE --no-traffic --tag canary

# Gradually shift traffic
gcloud run services update-traffic SERVICE --to-tags canary=10
gcloud run services update-traffic SERVICE --to-tags canary=50
gcloud run services update-traffic SERVICE --to-tags canary=100
```

For advanced deployment patterns, see `references/cloud-run-deployment.md`.

## Workflow: Cloud Scheduler

### Create HTTP Job

```bash
gcloud scheduler jobs create http JOB_NAME \
  --location=us-central1 \
  --schedule="0 * * * *" \
  --uri="https://SERVICE-URL/endpoint" \
  --http-method=POST \
  --oidc-service-account-email=scheduler-sa@PROJECT.iam.gserviceaccount.com
```

### Trigger Cloud Run Service

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe SERVICE --region REGION --format='value(status.url)')

# Create authenticated job
gcloud scheduler jobs create http trigger-job \
  --location=us-central1 \
  --schedule="0 2 * * *" \
  --uri="${SERVICE_URL}/task" \
  --oidc-service-account-email=scheduler-sa@PROJECT.iam.gserviceaccount.com \
  --oidc-token-audience="${SERVICE_URL}"
```

For scheduler configuration details, see `references/cloud-scheduler.md`.

## Workflow: Cloud Storage

### Bucket Operations

```bash
# Create bucket
gcloud storage buckets create gs://BUCKET --location=us-central1

# Upload files
gcloud storage cp local-file.txt gs://BUCKET/
gcloud storage cp -r ./directory gs://BUCKET/path/

# Download files
gcloud storage cp gs://BUCKET/file.txt ./local/

# List contents
gcloud storage ls gs://BUCKET/

# Set permissions
gcloud storage buckets add-iam-policy-binding gs://BUCKET \
  --member="allUsers" \
  --role="roles/storage.objectViewer"
```

For complete GCS operations, see `references/cloud-storage.md`.

## Workflow: AlloyDB

### Create Cluster and Instance

```bash
# Create cluster
gcloud alloydb clusters create CLUSTER \
  --region=us-central1 \
  --password=SECURE_PASSWORD \
  --network=default

# Create primary instance
gcloud alloydb instances create INSTANCE \
  --cluster=CLUSTER \
  --region=us-central1 \
  --instance-type=PRIMARY \
  --cpu-count=2
```

For AlloyDB management, see `references/alloydb-management.md`.

## Workflow: Firebase Integration

Firebase management requires both gcloud CLI and Firebase CLI:

```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login

# Deploy functions
firebase deploy --only functions

# Deploy hosting
firebase deploy --only hosting

# Deploy security rules
firebase deploy --only firestore:rules
```

For Firebase workflows, see `references/firebase-management.md`.

## Workflow: CI/CD Integration

### GitHub Actions with Service Account Key

```yaml
- uses: google-github-actions/auth@v2
  with:
    credentials_json: ${{ secrets.GCP_SA_KEY }}

- uses: google-github-actions/setup-gcloud@v2

- run: gcloud run deploy SERVICE --source . --region us-central1
```

### GitHub Actions with Workload Identity Federation (Recommended)

```yaml
permissions:
  contents: read
  id-token: write

- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
    service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```

### Cloud Build

```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'IMAGE_URL', '.']
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'IMAGE_URL']
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args: ['run', 'deploy', 'SERVICE', '--image', 'IMAGE_URL', '--region', 'REGION']
```

For complete CI/CD patterns, see `references/cicd-integration.md`.

## Workflow: Verify GCP Setup

Comprehensive verification of your GCP project configuration:

```bash
# Using the verification script
./scripts/verify-gcp-setup.sh --project-id my-project

# With verbose output
./scripts/verify-gcp-setup.sh --project-id my-project --verbose

# Set environment variable for convenience
export GCP_PROJECT_ID=my-project
./scripts/verify-gcp-setup.sh
```

The verification script checks:
- Prerequisites (gcloud, Docker, jq)
- Project existence and status
- Required API enablement
- Authentication status
- Workload Identity Federation
- Artifact Registry configuration

For verification patterns and customization, see `references/verification-patterns.md`.

## Workflow: Reset Authentication

Complete authentication reset when troubleshooting or switching environments:

```bash
# Basic reset (credentials only)
./scripts/reset-gcloud-auth.sh

# Full reset (credentials + configurations)
./scripts/reset-gcloud-auth.sh --full-reset

# Reset and set new project
./scripts/reset-gcloud-auth.sh --full-reset --project-id new-project
```

Quick manual reset:
```bash
# Revoke and re-authenticate
gcloud auth revoke --all
rm -f ~/.config/gcloud/application_default_credentials.json
gcloud auth login
gcloud auth application-default login
```

For complete reset procedures, see `references/authentication-reset.md`.

## Workflow: Switch Projects

Efficiently switch between multiple GCP projects:

```bash
# Switch to a project
./scripts/switch-gcloud-project.sh switch my-project

# Switch and update ADC
./scripts/switch-gcloud-project.sh switch my-project --adc

# Add a project to your configuration
./scripts/switch-gcloud-project.sh add my-project --region us-east1 --description "Production"

# List configured projects
./scripts/switch-gcloud-project.sh list

# Save current configuration
./scripts/switch-gcloud-project.sh save

# Show current status
./scripts/switch-gcloud-project.sh status
```

For multi-project management, see `references/multi-account-management.md`.

## Workflow: Enable Required APIs

Enable all APIs needed for a typical GCP application:

```bash
# Core APIs for Cloud Run deployment
gcloud services enable \
    cloudresourcemanager.googleapis.com \
    compute.googleapis.com \
    iam.googleapis.com \
    iamcredentials.googleapis.com \
    sts.googleapis.com \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    --project=PROJECT_ID

# Additional APIs for AI/ML
gcloud services enable \
    aiplatform.googleapis.com \
    storage.googleapis.com \
    --project=PROJECT_ID

# Verify enabled APIs
gcloud services list --enabled --project=PROJECT_ID
```

For a complete list of 20+ commonly needed APIs organized by category, see `references/api-enablement.md`.

## Common Troubleshooting

### Permission Errors

```bash
# Check active account and project
gcloud auth list
gcloud config get-value project

# Verify IAM permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --format='table(bindings.role)' \
  --filter="bindings.members:YOUR_EMAIL"
```

### Configuration Issues

```bash
# List and verify configurations
gcloud config configurations list
gcloud config list

# Reset to defaults
gcloud config configurations activate default

# Full reset if needed
./scripts/reset-gcloud-auth.sh --full-reset
```

### Docker Authentication Issues

```bash
# Re-authenticate
gcloud auth configure-docker REGION-docker.pkg.dev

# Verify with test pull
docker pull REGION-docker.pkg.dev/PROJECT/REPO/IMAGE
```

### Verify Complete Setup

```bash
# Run comprehensive verification
./scripts/verify-gcp-setup.sh --project-id PROJECT_ID --verbose

# Check success rate and fix any failures
```

## Reference Files

Detailed guides are available in the `references/` directory:

- `references/installation-macos.md` - Complete macOS installation guide
- `references/authentication.md` - All authentication methods and patterns
- `references/multi-account-management.md` - Configuration profiles and switching
- `references/iam-permissions.md` - IAM roles, custom roles, and policies
- `references/cloud-run-deployment.md` - Deployment patterns and traffic management
- `references/cloud-scheduler.md` - Scheduled job configuration
- `references/cloud-storage.md` - GCS bucket and object operations
- `references/alloydb-management.md` - AlloyDB cluster management
- `references/firebase-management.md` - Firebase CLI integration
- `references/cicd-integration.md` - GitHub Actions and Cloud Build pipelines
