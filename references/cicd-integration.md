# CI/CD Integration Guide

This guide covers integrating gcloud CLI with CI/CD pipelines, focusing on GitHub Actions,
Cloud Build, and Workload Identity Federation for secure, keyless authentication.

## Authentication Strategies

### Strategy Comparison

| Method | Security | Complexity | Use Case |
|--------|----------|------------|----------|
| Service Account Key | Medium | Low | Legacy systems |
| Workload Identity Federation | High | Medium | Modern CI/CD |
| Service Account Impersonation | High | Medium | Hybrid setups |

**Recommendation**: Use Workload Identity Federation for GitHub Actions to eliminate key management.

## GitHub Actions

### Basic Setup with Service Account Key

```yaml
name: Deploy to GCP

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy my-service \
            --source . \
            --region us-central1 \
            --project ${{ secrets.GCP_PROJECT_ID }} \
            --allow-unauthenticated
```

**Create the secret:**

```bash
# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions"

# Grant deployment permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-actions@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-actions@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

# Generate key
gcloud iam service-accounts keys create key.json \
  --iam-account=github-actions@PROJECT_ID.iam.gserviceaccount.com

# Add to GitHub secrets (base64 encoded)
cat key.json | base64
# Copy output to GitHub repository secrets as GCP_SA_KEY
```

### Workload Identity Federation (Recommended)

#### Step 1: Create Workload Identity Pool

```bash
# Create identity pool
gcloud iam workload-identity-pools create "github-pool" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Get pool name
gcloud iam workload-identity-pools describe "github-pool" \
  --location="global" \
  --format="value(name)"
```

#### Step 2: Create OIDC Provider

```bash
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --workload-identity-pool="github-pool" \
  --location="global" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == 'YOUR_GITHUB_ORG'"
```

#### Step 3: Create Service Account

```bash
# Create service account
gcloud iam service-accounts create github-deploy-sa \
  --display-name="GitHub Deploy SA"

# Grant necessary roles
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-deploy-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-deploy-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-deploy-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

#### Step 4: Grant Workload Identity Access

```bash
PROJECT_NUMBER=$(gcloud projects describe PROJECT_ID --format='value(projectNumber)')

# Grant specific repo access to impersonate SA
gcloud iam service-accounts add-iam-policy-binding \
  github-deploy-sa@PROJECT_ID.iam.gserviceaccount.com \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_GITHUB_ORG/YOUR_REPO" \
  --role="roles/iam.workloadIdentityUser"
```

#### Step 5: GitHub Actions Workflow

```yaml
name: Deploy with Workload Identity

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

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
          service_account: 'github-deploy-sa@PROJECT_ID.iam.gserviceaccount.com'

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy my-service \
            --source . \
            --region us-central1 \
            --quiet
```

### Multi-Environment Deployment

```yaml
name: Multi-Environment Deploy

on:
  push:
    branches:
      - develop
      - staging
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      id-token: write

    steps:
      - uses: actions/checkout@v4

      - name: Set environment
        id: env
        run: |
          if [[ $GITHUB_REF == 'refs/heads/main' ]]; then
            echo "environment=production" >> $GITHUB_OUTPUT
            echo "project=${{ secrets.PROD_PROJECT_ID }}" >> $GITHUB_OUTPUT
            echo "sa=${{ secrets.PROD_SERVICE_ACCOUNT }}" >> $GITHUB_OUTPUT
          elif [[ $GITHUB_REF == 'refs/heads/staging' ]]; then
            echo "environment=staging" >> $GITHUB_OUTPUT
            echo "project=${{ secrets.STAGING_PROJECT_ID }}" >> $GITHUB_OUTPUT
            echo "sa=${{ secrets.STAGING_SERVICE_ACCOUNT }}" >> $GITHUB_OUTPUT
          else
            echo "environment=development" >> $GITHUB_OUTPUT
            echo "project=${{ secrets.DEV_PROJECT_ID }}" >> $GITHUB_OUTPUT
            echo "sa=${{ secrets.DEV_SERVICE_ACCOUNT }}" >> $GITHUB_OUTPUT
          fi

      - name: Authenticate
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ steps.env.outputs.sa }}

      - name: Deploy
        run: |
          gcloud run deploy my-service-${{ steps.env.outputs.environment }} \
            --source . \
            --region us-central1 \
            --project ${{ steps.env.outputs.project }} \
            --quiet

      - name: Notify
        if: success()
        run: echo "Deployed to ${{ steps.env.outputs.environment }}"
