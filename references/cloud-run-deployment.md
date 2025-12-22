# Cloud Run Deployment Guide

This guide covers deploying containerized applications to Cloud Run, including source deployments,
container image deployments, traffic management, and security configuration.

## Prerequisites

Enable required APIs:

```bash
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com
```

## Deployment Methods

### Method 1: Deploy from Source Code

Cloud Run builds the container automatically using Cloud Build and Buildpacks:

```bash
# Basic source deployment
gcloud run deploy SERVICE_NAME \
  --source . \
  --region us-central1 \
  --platform managed

# With options
gcloud run deploy my-api \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1 \
  --timeout 300s \
  --max-instances 10 \
  --min-instances 0
```

The `--source .` flag:
1. Detects language/framework automatically
2. Builds container using Google Buildpacks
3. Pushes to Artifact Registry (creates `cloud-run-source-deploy` repo)
4. Deploys to Cloud Run

### Method 2: Deploy from Container Image

For more control, build and push images separately:

```bash
# 1. Create Artifact Registry repository
gcloud artifacts repositories create my-repo \
  --repository-format=docker \
  --location=us-central1 \
  --description="Container images"

# 2. Configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# 3. Build and push
docker build -t us-central1-docker.pkg.dev/PROJECT_ID/my-repo/my-service:v1 .
docker push us-central1-docker.pkg.dev/PROJECT_ID/my-repo/my-service:v1

# 4. Deploy
gcloud run deploy my-service \
  --image us-central1-docker.pkg.dev/PROJECT_ID/my-repo/my-service:v1 \
  --region us-central1
```

### Method 3: Cloud Build Submission

Build with Cloud Build, then deploy:

```bash
# Build and push with Cloud Build
gcloud builds submit --tag us-central1-docker.pkg.dev/PROJECT_ID/my-repo/my-service:$COMMIT_SHA .

# Deploy the built image
gcloud run deploy my-service \
  --image us-central1-docker.pkg.dev/PROJECT_ID/my-repo/my-service:$COMMIT_SHA \
  --region us-central1
```

## Deployment Configuration

### Resource Allocation

```bash
gcloud run deploy my-service \
  --image IMAGE \
  --region us-central1 \
  --memory 1Gi \           # Memory: 128Mi to 32Gi
  --cpu 2 \                # CPU: 1, 2, 4, 6, 8
  --concurrency 80 \       # Max concurrent requests per instance
  --timeout 300s \         # Request timeout (max 3600s)
  --max-instances 100 \    # Maximum auto-scaling
  --min-instances 1        # Keep warm instances (costs apply)
```

### Environment Variables

```bash
# Set environment variables
gcloud run deploy my-service \
  --image IMAGE \
  --set-env-vars="DATABASE_URL=postgres://...,API_KEY=abc123,DEBUG=false"

# Update existing service
gcloud run services update my-service \
  --update-env-vars="NEW_VAR=value"

# Remove environment variable
gcloud run services update my-service \
  --remove-env-vars="OLD_VAR"
```

### Secret Integration

```bash
# Create secret
echo -n "secret-value" | gcloud secrets create my-secret --data-file=-

# Mount as environment variable
gcloud run deploy my-service \
  --image IMAGE \
  --set-secrets="DB_PASSWORD=my-secret:latest"

# Mount as file
gcloud run deploy my-service \
  --image IMAGE \
  --set-secrets="/secrets/api-key=api-key-secret:latest"
```

### Service Account

```bash
# Create runtime service account
gcloud iam service-accounts create cloud-run-sa \
  --display-name="Cloud Run Runtime SA"

# Grant necessary permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:cloud-run-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/datastore.user"

# Deploy with custom service account
gcloud run deploy my-service \
  --image IMAGE \
  --service-account=cloud-run-sa@PROJECT_ID.iam.gserviceaccount.com
```

### VPC Connectivity

```bash
# Create VPC connector
gcloud compute networks vpc-access connectors create my-connector \
  --region us-central1 \
  --network default \
  --range 10.8.0.0/28

# Deploy with VPC access
gcloud run deploy my-service \
  --image IMAGE \
  --vpc-connector my-connector \
  --vpc-egress all-traffic  # or private-ranges-only
```

## Traffic Management

### Revisions and Tags

```bash
# Deploy new revision without traffic
gcloud run deploy my-service \
  --image NEW_IMAGE \
  --no-traffic \
  --tag canary

# Tagged revision URL: https://canary---my-service-HASH.a.run.app

# List revisions
gcloud run revisions list --service my-service --region us-central1
```

### Traffic Splitting

