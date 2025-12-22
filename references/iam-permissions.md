# IAM Roles and Permissions

This guide covers Identity and Access Management (IAM) for Google Cloud, including predefined roles,
custom roles, and policy management via gcloud CLI.

## IAM Fundamentals

### Core Concepts

- **Principal**: Who (user, group, service account, domain)
- **Role**: What permissions (collection of permissions)
- **Resource**: Where (project, bucket, service, etc.)
- **Binding**: Links principal to role on resource
- **Policy**: Collection of bindings for a resource

### Principal Types

| Type | Format | Example |
|------|--------|---------|
| User | `user:EMAIL` | `user:admin@example.com` |
| Service Account | `serviceAccount:EMAIL` | `serviceAccount:sa@proj.iam.gserviceaccount.com` |
| Group | `group:EMAIL` | `group:devs@example.com` |
| Domain | `domain:DOMAIN` | `domain:example.com` |
| All Users | `allUsers` | Public access |
| All Authenticated | `allAuthenticatedUsers` | Any Google account |

## Role Types

### Basic Roles (Legacy - Avoid in Production)

```bash
roles/viewer     # Read access to all resources
roles/editor     # Read/write to most resources
roles/owner      # Full access including IAM management
```

**Warning**: Basic roles are overly permissive. Use predefined or custom roles instead.

### Predefined Roles (Recommended)

Service-specific roles following least privilege:

```bash
# Compute Engine
roles/compute.instanceAdmin.v1
roles/compute.networkAdmin

# Cloud Run
roles/run.admin
roles/run.developer
roles/run.invoker

# Cloud Storage
roles/storage.admin
roles/storage.objectAdmin
roles/storage.objectViewer
roles/storage.objectCreator

# Cloud SQL / AlloyDB
roles/cloudsql.admin
roles/cloudsql.client
roles/alloydb.admin

# Pub/Sub
roles/pubsub.admin
roles/pubsub.publisher
roles/pubsub.subscriber

# Secret Manager
roles/secretmanager.admin
roles/secretmanager.secretAccessor

# IAM
roles/iam.serviceAccountAdmin
roles/iam.serviceAccountUser
roles/iam.serviceAccountTokenCreator
```

### Custom Roles

Create roles with specific permissions:

```bash
# Create from scratch
gcloud iam roles create customBucketViewer \
  --project=PROJECT_ID \
  --title="Bucket Viewer" \
  --description="View buckets and objects only" \
  --permissions="storage.buckets.get,storage.buckets.list,storage.objects.get,storage.objects.list" \
  --stage=GA

# Create from YAML file
gcloud iam roles create customRole \
  --project=PROJECT_ID \
  --file=role-definition.yaml
```

Example `role-definition.yaml`:

```yaml
title: "Custom Deployer"
description: "Deploy to Cloud Run without admin access"
stage: "GA"
includedPermissions:
  - run.services.create
  - run.services.update
  - run.services.get
  - run.services.list
  - run.revisions.get
  - run.revisions.list
```

## Granting Permissions

### Project-Level Bindings

```bash
# Grant role to user
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:developer@example.com" \
  --role="roles/viewer"

# Grant role to service account
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:my-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

# Grant role to group
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="group:developers@example.com" \
  --role="roles/editor"

# Grant multiple roles
for role in roles/run.developer roles/storage.objectViewer roles/logging.viewer; do
  gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="user:dev@example.com" \
    --role="$role"
done
```

### Resource-Level Bindings

```bash
# Cloud Run service
gcloud run services add-iam-policy-binding SERVICE_NAME \
  --region=REGION \
  --member="serviceAccount:invoker@PROJECT.iam.gserviceaccount.com" \
  --role="roles/run.invoker"

# Cloud Storage bucket
gcloud storage buckets add-iam-policy-binding gs://BUCKET \
  --member="user:analyst@example.com" \
  --role="roles/storage.objectViewer"

# Pub/Sub topic
gcloud pubsub topics add-iam-policy-binding TOPIC \
  --member="serviceAccount:publisher@PROJECT.iam.gserviceaccount.com" \
  --role="roles/pubsub.publisher"

# Secret Manager secret
gcloud secrets add-iam-policy-binding SECRET_NAME \
  --member="serviceAccount:app@PROJECT.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Public Access

```bash
# Make Cloud Run service public
gcloud run services add-iam-policy-binding SERVICE \
  --region=REGION \
  --member="allUsers" \
  --role="roles/run.invoker"

# Make GCS bucket public (read-only)
gcloud storage buckets add-iam-policy-binding gs://BUCKET \
  --member="allUsers" \
  --role="roles/storage.objectViewer"