```

### Docker Build and Deploy

```yaml
name: Build and Deploy

on:
  push:
    branches: [main]

env:
  PROJECT_ID: my-project
  REGION: us-central1
  SERVICE: my-service
  REPO: my-repo

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      id-token: write

    steps:
      - uses: actions/checkout@v4

      - name: Authenticate
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker
        run: gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev

      - name: Build image
        run: |
          docker build -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPO }}/${{ env.SERVICE }}:${{ github.sha }} .

      - name: Push image
        run: |
          docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPO }}/${{ env.SERVICE }}:${{ github.sha }}

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy ${{ env.SERVICE }} \
            --image ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPO }}/${{ env.SERVICE }}:${{ github.sha }} \
            --region ${{ env.REGION }} \
            --platform managed \
            --quiet
```

## Cloud Build

### Basic cloudbuild.yaml

```yaml
steps:
  # Build container
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - 'us-central1-docker.pkg.dev/$PROJECT_ID/my-repo/my-service:$COMMIT_SHA'
      - '.'

  # Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - 'us-central1-docker.pkg.dev/$PROJECT_ID/my-repo/my-service:$COMMIT_SHA'

  # Deploy to Cloud Run
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - 'run'
      - 'deploy'
      - 'my-service'
      - '--image=us-central1-docker.pkg.dev/$PROJECT_ID/my-repo/my-service:$COMMIT_SHA'
      - '--region=us-central1'
      - '--platform=managed'
      - '--quiet'

images:
  - 'us-central1-docker.pkg.dev/$PROJECT_ID/my-repo/my-service:$COMMIT_SHA'

options:
  logging: CLOUD_LOGGING_ONLY
```

### Cloud Build with Substitutions

```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_SERVICE}:$COMMIT_SHA'
      - '-t'
      - '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_SERVICE}:latest'
      - '.'

  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', '--all-tags', '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_SERVICE}']

  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - 'run'
      - 'deploy'
      - '${_SERVICE}'
      - '--image=${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_SERVICE}:$COMMIT_SHA'
      - '--region=${_REGION}'
      - '--service-account=${_RUNTIME_SA}'
      - '--quiet'

substitutions:
  _REGION: us-central1
  _REPO: my-repo
  _SERVICE: my-service
  _RUNTIME_SA: runtime-sa@PROJECT_ID.iam.gserviceaccount.com

images:
  - '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_SERVICE}'
```

### Create Cloud Build Trigger

```bash
# Connect repository
gcloud builds connections create github my-connection \
  --region=us-central1

# Create trigger from GitHub
gcloud builds triggers create github \
  --name="deploy-on-push" \
  --repo-name=my-repo \
  --repo-owner=my-github-org \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml \
  --region=us-central1

# Trigger with substitutions
gcloud builds triggers create github \
  --name="deploy-staging" \
  --repo-name=my-repo \
  --repo-owner=my-github-org \
  --branch-pattern="^staging$" \
  --build-config=cloudbuild.yaml \
  --region=us-central1 \
  --substitutions="_ENVIRONMENT=staging,_SERVICE=my-service-staging"
```

### Manual Build Submission

```bash
# Submit build
gcloud builds submit \
  --config cloudbuild.yaml \
  --region us-central1

# With substitutions
gcloud builds submit \
  --config cloudbuild.yaml \
  --region us-central1 \
  --substitutions="_SERVICE=my-service,_REGION=us-central1"

# Quick container build
gcloud builds submit \
  --tag us-central1-docker.pkg.dev/PROJECT_ID/my-repo/my-service:latest \
  --region us-central1
```

### Build ID Extraction and Monitoring

Extract Build ID for tracking and log retrieval:

```bash
# Submit and capture Build ID
BUILD_OUTPUT=$(gcloud builds submit \
  --config cloudbuild.yaml \
  --region us-central1 \
  --async \
  2>&1)