```bash
# Route percentage to tagged revision
gcloud run services update-traffic my-service \
  --region us-central1 \
  --to-tags canary=10

# Increase canary traffic
gcloud run services update-traffic my-service \
  --region us-central1 \
  --to-tags canary=50

# Full rollout
gcloud run services update-traffic my-service \
  --region us-central1 \
  --to-tags canary=100

# Route to latest revision
gcloud run services update-traffic my-service \
  --region us-central1 \
  --to-latest
```

### Blue-Green Deployment

```bash
# Deploy green version with no traffic
gcloud run deploy my-service \
  --image NEW_IMAGE \
  --no-traffic \
  --tag green

# Test green at tagged URL
curl https://green---my-service-HASH.a.run.app

# Switch all traffic to green
gcloud run services update-traffic my-service \
  --region us-central1 \
  --to-tags green=100
```

### Rollback

```bash
# Get previous revision name
gcloud run revisions list \
  --service my-service \
  --region us-central1 \
  --format='value(REVISION)' \
  --sort-by=~metadata.creationTimestamp \
  --limit=5

# Route traffic to specific revision
gcloud run services update-traffic my-service \
  --region us-central1 \
  --to-revisions=my-service-00005-abc=100
```

## Authentication and Security

### Public Access

```bash
# Allow unauthenticated access during deployment
gcloud run deploy my-service \
  --image IMAGE \
  --allow-unauthenticated

# Or add IAM binding afterward
gcloud run services add-iam-policy-binding my-service \
  --region us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"
```

### Authenticated Access Only

```bash
# Deploy with auth required (default)
gcloud run deploy my-service \
  --image IMAGE \
  --no-allow-unauthenticated

# Grant access to specific principals
gcloud run services add-iam-policy-binding my-service \
  --region us-central1 \
  --member="serviceAccount:invoker@PROJECT.iam.gserviceaccount.com" \
  --role="roles/run.invoker"

gcloud run services add-iam-policy-binding my-service \
  --region us-central1 \
  --member="user:developer@example.com" \
  --role="roles/run.invoker"
```

### Invoking Authenticated Services

```bash
# Get identity token
TOKEN=$(gcloud auth print-identity-token)

# Call service
curl -H "Authorization: Bearer $TOKEN" https://my-service-HASH.a.run.app

# For service-to-service calls, use service account
gcloud run services add-iam-policy-binding target-service \
  --region us-central1 \
  --member="serviceAccount:caller-sa@PROJECT.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
```

## Managing Services

### List Services

```bash
gcloud run services list --region us-central1

# All regions
gcloud run services list --platform managed
```

### Describe Service

```bash
gcloud run services describe my-service \
  --region us-central1 \
  --format yaml
```

### Update Service

```bash
gcloud run services update my-service \
  --region us-central1 \
  --memory 1Gi \
  --update-env-vars="NEW_VAR=value"
```

### Delete Service

```bash
gcloud run services delete my-service --region us-central1
```

### View Logs

```bash
# Recent logs
gcloud run services logs read my-service --region us-central1 --limit 50

# Follow logs
gcloud run services logs tail my-service --region us-central1

# Filtered logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=my-service" --limit 100
```

## Cloud Run Jobs

For run-to-completion workloads:

```bash
# Create job
gcloud run jobs create my-job \
  --image IMAGE \
  --region us-central1 \
  --memory 2Gi \
  --cpu 2 \
  --task-timeout 3600s \
  --max-retries 3

# Execute job
gcloud run jobs execute my-job --region us-central1

# Execute and wait
gcloud run jobs execute my-job --region us-central1 --wait

# List executions
gcloud run jobs executions list --job my-job --region us-central1
```

## Required IAM Roles

### For Deployment

```bash
# Cloud Run Admin (full control)
roles/run.admin

# Cloud Run Developer (deploy/update)
roles/run.developer

# Plus Artifact Registry access
roles/artifactregistry.reader

# Plus Service Account User (if using custom SA)
roles/iam.serviceAccountUser
```

### Grant Deployment Permissions

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:deployer@example.com" \
  --role="roles/run.developer"

gcloud iam service-accounts add-iam-policy-binding \
  runtime-sa@PROJECT_ID.iam.gserviceaccount.com \
  --member="user:deployer@example.com" \
  --role="roles/iam.serviceAccountUser"
```

## Troubleshooting

### Deployment Failures

```bash
# Check build logs
gcloud builds list --limit 5
gcloud builds log BUILD_ID

# Check service status
gcloud run services describe my-service --region us-central1

# Check revision status
gcloud run revisions describe REVISION --region us-central1
```

### Container Startup Issues

```bash
# Check logs for startup errors
gcloud run services logs read my-service --region us-central1 --limit 100

# Verify container runs locally
docker run -p 8080:8080 IMAGE
```

### Permission Errors

```bash
# Verify active account
gcloud auth list

# Check IAM bindings
gcloud run services get-iam-policy my-service --region us-central1
```
