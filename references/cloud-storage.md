# Google Cloud Storage (GCS) Guide

This guide covers managing Cloud Storage buckets and objects using the gcloud CLI,
including bucket creation, permissions, lifecycle policies, and data transfer.

## Prerequisites

Enable the Cloud Storage API:

```bash
gcloud services enable storage.googleapis.com
```

## Bucket Operations

### Create Buckets

```bash
# Basic bucket (default settings)
gcloud storage buckets create gs://my-bucket-name

# With location
gcloud storage buckets create gs://my-bucket \
  --location=us-central1

# Multi-regional bucket
gcloud storage buckets create gs://my-global-bucket \
  --location=us

# With storage class
gcloud storage buckets create gs://archive-bucket \
  --location=us-central1 \
  --storage-class=COLDLINE

# With uniform bucket-level access (recommended)
gcloud storage buckets create gs://secure-bucket \
  --location=us-central1 \
  --uniform-bucket-level-access \
  --public-access-prevention
```

**Bucket naming rules:**
- Globally unique across all of GCS
- 3-63 characters
- Lowercase letters, numbers, hyphens, underscores
- Cannot start with "goog" prefix

### Storage Classes

| Class | Use Case | Minimum Storage Duration |
|-------|----------|-------------------------|
| STANDARD | Frequently accessed data | None |
| NEARLINE | Once per month | 30 days |
| COLDLINE | Once per quarter | 90 days |
| ARCHIVE | Once per year | 365 days |

### List Buckets

```bash
# List all buckets in project
gcloud storage buckets list

# With details
gcloud storage buckets list --format="table(name,location,storageClass)"
```

### Describe Bucket

```bash
gcloud storage buckets describe gs://my-bucket

# Specific properties
gcloud storage buckets describe gs://my-bucket --format="value(location)"
```

### Update Bucket

```bash
# Enable versioning
gcloud storage buckets update gs://my-bucket --versioning

# Disable versioning
gcloud storage buckets update gs://my-bucket --no-versioning

# Set default storage class
gcloud storage buckets update gs://my-bucket --default-storage-class=NEARLINE
```

### Delete Bucket

```bash
# Delete empty bucket
gcloud storage buckets delete gs://my-bucket

# Delete bucket and all contents (use with caution!)
gcloud storage rm -r gs://my-bucket
```

## Object Operations

### Upload Files

```bash
# Upload single file
gcloud storage cp local-file.txt gs://my-bucket/

# Upload with specific name
gcloud storage cp local-file.txt gs://my-bucket/remote-name.txt

# Upload to subdirectory
gcloud storage cp local-file.txt gs://my-bucket/path/to/file.txt

# Upload directory recursively
gcloud storage cp -r ./local-directory gs://my-bucket/

# Upload with parallel processing
gcloud storage cp -r ./large-directory gs://my-bucket/ --parallel
```

### Download Files

```bash
# Download single file
gcloud storage cp gs://my-bucket/file.txt ./local/

# Download directory
gcloud storage cp -r gs://my-bucket/directory ./local/

# Download matching pattern
gcloud storage cp gs://my-bucket/*.json ./downloads/

# Resume interrupted download
gcloud storage cp gs://my-bucket/large-file.zip ./local/ --resumable
```

### List Objects

```bash
# List all objects
gcloud storage ls gs://my-bucket/

# List with details
gcloud storage ls -l gs://my-bucket/

# List recursively
gcloud storage ls -r gs://my-bucket/

# List with prefix filter
gcloud storage ls gs://my-bucket/logs/2024/

# List only directories
gcloud storage ls gs://my-bucket/ --format="value(name)" | grep '/$'
```

### Move and Copy Objects