BUILD_ID=$(echo "$BUILD_OUTPUT" | grep -oE '[a-f0-9-]{36}' | head -1)
echo "Build ID: $BUILD_ID"

# Alternative: use --format flag
BUILD_ID=$(gcloud builds submit \
  --config cloudbuild.yaml \
  --region us-central1 \
  --async \
  --format='value(id)')
```

### Build Status Checking

```bash
# Check build status
check_build_status() {
    local build_id=$1
    local region=${2:-us-central1}

    gcloud builds describe "$build_id" \
        --region="$region" \
        --format='value(status)'
}

# Wait for build completion
wait_for_build() {
    local build_id=$1
    local region=${2:-us-central1}
    local timeout=${3:-1800}  # 30 minutes default

    echo "Waiting for build $build_id..."
    local start_time=$(date +%s)

    while true; do
        local status=$(check_build_status "$build_id" "$region")

        case "$status" in
            SUCCESS)
                echo "✅ Build succeeded!"
                return 0
                ;;
            FAILURE|TIMEOUT|CANCELLED)
                echo "❌ Build $status"
                return 1
                ;;
            WORKING|QUEUED)
                local elapsed=$(($(date +%s) - start_time))
                if [ $elapsed -gt $timeout ]; then
                    echo "⏰ Build timed out after ${timeout}s"
                    return 2
                fi
                echo "  Status: $status (${elapsed}s elapsed)"
                sleep 10
                ;;
            *)
                echo "  Unknown status: $status"
                sleep 10
                ;;
        esac
    done
}

# Usage
BUILD_ID="abc123-def456-789..."
wait_for_build "$BUILD_ID" "us-central1" 1800
```

### Build Log Retrieval

```bash
# Stream logs for running build
gcloud builds log "$BUILD_ID" --region us-central1 --stream

# Get logs after completion
gcloud builds log "$BUILD_ID" --region us-central1

# Get logs with timestamps
gcloud builds describe "$BUILD_ID" \
    --region us-central1 \
    --format='value(logUrl)'

# Tail recent logs
gcloud builds log "$BUILD_ID" \
    --region us-central1 \
    | tail -50

# Save logs to file
gcloud builds log "$BUILD_ID" \
    --region us-central1 \
    > "build-${BUILD_ID}.log" 2>&1
```

### Comprehensive Build Script

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project)}"
REGION="${GCP_REGION:-us-central1}"
CONFIG_FILE="${1:-cloudbuild.yaml}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Starting build..."
echo "  Project: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Config: $CONFIG_FILE"
echo

# Submit build and capture ID
BUILD_OUTPUT=$(gcloud builds submit \
    --config "$CONFIG_FILE" \
    --project "$PROJECT_ID" \
    --region "$REGION" \
    --async \
    2>&1)

BUILD_ID=$(echo "$BUILD_OUTPUT" | grep -oE '[a-f0-9-]{36}' | head -1)

if [ -z "$BUILD_ID" ]; then
    echo -e "${RED}Failed to extract Build ID${NC}"
    echo "$BUILD_OUTPUT"
    exit 1
fi

echo -e "${GREEN}Build submitted: $BUILD_ID${NC}"
echo

# Stream logs
echo "Streaming build logs..."
gcloud builds log "$BUILD_ID" --region "$REGION" --stream || true

# Check final status
FINAL_STATUS=$(gcloud builds describe "$BUILD_ID" \
    --region "$REGION" \
    --format='value(status)')

echo
if [ "$FINAL_STATUS" = "SUCCESS" ]; then
    echo -e "${GREEN}✅ Build completed successfully${NC}"
    exit 0
else
    echo -e "${RED}❌ Build failed with status: $FINAL_STATUS${NC}"
    echo "View full logs at:"
    gcloud builds describe "$BUILD_ID" \
        --region "$REGION" \
        --format='value(logUrl)'
    exit 1
fi
```

### Build History and Filtering

