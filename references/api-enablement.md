# GCP API Enablement Guide

This guide covers enabling and managing GCP APIs, including a comprehensive list of
commonly required APIs organized by category.

## API Management Basics

### Enable a Single API

```bash
gcloud services enable API_NAME --project=PROJECT_ID
```

### Enable Multiple APIs

```bash
gcloud services enable \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    --project=PROJECT_ID
```

### List Enabled APIs

```bash
# All enabled APIs
gcloud services list --enabled --project=PROJECT_ID

# Filter by pattern
gcloud services list --enabled \
    --filter="name:(*aiplatform* OR *run* OR *artifactregistry*)" \
    --project=PROJECT_ID
```

### Check if API is Enabled

```bash
if gcloud services list --enabled \
    --filter="name:run.googleapis.com" \
    --format="value(name)" \
    --project=PROJECT_ID | grep -q .; then
    echo "API is enabled"
else
    echo "API is not enabled"
fi
```

## Comprehensive API List by Category

### Core Infrastructure APIs

Essential APIs for any GCP project:

```bash
CORE_APIS=(
    "cloudresourcemanager.googleapis.com"  # Project and resource management
    "compute.googleapis.com"               # VPC, networks, VMs, load balancers
    "iam.googleapis.com"                   # Identity and Access Management
    "iamcredentials.googleapis.com"        # Service Account Credentials API
    "sts.googleapis.com"                   # Security Token Service (for WIF)
    "serviceusage.googleapis.com"          # Service usage and quotas
)
```

### Container & Deployment APIs

For containerized application deployments:

```bash
CONTAINER_APIS=(
    "run.googleapis.com"                   # Cloud Run (serverless containers)
    "cloudbuild.googleapis.com"            # Cloud Build (CI/CD)
    "artifactregistry.googleapis.com"      # Artifact Registry (container images)
    "containerregistry.googleapis.com"     # Legacy Container Registry
    "container.googleapis.com"             # Google Kubernetes Engine (GKE)
)
```

### Data & Storage APIs

For data persistence and storage:

```bash
DATA_APIS=(
    "storage.googleapis.com"               # Cloud Storage (GCS buckets)
    "sqladmin.googleapis.com"              # Cloud SQL / AlloyDB admin
    "alloydb.googleapis.com"               # AlloyDB for PostgreSQL
    "redis.googleapis.com"                 # Memorystore for Redis
    "firestore.googleapis.com"             # Firestore database
    "bigtable.googleapis.com"              # Cloud Bigtable
    "spanner.googleapis.com"               # Cloud Spanner
)
```

### AI/ML APIs

For AI and machine learning workloads:

```bash
AI_APIS=(
    "aiplatform.googleapis.com"            # Vertex AI
    "ml.googleapis.com"                    # AI Platform (legacy)
    "vision.googleapis.com"                # Cloud Vision API
    "language.googleapis.com"              # Natural Language API
    "translate.googleapis.com"             # Cloud Translation API
    "speech.googleapis.com"                # Speech-to-Text API
    "texttospeech.googleapis.com"          # Text-to-Speech API
)
```

### Monitoring & Operations APIs

For observability and operations:

```bash
OPERATIONS_APIS=(
    "logging.googleapis.com"               # Cloud Logging
    "monitoring.googleapis.com"            # Cloud Monitoring
    "cloudtrace.googleapis.com"            # Cloud Trace
    "cloudprofiler.googleapis.com"         # Cloud Profiler
    "clouderrorreporting.googleapis.com"   # Error Reporting
    "cloudscheduler.googleapis.com"        # Cloud Scheduler (cron jobs)
    "cloudtasks.googleapis.com"            # Cloud Tasks (async tasks)
)
```

### Security APIs

For security and secrets management:

```bash
SECURITY_APIS=(
    "secretmanager.googleapis.com"         # Secret Manager
    "cloudkms.googleapis.com"              # Cloud Key Management Service
    "iap.googleapis.com"                   # Identity-Aware Proxy
    "certificatemanager.googleapis.com"    # Certificate Manager
    "securitycenter.googleapis.com"        # Security Command Center
)
```

### Networking APIs

For advanced networking:

```bash
NETWORKING_APIS=(
    "servicenetworking.googleapis.com"     # Service Networking (VPC peering)
    "vpcaccess.googleapis.com"             # Serverless VPC Access
    "dns.googleapis.com"                   # Cloud DNS
    "networkconnectivity.googleapis.com"   # Network Connectivity Center
)
```

## Common Application Profiles

### Web Application (Cloud Run)

APIs for a typical Cloud Run web application:

```bash
WEB_APP_APIS=(
    "run.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
    "iam.googleapis.com"
    "iamcredentials.googleapis.com"
    "sts.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
    "secretmanager.googleapis.com"
)
```

### Full-Stack Application with Database

APIs for a complete application with database and AI:

```bash
FULLSTACK_APIS=(
    # Core
    "cloudresourcemanager.googleapis.com"
    "compute.googleapis.com"
    "iam.googleapis.com"
    "iamcredentials.googleapis.com"
    "sts.googleapis.com"
    "serviceusage.googleapis.com"
    # Deployment
    "run.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
    # Data
    "sqladmin.googleapis.com"
    "storage.googleapis.com"
    "redis.googleapis.com"
    # AI
    "aiplatform.googleapis.com"
    # Operations
    "logging.googleapis.com"
    "monitoring.googleapis.com"
    "cloudtrace.googleapis.com"
    "cloudscheduler.googleapis.com"
    # Security
    "secretmanager.googleapis.com"
    "cloudkms.googleapis.com"
)
```

## Batch Enable Script

Complete script for enabling APIs:

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:-$(gcloud config get-value project)}"

echo "Enabling APIs for project: $PROJECT_ID"
echo

# Define your API list
APIS=(
    "cloudresourcemanager.googleapis.com"
    "compute.googleapis.com"
    "iam.googleapis.com"
    "iamcredentials.googleapis.com"
    "sts.googleapis.com"
    "serviceusage.googleapis.com"
    "artifactregistry.googleapis.com"
    "cloudbuild.googleapis.com"
    "run.googleapis.com"
    "aiplatform.googleapis.com"
    "storage.googleapis.com"
    "sqladmin.googleapis.com"
    "redis.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
    "cloudtrace.googleapis.com"
    "secretmanager.googleapis.com"
    "cloudkms.googleapis.com"
    "cloudscheduler.googleapis.com"
    "vpcaccess.googleapis.com"
)

for api in "${APIS[@]}"; do
    echo "  Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" 2>/dev/null || {
        echo "    ⚠️  Could not enable $api (may require billing or permissions)"
    }
done

echo
echo "✅ API enablement complete"

# Verify
echo
echo "Verifying enabled APIs..."
gcloud services list --enabled \
    --project="$PROJECT_ID" \
    --format="table(config.name)" | head -20
```

## API Verification Script

Verify required APIs are enabled:

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:-$(gcloud config get-value project)}"

REQUIRED_APIS=(
    "run.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
    "iam.googleapis.com"
)

echo "Checking APIs for project: $PROJECT_ID"
echo

# Get enabled APIs once
ENABLED=$(gcloud services list --enabled \
    --format="value(config.name)" \
    --project="$PROJECT_ID")

MISSING=0
for api in "${REQUIRED_APIS[@]}"; do
    if echo "$ENABLED" | grep -q "^$api$"; then
        echo "  ✅ $api"
    else
        echo "  ❌ $api (not enabled)"
        ((MISSING++))
    fi
done

echo
if [ $MISSING -eq 0 ]; then
    echo "✅ All required APIs are enabled"
else
    echo "❌ $MISSING APIs need to be enabled"
    exit 1
fi
```

## Troubleshooting

### API Not Found

```bash
# Search for API name
gcloud services list --available \
    --filter="name:*run*" \
    --format="table(config.name,config.title)"
```

### Permission Denied

```bash
# Check if you have permission to enable APIs
gcloud projects get-iam-policy PROJECT_ID \
    --filter="bindings.members:YOUR_EMAIL" \
    --format="value(bindings.role)" | grep -E "(Owner|Editor|serviceUsage)"
```

### Billing Not Enabled

Some APIs require billing to be enabled:

```bash
# Check billing status
gcloud billing projects describe PROJECT_ID

# Link billing account
gcloud billing projects link PROJECT_ID \
    --billing-account=BILLING_ACCOUNT_ID
```

### API Quota Issues

```bash
# Check quotas
gcloud services quotas list \
    --service=run.googleapis.com \
    --project=PROJECT_ID

# Request quota increase via console
echo "Visit: https://console.cloud.google.com/iam-admin/quotas?project=PROJECT_ID"
```

## Best Practices

1. **Enable in batches** - Group related APIs and enable together
2. **Document requirements** - Keep a list of required APIs for your project
3. **Verify after enabling** - Always confirm APIs are enabled before deploying
4. **Use service accounts** - Enable APIs using a service account with appropriate permissions
5. **Check dependencies** - Some APIs require other APIs to be enabled first
6. **Monitor costs** - Some APIs have costs; review pricing before enabling