```bash
# Move within bucket
gcloud storage mv gs://my-bucket/old-path/file.txt gs://my-bucket/new-path/

# Copy between buckets
gcloud storage cp gs://source-bucket/file.txt gs://dest-bucket/

# Move between buckets
gcloud storage mv gs://source-bucket/file.txt gs://dest-bucket/

# Copy with metadata preservation
gcloud storage cp gs://source/file gs://dest/ --preserve-acl
```

### Delete Objects

```bash
# Delete single object
gcloud storage rm gs://my-bucket/file.txt

# Delete multiple objects
gcloud storage rm gs://my-bucket/file1.txt gs://my-bucket/file2.txt

# Delete with pattern
gcloud storage rm gs://my-bucket/*.log

# Delete directory recursively
gcloud storage rm -r gs://my-bucket/directory/

# Delete all objects (keep bucket)
gcloud storage rm gs://my-bucket/**
```

### Object Metadata

```bash
# View object metadata
gcloud storage objects describe gs://my-bucket/file.txt

# Update content type
gcloud storage objects update gs://my-bucket/file.txt \
  --content-type="application/json"

# Add custom metadata
gcloud storage objects update gs://my-bucket/file.txt \
  --custom-metadata="author=john,version=1.0"
```

## Permissions

### Bucket IAM

```bash
# View bucket policy
gcloud storage buckets get-iam-policy gs://my-bucket

# Grant read access
gcloud storage buckets add-iam-policy-binding gs://my-bucket \
  --member="user:analyst@example.com" \
  --role="roles/storage.objectViewer"

# Grant write access
gcloud storage buckets add-iam-policy-binding gs://my-bucket \
  --member="serviceAccount:app@PROJECT.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

# Make bucket public (read-only)
gcloud storage buckets add-iam-policy-binding gs://my-bucket \
  --member="allUsers" \
  --role="roles/storage.objectViewer"

# Remove access
gcloud storage buckets remove-iam-policy-binding gs://my-bucket \
  --member="user:former@example.com" \
  --role="roles/storage.objectViewer"
```

### Common Storage Roles

| Role | Description |
|------|-------------|
| `roles/storage.admin` | Full control over buckets and objects |
| `roles/storage.objectAdmin` | Full control over objects |
| `roles/storage.objectViewer` | Read objects |
| `roles/storage.objectCreator` | Create objects |
| `roles/storage.legacyBucketOwner` | Legacy bucket owner |

### Object-Level IAM

```bash
# Grant access to specific object
gcloud storage objects add-iam-policy-binding \
  gs://my-bucket/sensitive/report.pdf \
  --member="user:executive@example.com" \
  --role="roles/storage.objectViewer"
```

## Lifecycle Management

### Create Lifecycle Rules

Create `lifecycle.json`:

```json
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 30}
      },
      {
        "action": {
          "type": "SetStorageClass",
          "storageClass": "NEARLINE"
        },
        "condition": {"age": 90}
      },
      {
        "action": {
          "type": "SetStorageClass",
          "storageClass": "COLDLINE"
        },
        "condition": {"age": 365}
      }
    ]
  }
}
```

Apply lifecycle policy:

```bash
gcloud storage buckets update gs://my-bucket \
  --lifecycle-file=lifecycle.json
```

### View Lifecycle Rules

```bash
gcloud storage buckets describe gs://my-bucket \
  --format="json(lifecycle)"
```

### Remove Lifecycle Rules

```bash
# Create empty lifecycle file
echo '{"lifecycle": {"rule": []}}' > empty-lifecycle.json

gcloud storage buckets update gs://my-bucket \
  --lifecycle-file=empty-lifecycle.json
```

### Common Lifecycle Patterns

**Delete old logs:**
```json
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 30,
          "matchesPrefix": ["logs/"]
        }
      }
    ]
  }
}
```

**Archive and delete:**
```json
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "SetStorageClass", "storageClass": "ARCHIVE"},
        "condition": {"age": 90}
      },
      {
        "action": {"type": "Delete"},
        "condition": {"age": 730}
      }
    ]
  }
}
```

## Versioning