```bash
# List recent builds
gcloud builds list \
    --limit=10 \
    --region=us-central1 \
    --format='table(id,status,createTime,duration)'

# Filter by status
gcloud builds list \
    --filter="status=FAILURE" \
    --limit=5 \
    --region=us-central1

# Filter by trigger
gcloud builds list \
    --filter="buildTriggerId=TRIGGER_ID" \
    --limit=10 \
    --region=us-central1

# Get builds in date range
gcloud builds list \
    --filter="createTime>2024-01-01 AND createTime<2024-01-31" \
    --region=us-central1

# Format as JSON for scripting
gcloud builds list \
    --limit=5 \
    --region=us-central1 \
    --format=json
```

### Cloud Build Service Account Permissions

```bash
# Get Cloud Build service account
PROJECT_NUMBER=$(gcloud projects describe PROJECT_ID --format='value(projectNumber)')
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

# Grant Cloud Run Admin
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/run.admin"

# Grant Artifact Registry Writer
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/artifactregistry.writer"

# Grant Service Account User (for runtime SA)
gcloud iam service-accounts add-iam-policy-binding \
  runtime-sa@PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/iam.serviceAccountUser"
```

## Firebase CI/CD

### Firebase in GitHub Actions

```yaml
name: Deploy to Firebase

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        working-directory: ./functions
        run: npm ci

      - name: Deploy to Firebase
        uses: w9jds/firebase-action@master
        with:
          args: deploy --only functions,hosting
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

### Firebase in Cloud Build

```yaml
steps:
  # Install dependencies
  - name: 'node:20'
    dir: 'functions'
    entrypoint: npm
    args: ['ci']

  # Deploy to Firebase
  - name: 'us-docker.pkg.dev/firebase-cli/us/firebase'
    args:
      - 'deploy'
      - '--project=$PROJECT_ID'
      - '--only=functions,hosting'
    env:
      - 'FIREBASE_TOKEN=${_FIREBASE_TOKEN}'

substitutions:
  _FIREBASE_TOKEN: ''  # Set via trigger or --substitutions
```

## Testing in CI/CD

### Run Tests Before Deploy

```yaml
name: Test and Deploy

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm test

  deploy:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
      - uses: google-github-actions/setup-gcloud@v2
      - run: gcloud run deploy my-service --source . --region us-central1 --quiet
```

## Secrets Management

### Using Secret Manager in CI/CD

```yaml
steps:
  - name: Authenticate
    uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
      service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

  - name: Get secrets
    id: secrets
    run: |
      API_KEY=$(gcloud secrets versions access latest --secret="api-key")
      echo "::add-mask::$API_KEY"
      echo "api_key=$API_KEY" >> $GITHUB_OUTPUT

  - name: Use secret
    run: |
      curl -H "Authorization: Bearer ${{ steps.secrets.outputs.api_key }}" https://api.example.com
```

## Best Practices

### 1. Use Workload Identity Federation

Eliminate service account keys for better security.

### 2. Principle of Least Privilege

Grant only necessary permissions to CI/CD service accounts.

### 3. Separate Environments

Use different service accounts and projects for dev/staging/prod.

### 4. Audit and Monitor

```bash
# View build history
gcloud builds list --limit=10

# View Cloud Run deployments
gcloud run revisions list --service=my-service --region=us-central1
```

### 5. Use Secrets Properly

Never commit secrets. Use GitHub Secrets or Secret Manager.

### 6. Version Control Your CI/CD

Keep all pipeline configurations in version control.

## Troubleshooting

### Authentication Failures

```bash
# Verify WIF setup
gcloud iam workload-identity-pools providers describe github-provider \
  --workload-identity-pool=github-pool \
  --location=global

# Check service account IAM
gcloud iam service-accounts get-iam-policy \
  github-deploy-sa@PROJECT_ID.iam.gserviceaccount.com
```

### Build Failures

```bash
# View build logs
gcloud builds log BUILD_ID

# List recent builds
gcloud builds list --limit=5 --region=us-central1
```

### Deployment Failures

```bash
# Check Cloud Run logs
gcloud run services logs read my-service --region=us-central1 --limit=50

# Check revision status
gcloud run revisions list --service=my-service --region=us-central1
```
