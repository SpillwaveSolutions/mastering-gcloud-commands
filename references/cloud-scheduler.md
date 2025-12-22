# Cloud Scheduler Guide

This guide covers creating and managing scheduled jobs with Google Cloud Scheduler,
including HTTP targets, Pub/Sub integration, and authentication.

## Prerequisites

Enable the Cloud Scheduler API:

```bash
gcloud services enable cloudscheduler.googleapis.com
```

## Creating Scheduler Jobs

### HTTP Jobs

#### Basic HTTP Job

```bash
gcloud scheduler jobs create http my-job \
  --location=us-central1 \
  --schedule="0 * * * *" \
  --uri="https://example.com/api/task" \
  --http-method=GET
```

#### HTTP POST with Body

```bash
gcloud scheduler jobs create http api-job \
  --location=us-central1 \
  --schedule="*/15 * * * *" \
  --uri="https://api.example.com/process" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"action":"process","timestamp":"now"}'

# Body from file
gcloud scheduler jobs create http batch-job \
  --location=us-central1 \
  --schedule="0 2 * * *" \
  --uri="https://api.example.com/batch" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body-from-file=payload.json
```

### Pub/Sub Jobs

```bash
# Create Pub/Sub topic
gcloud pubsub topics create my-topic

# Create scheduler job to publish
gcloud scheduler jobs create pubsub pubsub-job \
  --location=us-central1 \
  --schedule="*/10 * * * *" \
  --topic=my-topic \
  --message-body='{"event":"scheduled","timestamp":"$(date)"}'

# With attributes
gcloud scheduler jobs create pubsub pubsub-job \
  --location=us-central1 \
  --schedule="0 * * * *" \
  --topic=my-topic \
  --message-body="process" \
  --attributes="type=scheduled,source=scheduler"
```

### App Engine Jobs

```bash
gcloud scheduler jobs create app-engine ae-job \
  --location=us-central1 \
  --schedule="0 0 * * *" \
  --service=my-service \
  --relative-url=/cron/daily
```

## Schedule Syntax (Cron Format)

```
┌───────────── minute (0-59)
│ ┌───────────── hour (0-23)
│ │ ┌───────────── day of month (1-31)
│ │ │ ┌───────────── month (1-12)
│ │ │ │ ┌───────────── day of week (0-6, Sun=0)
│ │ │ │ │
* * * * *
```

### Common Schedule Patterns

| Schedule | Cron Expression | Description |
|----------|----------------|-------------|
| Every minute | `* * * * *` | Every minute |
| Every 5 minutes | `*/5 * * * *` | At :00, :05, :10, etc. |
| Every hour | `0 * * * *` | At minute 0 of every hour |
| Every 3 hours | `0 */3 * * *` | At minute 0 of every 3rd hour |
| Daily at midnight | `0 0 * * *` | At 00:00 every day |
| Daily at 9 AM | `0 9 * * *` | At 09:00 every day |
| Weekly on Monday | `0 9 * * 1` | At 09:00 every Monday |
| Monthly first day | `0 0 1 * *` | At 00:00 on day 1 of month |
| Weekdays only | `0 9 * * 1-5` | At 09:00 Mon-Fri |

### Time Zone Configuration

```bash
gcloud scheduler jobs create http my-job \
  --location=us-central1 \
  --schedule="0 9 * * *" \
  --time-zone="America/Los_Angeles" \
  --uri="https://api.example.com/daily"
```

## Authentication

### OIDC Authentication (for Cloud Run)

```bash
# 1. Create service account for scheduler
gcloud iam service-accounts create scheduler-sa \
  --display-name="Cloud Scheduler SA"

# 2. Grant Cloud Run Invoker role
gcloud run services add-iam-policy-binding my-service \
  --region=us-central1 \
  --member="serviceAccount:scheduler-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.invoker"

# 3. Create job with OIDC auth
gcloud scheduler jobs create http trigger-cloud-run \
  --location=us-central1 \
  --schedule="0 * * * *" \
  --uri="https://my-service-HASH.a.run.app/task" \
  --http-method=POST \
  --oidc-service-account-email=scheduler-sa@PROJECT_ID.iam.gserviceaccount.com
```

### OIDC with Audience

For Cloud Run, specify the audience (service URL):

```bash
SERVICE_URL=$(gcloud run services describe my-service \
  --region us-central1 \
  --format='value(status.url)')

gcloud scheduler jobs create http secure-trigger \
  --location=us-central1 \
  --schedule="0 2 * * *" \
  --uri="${SERVICE_URL}/api/scheduled" \
  --http-method=POST \
  --oidc-service-account-email=scheduler-sa@PROJECT_ID.iam.gserviceaccount.com \
  --oidc-token-audience="${SERVICE_URL}"
```

### OAuth Authentication

For Google APIs or services requiring OAuth:

```bash
gcloud scheduler jobs create http oauth-job \
  --location=us-central1 \
  --schedule="0 6 * * *" \
  --uri="https://www.googleapis.com/some/api" \
  --http-method=POST \
  --oauth-service-account-email=api-caller@PROJECT_ID.iam.gserviceaccount.com \
  --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform"
```

## Retry Configuration

```bash
gcloud scheduler jobs create http retry-job \
  --location=us-central1 \
  --schedule="0 * * * *" \
  --uri="https://api.example.com/task" \
  --http-method=POST \
  --max-retry-attempts=5 \
  --max-retry-duration=3600s \
  --min-backoff=5s \
  --max-backoff=1h \
  --max-doublings=5
```

