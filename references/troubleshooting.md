# Troubleshooting

## Contents

- [Debug Mode](#debug-mode)
- [Common Commands](#common-commands)
- [Enable APIs](#enable-apis)
- [Authentication Issues](#authentication-issues)
- [Permission Errors](#permission-errors)
- [Cloud Run Issues](#cloud-run-issues)
- [VPC Connectivity Issues](#vpc-connectivity-issues)
- [Common Error Messages](#common-error-messages)

---

## Debug Mode

```bash
# Verbose output
gcloud compute instances create my-vm \
    --zone=us-central1-a \
    --verbosity=debug

# Show HTTP requests (useful for API debugging)
gcloud compute instances list \
    --log-http

# Combine both
gcloud run deploy my-service \
    --image=IMAGE \
    --verbosity=debug \
    --log-http
```

## Common Commands

```bash
# Check configuration
gcloud config list
gcloud info

# View project info
gcloud projects describe PROJECT_ID

# View logs
gcloud logging read \
    'resource.type="cloud_run_revision"' \
    --limit=50 \
    --format=json

# Filter logs by severity
gcloud logging read \
    'resource.type="cloud_run_revision" AND severity>=ERROR' \
    --limit=20

# View logs with timestamp
gcloud logging read \
    'resource.type="cloud_run_revision"' \
    --limit=20 \
    --format="table(timestamp,severity,textPayload)"

# List operations (for async actions)
gcloud compute operations list --filter="status=RUNNING"
gcloud alloydb operations list --region=us-central1
gcloud run operations list --region=us-central1

# Wait for operation to complete
gcloud compute operations wait OPERATION_NAME --zone=us-central1-a

# Describe any resource
gcloud compute instances describe my-vm --zone=us-central1-a
gcloud run services describe my-service --region=us-central1
gcloud secrets describe my-secret
```

## Enable APIs

```bash
# Enable required APIs (common set)
gcloud services enable \
    compute.googleapis.com \
    run.googleapis.com \
    alloydb.googleapis.com \
    secretmanager.googleapis.com \
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    servicenetworking.googleapis.com \
    vpcaccess.googleapis.com \
    iamcredentials.googleapis.com

# List enabled services
gcloud services list --enabled

# Check if specific API is enabled
gcloud services list --enabled --filter="name:run.googleapis.com"

# Enable single API
gcloud services enable run.googleapis.com
```

## Authentication Issues

```bash
# Check current identity
gcloud auth list

# Show active account
gcloud config get-value account

# Re-authenticate
gcloud auth login

# Use service account
gcloud auth activate-service-account \
    --key-file=key.json

# Revoke credentials
gcloud auth revoke

# Print access token (for debugging)
gcloud auth print-access-token

# Print identity token (for Cloud Run auth)
gcloud auth print-identity-token

# Application Default Credentials
gcloud auth application-default login
gcloud auth application-default print-access-token
```

## Permission Errors

```bash
# Check what roles you have
gcloud projects get-iam-policy PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:$(gcloud config get-value account)" \
    --format="table(bindings.role)"

# Check service account roles
gcloud projects get-iam-policy PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:SA_EMAIL" \
    --format="table(bindings.role)"

# Test permissions
gcloud iam list-testable-permissions \
    //cloudresourcemanager.googleapis.com/projects/PROJECT_ID

# Check role permissions
gcloud iam roles describe roles/run.admin

# Check if you can perform action
gcloud asset analyze-iam-policy \
    --organization=ORG_ID \
    --identity=user:you@example.com \
    --full-resource-name="//run.googleapis.com/projects/PROJECT_ID/locations/us-central1/services/my-service" \
    --permissions="run.services.update"
```

## Cloud Run Issues

```bash
# Get service logs
gcloud logging read \
    'resource.type="cloud_run_revision" AND resource.labels.service_name="my-service"' \
    --limit=100

# Get specific revision logs
gcloud logging read \
    'resource.type="cloud_run_revision" AND resource.labels.revision_name="my-service-00001-abc"' \
    --limit=50

# Check service status
gcloud run services describe my-service \
    --region=us-central1 \
    --format="yaml(status)"

# List revisions and their status
gcloud run revisions list \
    --service=my-service \
    --region=us-central1 \
    --format="table(name,ready,activePercent)"

# Check VPC connector status
gcloud compute networks vpc-access connectors describe my-connector \
    --region=us-central1

# Force new revision
gcloud run services update my-service \
    --region=us-central1 \
    --no-traffic
```

## VPC Connectivity Issues

```bash
# Check subnet has Private Google Access
gcloud compute networks subnets describe my-subnet \
    --region=us-central1 \
    --format="value(privateIpGoogleAccess)"

# Check private service connection
gcloud services vpc-peerings list --network=my-vpc

# Check VPC connector status
gcloud compute networks vpc-access connectors describe my-connector \
    --region=us-central1 \
    --format="yaml(state,minInstances,maxInstances)"

# Check firewall rules
gcloud compute firewall-rules list \
    --filter="network:my-vpc" \
    --format="table(name,direction,allowed,sourceRanges,targetTags)"

# Test connectivity from Cloud Shell to private IP
# (Only works if Cloud Shell is in same VPC or has peering)
curl -v http://PRIVATE_IP:PORT
```

## Common Error Messages

| Error | Cause | Solution |
|:------|:------|:---------|
| `PERMISSION_DENIED` | Missing IAM role | Check roles with `gcloud projects get-iam-policy` |
| `API not enabled` | API not activated | Run `gcloud services enable API_NAME` |
| `Quota exceeded` | Resource limit reached | Check quotas in Cloud Console or request increase |
| `Resource not found` | Wrong project/region | Verify `gcloud config list` and `--region` flag |
| `VPC connector failed` | Connector unhealthy | Check connector status, may need recreation |
| `Connection refused` | Firewall blocking | Check firewall rules for the VPC |
| `Deadline exceeded` | Timeout | Increase `--timeout` or optimize code |
| `Container failed to start` | App crash on startup | Check Cloud Run logs, test locally first |
| `Image not found` | Wrong image path or auth | Verify image exists in Artifact Registry |
| `Service account not found` | SA deleted or wrong email | Check SA exists with `gcloud iam service-accounts list` |
| `Invalid JWT` | WIF token issue | Verify WIF provider and bindings |

**Debug Workflow:**
```
[ ] 1. Check gcloud config: gcloud config list
[ ] 2. Verify identity: gcloud auth list
[ ] 3. Check project permissions: gcloud projects get-iam-policy PROJECT_ID
[ ] 4. Enable debug mode: --verbosity=debug --log-http
[ ] 5. Check Cloud Logging: gcloud logging read "..."
[ ] 6. Verify resource exists: gcloud RESOURCE describe NAME
[ ] 7. Check API enabled: gcloud services list --enabled
```
