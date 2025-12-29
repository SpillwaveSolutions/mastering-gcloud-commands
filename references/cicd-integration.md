# CI/CD Integration Guide

This guide covers integrating gcloud CLI with CI/CD pipelines, focusing on GitHub Actions,
Cloud Build, and Workload Identity Federation for secure, keyless authentication.

## Contents

- [Authentication Strategies](#authentication-strategies)
- [GitHub Actions](#github-actions)
- [Cloud Build](#cloud-build)
- [Firebase CI/CD](#firebase-cicd)
- [Testing in CI/CD](#testing-in-cicd)
- [Secrets Management](#secrets-management)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Authentication Strategies

| Method | Security | Complexity | Use Case |
|--------|----------|------------|----------|
| Service Account Key | Medium | Low | Legacy systems |
| Workload Identity Federation | High | Medium | Modern CI/CD |
| Service Account Impersonation | High | Medium | Hybrid setups |

**Recommendation**: Workload Identity Federation eliminates key management for GitHub Actions.

## GitHub Actions

### Base Workflow Template

All GitHub Actions workflows share this structure:

```yaml
name: GCP Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write  # Required for WIF

    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
      - uses: google-github-actions/setup-gcloud@v2
      - run: gcloud run deploy my-service --source . --region us-central1 --quiet
```

**Variations:**
- **SA Key Auth**: Replace `workload_identity_provider`/`service_account` with `credentials_json: ${{ secrets.GCP_SA_KEY }}`
- **Multi-env**: Add environment detection step (see Multi-Environment section below)
- **Docker build**: Add docker build/push steps before deploy

### Workload Identity Federation Setup

WIF setup involves creating an identity pool, OIDC provider, and granting access:

```bash
# 1. Create identity pool
gcloud iam workload-identity-pools create "github-pool" \
  --location="global" --display-name="GitHub Actions Pool"

# 2. Create OIDC provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --workload-identity-pool="github-pool" --location="global" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == 'YOUR_GITHUB_ORG'"

# 3. Create and configure service account
gcloud iam service-accounts create github-deploy-sa --display-name="GitHub Deploy SA"

# Grant required roles (run.admin, artifactregistry.writer, iam.serviceAccountUser)
for role in roles/run.admin roles/artifactregistry.writer roles/iam.serviceAccountUser; do
  gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:github-deploy-sa@PROJECT_ID.iam.gserviceaccount.com" \
    --role="$role"
done

# 4. Grant WIF access
PROJECT_NUMBER=$(gcloud projects describe PROJECT_ID --format='value(projectNumber)')
gcloud iam service-accounts add-iam-policy-binding \
  github-deploy-sa@PROJECT_ID.iam.gserviceaccount.com \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_ORG/YOUR_REPO" \
  --role="roles/iam.workloadIdentityUser"
```

### Multi-Environment Deployment

Add environment detection before the auth step:

```yaml
- name: Set environment
  id: env
  run: |
    case $GITHUB_REF in
      refs/heads/main)    ENV=production; PROJECT=${{ secrets.PROD_PROJECT_ID }};;
      refs/heads/staging) ENV=staging; PROJECT=${{ secrets.STAGING_PROJECT_ID }};;
      *)                  ENV=development; PROJECT=${{ secrets.DEV_PROJECT_ID }};;
    esac
    echo "environment=$ENV" >> $GITHUB_OUTPUT
    echo "project=$PROJECT" >> $GITHUB_OUTPUT

- name: Deploy
  run: gcloud run deploy my-service-${{ steps.env.outputs.environment }} --source . --region us-central1 --project ${{ steps.env.outputs.project }} --quiet
```

### Docker Build and Deploy

For container-based deployments, add these steps after auth:

```yaml
env:
  IMAGE: ${{ vars.REGION }}-docker.pkg.dev/${{ vars.PROJECT_ID }}/${{ vars.REPO }}/${{ vars.SERVICE }}:${{ github.sha }}

steps:
  # ... auth steps ...
  - run: gcloud auth configure-docker ${{ vars.REGION }}-docker.pkg.dev
  - run: docker build -t ${{ env.IMAGE }} .
  - run: docker push ${{ env.IMAGE }}
  - run: gcloud run deploy ${{ vars.SERVICE }} --image ${{ env.IMAGE }} --region ${{ vars.REGION }} --quiet
```

## Cloud Build

### cloudbuild.yaml Template

Base template with substitution variables for reusability:

```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_SERVICE}:$COMMIT_SHA', '.']
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_SERVICE}:$COMMIT_SHA']
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args: ['run', 'deploy', '${_SERVICE}', '--image=${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_SERVICE}:$COMMIT_SHA', '--region=${_REGION}', '--quiet']

substitutions:
  _REGION: us-central1
  _REPO: my-repo
  _SERVICE: my-service

options:
  logging: CLOUD_LOGGING_ONLY
```

### Build Triggers and Submission

```bash
# Create GitHub trigger
gcloud builds triggers create github \
  --name="deploy-on-push" --repo-name=my-repo --repo-owner=my-org \
  --branch-pattern="^main$" --build-config=cloudbuild.yaml --region=us-central1

# Manual submission
gcloud builds submit --config cloudbuild.yaml --region us-central1

# Quick container build (no cloudbuild.yaml needed)
gcloud builds submit --tag us-central1-docker.pkg.dev/PROJECT_ID/my-repo/my-service:latest
```

### Build Monitoring

```bash
# Submit async and capture ID
BUILD_ID=$(gcloud builds submit --config cloudbuild.yaml --region us-central1 --async --format='value(id)')

# Stream logs
gcloud builds log "$BUILD_ID" --region us-central1 --stream

# Check status
gcloud builds describe "$BUILD_ID" --region us-central1 --format='value(status)'

# List recent builds
gcloud builds list --limit=10 --region=us-central1 --format='table(id,status,createTime,duration)'
```

### Cloud Build Service Account Setup

```bash
PROJECT_NUMBER=$(gcloud projects describe PROJECT_ID --format='value(projectNumber)')
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

# Grant required roles
for role in roles/run.admin roles/artifactregistry.writer; do
  gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:${CB_SA}" --role="$role"
done

# Grant SA impersonation for runtime SA
gcloud iam service-accounts add-iam-policy-binding runtime-sa@PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:${CB_SA}" --role="roles/iam.serviceAccountUser"
```

## Firebase CI/CD

### Firebase Deployment

**GitHub Actions:**
```yaml
- uses: w9jds/firebase-action@master
  with:
    args: deploy --only functions,hosting
  env:
    FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

**Cloud Build:**
```yaml
steps:
  - name: 'node:20'
    dir: 'functions'
    entrypoint: npm
    args: ['ci']
  - name: 'us-docker.pkg.dev/firebase-cli/us/firebase'
    args: ['deploy', '--project=$PROJECT_ID', '--only=functions,hosting']
    env: ['FIREBASE_TOKEN=${_FIREBASE_TOKEN}']
```

## Testing in CI/CD

Add a `test` job that runs before `deploy`:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm test

  deploy:
    needs: test
    # ... deploy steps ...
```

## Secrets Management

Retrieve secrets from Secret Manager in workflows:

```yaml
- name: Get secrets
  run: |
    API_KEY=$(gcloud secrets versions access latest --secret="api-key")
    echo "::add-mask::$API_KEY"
    echo "api_key=$API_KEY" >> $GITHUB_OUTPUT
```

## Best Practices

| Practice | Description |
|----------|-------------|
| Use WIF | Eliminate service account keys for better security |
| Least Privilege | Grant only necessary permissions to CI/CD service accounts |
| Separate Environments | Use different service accounts and projects for dev/staging/prod |
| Version Control | Keep all pipeline configurations in version control |
| Secret Manager | Never commit secrets; use GitHub Secrets or Secret Manager |

## Troubleshooting

```bash
# Verify WIF setup
gcloud iam workload-identity-pools providers describe github-provider \
  --workload-identity-pool=github-pool --location=global

# Check SA IAM
gcloud iam service-accounts get-iam-policy github-deploy-sa@PROJECT_ID.iam.gserviceaccount.com

# View build logs
gcloud builds log BUILD_ID --region us-central1

# Check Cloud Run logs
gcloud run services logs read my-service --region=us-central1 --limit=50
```