```

## Removing Permissions

```bash
# Remove project-level binding
gcloud projects remove-iam-policy-binding PROJECT_ID \
  --member="user:former-employee@example.com" \
  --role="roles/editor"

# Remove service-level binding
gcloud run services remove-iam-policy-binding SERVICE \
  --region=REGION \
  --member="allUsers" \
  --role="roles/run.invoker"
```

## Viewing Permissions

### View Project IAM Policy

```bash
# Full policy
gcloud projects get-iam-policy PROJECT_ID

# Formatted table
gcloud projects get-iam-policy PROJECT_ID \
  --format='table(bindings.role,bindings.members)'

# Filter by member
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --format='table(bindings.role)' \
  --filter="bindings.members:user@example.com"
```

### View Resource IAM Policy

```bash
# Cloud Run
gcloud run services get-iam-policy SERVICE --region=REGION

# Cloud Storage
gcloud storage buckets get-iam-policy gs://BUCKET

# Pub/Sub
gcloud pubsub topics get-iam-policy TOPIC
```

### Check Permissions

```bash
# Test if user can perform actions
gcloud asset analyze-iam-policy \
  --organization=ORG_ID \
  --identity="user:developer@example.com" \
  --full-resource-name="//cloudresourcemanager.googleapis.com/projects/PROJECT_ID"
```

## Service Account Management

### Create Service Account

```bash
gcloud iam service-accounts create my-app-sa \
  --display-name="My Application SA" \
  --description="Service account for production app"
```

### Grant Roles to Service Account

```bash
# Project-level roles
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:my-app-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/datastore.user"

# Resource-level roles
gcloud storage buckets add-iam-policy-binding gs://BUCKET \
  --member="serviceAccount:my-app-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"
```

### Service Account User Role

Required when deploying resources that run as a service account:

```bash
# Allow user to deploy Cloud Run with specific SA
gcloud iam service-accounts add-iam-policy-binding \
  runtime-sa@PROJECT_ID.iam.gserviceaccount.com \
  --member="user:deployer@example.com" \
  --role="roles/iam.serviceAccountUser"
```

### Service Account Token Creator

Required for impersonation:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  target-sa@PROJECT_ID.iam.gserviceaccount.com \
  --member="user:developer@example.com" \
  --role="roles/iam.serviceAccountTokenCreator"
```

## Common Role Patterns

### Developer Access

```bash
# Cloud Run developer
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:dev@example.com" \
  --role="roles/run.developer"

gcloud iam service-accounts add-iam-policy-binding \
  runtime-sa@PROJECT_ID.iam.gserviceaccount.com \
  --member="user:dev@example.com" \
  --role="roles/iam.serviceAccountUser"
```

### CI/CD Pipeline

```bash
# Service account for CI/CD
SA_EMAIL="ci-cd-sa@PROJECT_ID.iam.gserviceaccount.com"

# Deployment permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/artifactregistry.writer"

# Use service accounts for runtime
gcloud iam service-accounts add-iam-policy-binding \
  runtime-sa@PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.serviceAccountUser"
```

### Read-Only Analyst

```bash
# View resources only
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:analyst@example.com" \
  --role="roles/viewer"

# View storage objects
gcloud storage buckets add-iam-policy-binding gs://DATA_BUCKET \
  --member="user:analyst@example.com" \
  --role="roles/storage.objectViewer"
```

## Conditional IAM

Add conditions to bindings:

```bash
# Time-based access
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:contractor@example.com" \
  --role="roles/editor" \
  --condition="expression=request.time < timestamp('2024-12-31T23:59:59Z'),title=Temporary access,description=Access until end of 2024"

# Resource-based condition
gcloud storage buckets add-iam-policy-binding gs://BUCKET \
  --member="user:dev@example.com" \
  --role="roles/storage.objectAdmin" \
  --condition="expression=resource.name.startsWith('projects/_/buckets/BUCKET/objects/dev/'),title=Dev folder only"
```

## Best Practices

1. **Use predefined roles** over basic roles
2. **Grant at lowest resource level** (service > project > folder > org)
3. **Use groups** for team access instead of individual users
4. **Regular audits** of IAM policies
5. **Least privilege** - only grant what's needed
6. **Use conditions** for time-limited or scoped access
7. **Document role assignments** with descriptions
8. **Separate production service accounts** from development

## Troubleshooting

### Permission Denied Errors

```bash
# Check who has what role
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:ACCOUNT_EMAIL"

# Test specific permission
gcloud projects get-iam-policy PROJECT_ID --format=json | \
  jq '.bindings[] | select(.role=="roles/run.admin")'
```

### Role Not Found

```bash
# List available roles
gcloud iam roles list --filter="name:run"

# Describe specific role
gcloud iam roles describe roles/run.admin
```