Retry parameters:
- `max-retry-attempts`: Maximum number of retries (0-5)
- `max-retry-duration`: Maximum time to keep retrying
- `min-backoff`: Minimum wait before first retry
- `max-backoff`: Maximum wait between retries
- `max-doublings`: Number of times to double backoff

## Managing Jobs

### List Jobs

```bash
# List all jobs in location
gcloud scheduler jobs list --location=us-central1

# List all jobs across locations
gcloud scheduler jobs list
```

### Describe Job

```bash
gcloud scheduler jobs describe my-job --location=us-central1
```

### Update Job

```bash
# Update schedule
gcloud scheduler jobs update http my-job \
  --location=us-central1 \
  --schedule="0 */2 * * *"

# Update URI
gcloud scheduler jobs update http my-job \
  --location=us-central1 \
  --uri="https://new-endpoint.example.com/api"

# Update headers
gcloud scheduler jobs update http my-job \
  --location=us-central1 \
  --headers="Authorization=Bearer new-token"
```

### Pause and Resume

```bash
# Pause job (stops execution but keeps configuration)
gcloud scheduler jobs pause my-job --location=us-central1

# Resume job
gcloud scheduler jobs resume my-job --location=us-central1
```

### Run Job Manually

```bash
# Trigger immediate execution (for testing)
gcloud scheduler jobs run my-job --location=us-central1
```

### Delete Job

```bash
gcloud scheduler jobs delete my-job --location=us-central1
```

## Common Patterns

### Trigger Cloud Run Service

```bash
#!/bin/bash
# Setup script for Cloud Run + Scheduler

PROJECT_ID="my-project"
REGION="us-central1"
SERVICE_NAME="my-service"
JOB_NAME="trigger-service"

# Create scheduler service account
gcloud iam service-accounts create scheduler-sa \
  --display-name="Cloud Scheduler SA"

# Get Cloud Run service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
  --region=$REGION \
  --format='value(status.url)')

# Grant invoker role
gcloud run services add-iam-policy-binding $SERVICE_NAME \
  --region=$REGION \
  --member="serviceAccount:scheduler-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/run.invoker"

# Create scheduler job
gcloud scheduler jobs create http $JOB_NAME \
  --location=$REGION \
  --schedule="0 * * * *" \
  --uri="${SERVICE_URL}/scheduled-task" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"source":"scheduler"}' \
  --oidc-service-account-email="scheduler-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --oidc-token-audience="${SERVICE_URL}"
```

### Daily Database Backup

```bash
gcloud scheduler jobs create http daily-backup \
  --location=us-central1 \
  --schedule="0 2 * * *" \
  --time-zone="UTC" \
  --uri="https://backup-service.a.run.app/backup" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"type":"full","retention_days":30}' \
  --oidc-service-account-email=scheduler-sa@PROJECT.iam.gserviceaccount.com \
  --max-retry-attempts=3
```

### Cache Invalidation

```bash
gcloud scheduler jobs create http cache-refresh \
  --location=us-central1 \
  --schedule="*/30 * * * *" \
  --uri="https://api.example.com/cache/invalidate" \
  --http-method=DELETE \
  --oidc-service-account-email=scheduler-sa@PROJECT.iam.gserviceaccount.com
```

### Report Generation

```bash
gcloud scheduler jobs create http weekly-report \
  --location=us-central1 \
  --schedule="0 8 * * 1" \
  --time-zone="America/New_York" \
  --uri="https://reports.example.com/generate" \
  --http-method=POST \
  --message-body='{"report_type":"weekly_summary","recipients":["team@example.com"]}' \
  --oidc-service-account-email=scheduler-sa@PROJECT.iam.gserviceaccount.com \
  --max-retry-attempts=3 \
  --max-retry-duration=1800s
```

## Required IAM Roles

```bash
# Cloud Scheduler Admin (create/manage jobs)
roles/cloudscheduler.admin

# Cloud Scheduler Viewer (read-only)
roles/cloudscheduler.viewer
```

Grant scheduler permissions:

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:admin@example.com" \
  --role="roles/cloudscheduler.admin"
```

## Troubleshooting

### Job Not Triggering

```bash
# Check job status
gcloud scheduler jobs describe my-job --location=us-central1

# Verify schedule is correct
# Check time zone settings
# Ensure job is not paused

# View execution history in Cloud Logging
gcloud logging read "resource.type=cloud_scheduler_job AND resource.labels.job_id=my-job" --limit=10
```

### Authentication Failures (401/403)

```bash
# Verify service account exists
gcloud iam service-accounts list | grep scheduler-sa

# Check service account has invoker role
gcloud run services get-iam-policy my-service --region=us-central1

# Verify OIDC configuration
gcloud scheduler jobs describe my-job --location=us-central1 | grep oidc
```

### HTTP Errors

```bash
# View detailed error logs
gcloud logging read "resource.type=cloud_scheduler_job" --format="json" --limit=5

# Test endpoint manually
curl -X POST https://my-service.a.run.app/task \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)"
```

### Missing Audience Error

For Cloud Run, ensure `--oidc-token-audience` matches the service URL exactly:

```bash
# Get exact service URL
gcloud run services describe SERVICE --region=REGION --format='value(status.url)'

# Use this URL for audience
```
