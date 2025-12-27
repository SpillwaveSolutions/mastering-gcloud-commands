# Scripting Patterns

## Contents

- [Error Handling](#error-handling)
- [Idempotent Operations](#idempotent-operations)
- [Output Formatting and Parsing](#output-formatting-and-parsing)
- [Advanced Filtering](#advanced-filtering)
- [Using jq for Complex Parsing](#using-jq-for-complex-parsing)
- [Batch Operations](#batch-operations)
- [Environment Variables](#environment-variables)
- [Configuration Management](#configuration-management)
- [CI/CD Best Practices](#cicd-best-practices)
- [Reliable Script Pattern](#reliable-script-pattern)

---

## Error Handling

```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined var, pipe failure

# Check command success
if gcloud compute instances create my-vm --zone=us-central1-a; then
    echo "VM created successfully"
else
    echo "Failed to create VM" >&2
    exit 1
fi

# Capture exit code
gcloud compute instances describe my-vm --zone=us-central1-a
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    echo "VM does not exist"
fi

# Try/catch pattern
if ! output=$(gcloud run deploy my-service --image=IMAGE 2>&1); then
    echo "Deploy failed: $output" >&2
    exit 1
fi
echo "Deploy succeeded"
```

## Idempotent Operations

```bash
#!/bin/bash

# Check if VPC exists before creating
create_vpc() {
    local vpc_name=$1
    if ! gcloud compute networks describe "$vpc_name" &>/dev/null; then
        echo "Creating VPC $vpc_name..."
        gcloud compute networks create "$vpc_name" --subnet-mode=custom
    else
        echo "VPC $vpc_name already exists"
    fi
}

# Check if subnet exists before creating
create_subnet() {
    local subnet_name=$1
    local vpc_name=$2
    local region=$3
    local range=$4

    if ! gcloud compute networks subnets describe "$subnet_name" \
        --region="$region" &>/dev/null; then
        echo "Creating subnet $subnet_name..."
        gcloud compute networks subnets create "$subnet_name" \
            --network="$vpc_name" \
            --region="$region" \
            --range="$range" \
            --enable-private-ip-google-access
    else
        echo "Subnet $subnet_name already exists"
    fi
}

# Check if secret exists before creating
create_secret() {
    local secret_name=$1
    local secret_value=$2

    if ! gcloud secrets describe "$secret_name" &>/dev/null; then
        echo "Creating secret $secret_name..."
        echo -n "$secret_value" | gcloud secrets create "$secret_name" \
            --replication-policy="automatic" \
            --data-file=-
    else
        echo "Secret $secret_name exists, adding new version..."
        echo -n "$secret_value" | gcloud secrets versions add "$secret_name" \
            --data-file=-
    fi
}
```

## Output Formatting and Parsing

```bash
# JSON output
gcloud compute instances list --format=json

# Get specific field value
IP=$(gcloud compute instances describe my-vm \
    --zone=us-central1-a \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

# Get multiple fields
gcloud compute instances describe my-vm \
    --zone=us-central1-a \
    --format="value(name,zone.basename(),status)"

# Table format with custom columns
gcloud compute instances list \
    --format="table(name,zone.basename(),status,networkInterfaces[0].networkIP:label=INTERNAL_IP)"

# CSV format
gcloud compute instances list \
    --format="csv(name,zone,status)" > instances.csv

# YAML format
gcloud run services describe my-service \
    --region=us-central1 \
    --format=yaml

# Flattened output (for nested arrays)
gcloud projects get-iam-policy PROJECT_ID \
    --flatten="bindings[].members" \
    --format="table(bindings.role,bindings.members)"
```

## Advanced Filtering

```bash
# Filter by name pattern (regex)
gcloud compute instances list \
    --filter="name~'^prod-.*'"

# Filter by exact value
gcloud compute instances list \
    --filter="zone:us-central1-a"

# Multiple conditions (AND)
gcloud compute instances list \
    --filter="zone:us-central1-a AND status=RUNNING"

# OR conditions
gcloud compute instances list \
    --filter="zone:(us-central1-a OR us-central1-b)"

# Negation
gcloud compute instances list \
    --filter="NOT status=TERMINATED"

# Date comparison
gcloud compute instances list \
    --filter="creationTimestamp>'2024-01-01'"

# Field comparison
gcloud compute instances list \
    --filter="machineType.basename()=n1-standard-1"

# Label filtering
gcloud compute instances list \
    --filter="labels.env=production"

# Combine filter and format
gcloud compute instances list \
    --filter="status=RUNNING" \
    --format="value(name)" | while read name; do
    echo "Processing $name"
done
```

## Using jq for Complex Parsing

```bash
# Get all running instance names
gcloud compute instances list --format=json | \
    jq -r '.[] | select(.status=="RUNNING") | .name'

# Extract nested fields
gcloud run services describe my-service \
    --region=us-central1 \
    --format=json | \
    jq -r '.status.url'

# Build complex objects
gcloud compute instances list --format=json | \
    jq '[.[] | {name: .name, ip: .networkInterfaces[0].networkIP}]'

# Count resources
gcloud compute instances list --format=json | \
    jq 'length'

# Group by status
gcloud compute instances list --format=json | \
    jq 'group_by(.status) | map({status: .[0].status, count: length})'

# Extract secrets from Secret Manager
SECRET=$(gcloud secrets versions access latest --secret=my-secret --format=json | \
    jq -r '.payload.data' | base64 -d)
```

## Batch Operations

```bash
#!/bin/bash

# Stop all running instances in parallel
gcloud compute instances list \
    --filter="status=RUNNING" \
    --format="value(name,zone)" | while read line; do

    name=$(echo "$line" | cut -f1)
    zone=$(echo "$line" | cut -f2)

    echo "Stopping $name in $zone..."
    gcloud compute instances stop "$name" --zone="$zone" --quiet &
done

# Wait for all background jobs
wait
echo "All instances stopped"

# Delete all secrets matching pattern
gcloud secrets list --filter="name~'^temp-'" --format="value(name)" | \
    xargs -I {} gcloud secrets delete {} --quiet

# Tag all instances in a zone
gcloud compute instances list \
    --filter="zone:us-central1-a" \
    --format="value(name)" | while read name; do
    gcloud compute instances add-labels "$name" \
        --zone=us-central1-a \
        --labels="managed=true"
done
```

## Environment Variables

```bash
# Set default project and region
export CLOUDSDK_CORE_PROJECT=my-project
export CLOUDSDK_COMPUTE_REGION=us-central1
export CLOUDSDK_COMPUTE_ZONE=us-central1-a

# Disable prompts for CI/CD
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

# Service account authentication
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json

# Use in commands (automatically picked up)
gcloud compute instances list  # Uses CLOUDSDK_CORE_PROJECT

# Override for single command
CLOUDSDK_CORE_PROJECT=other-project gcloud compute instances list
```

## Configuration Management

```bash
# Create named configuration
gcloud config configurations create prod
gcloud config set project prod-project-id
gcloud config set compute/region us-central1

# Create dev configuration
gcloud config configurations create dev
gcloud config set project dev-project-id
gcloud config set compute/region us-west1

# Switch configurations
gcloud config configurations activate prod

# List configurations
gcloud config configurations list

# Use specific config for one command
gcloud compute instances list --configuration=dev

# Delete configuration
gcloud config configurations delete old-config
```

## CI/CD Best Practices

```bash
# Non-interactive mode (critical for CI/CD)
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

# Or use --quiet flag
gcloud compute instances delete my-vm \
    --zone=us-central1-a \
    --quiet

# Authentication in CI/CD using WIF (preferred)
# See workload-identity.md for setup

# Using service account key (avoid if possible)
echo "$GOOGLE_CREDENTIALS" | base64 -d > /tmp/key.json
gcloud auth activate-service-account --key-file=/tmp/key.json
rm /tmp/key.json  # Clean up immediately
```

## Reliable Script Pattern

```bash
#!/bin/bash
set -euo pipefail

# Validate required environment variables
: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${REGION:?REGION must be set}"
: "${IMAGE:?IMAGE must be set}"

# Set project
gcloud config set project "$PROJECT_ID" --quiet

# Disable prompts
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

# Function with error handling
deploy_service() {
    local service_name=$1
    local image=$2

    echo "Deploying $service_name..."

    if ! gcloud run deploy "$service_name" \
        --image="$image" \
        --region="$REGION" \
        --quiet 2>&1; then
        echo "Deployment failed, fetching logs..." >&2
        gcloud logging read "resource.type=cloud_run_revision" \
            --limit=50 \
            --format="table(timestamp,textPayload)"
        return 1
    fi

    # Get service URL
    URL=$(gcloud run services describe "$service_name" \
        --region="$REGION" \
        --format="value(status.url)")

    echo "Deployed to: $URL"
}

# Main execution
main() {
    deploy_service "my-service" "$IMAGE"
}

main "$@"
```