```bash
# Enable versioning
gcloud storage buckets update gs://my-bucket --versioning

# List object versions
gcloud storage ls --all-versions gs://my-bucket/file.txt

# Delete specific version
gcloud storage rm gs://my-bucket/file.txt#GENERATION_NUMBER

# Restore previous version (copy old version to current)
gcloud storage cp gs://my-bucket/file.txt#OLD_GENERATION gs://my-bucket/file.txt
```

## Signed URLs

Generate temporary access URLs:

```bash
# Generate signed URL (requires service account key)
gcloud storage sign-url gs://my-bucket/file.txt \
  --duration=1h \
  --private-key-file=service-account-key.json

# For downloading
gcloud storage sign-url gs://my-bucket/file.txt \
  --duration=24h \
  --private-key-file=key.json \
  --http-verb=GET

# For uploading
gcloud storage sign-url gs://my-bucket/uploads/ \
  --duration=1h \
  --private-key-file=key.json \
  --http-verb=PUT
```

## CORS Configuration

Create `cors.json`:

```json
[
  {
    "origin": ["https://example.com"],
    "method": ["GET", "HEAD", "PUT", "POST"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
```

Apply CORS:

```bash
gcloud storage buckets update gs://my-bucket --cors-file=cors.json
```

## Data Transfer

### Large-Scale Transfers

```bash
# Parallel upload for large datasets
gcloud storage cp -r ./large-data gs://my-bucket/ \
  --parallel \
  --content-type-inference

# Resume interrupted transfer
gcloud storage cp ./huge-file.zip gs://my-bucket/ --resumable
```

### Sync Directories

```bash
# Sync local to bucket (upload new/changed files)
gcloud storage rsync ./local-dir gs://my-bucket/remote-dir

# Sync with delete (mirror)
gcloud storage rsync --delete-unmatched-destination-objects \
  ./local-dir gs://my-bucket/remote-dir

# Sync bucket to local
gcloud storage rsync gs://my-bucket/remote-dir ./local-dir

# Dry run
gcloud storage rsync --dry-run ./local-dir gs://my-bucket/remote-dir
```

## Static Website Hosting

```bash
# Create bucket for website
gcloud storage buckets create gs://www.example.com \
  --location=us-central1 \
  --uniform-bucket-level-access

# Set main and error pages
gcloud storage buckets update gs://www.example.com \
  --web-main-page-suffix=index.html \
  --web-error-page=404.html

# Make public
gcloud storage buckets add-iam-policy-binding gs://www.example.com \
  --member="allUsers" \
  --role="roles/storage.objectViewer"

# Upload website files
gcloud storage cp -r ./website/* gs://www.example.com/
```

## Notifications

```bash
# Create Pub/Sub topic
gcloud pubsub topics create gcs-notifications

# Create notification
gcloud storage buckets notifications create gs://my-bucket \
  --topic=gcs-notifications \
  --event-types=OBJECT_FINALIZE,OBJECT_DELETE

# List notifications
gcloud storage buckets notifications list gs://my-bucket

# Delete notification
gcloud storage buckets notifications delete gs://my-bucket \
  --notification-id=NOTIFICATION_ID
```

## Troubleshooting

### Access Denied

```bash
# Check bucket permissions
gcloud storage buckets get-iam-policy gs://my-bucket

# Check active account
gcloud auth list

# Verify account has correct role
gcloud projects get-iam-policy PROJECT_ID \
  --filter="bindings.members:$(gcloud config get-value account)"
```

### Bucket Already Exists

```bash
# Bucket names are globally unique
# Try a more unique name:
gcloud storage buckets create gs://$(gcloud config get-value project)-my-bucket
```

### Slow Transfers

```bash
# Use parallel processing
gcloud storage cp -r ./data gs://bucket/ --parallel

# Use composite uploads for large files
gcloud storage cp ./large-file.zip gs://bucket/ --resumable
```
