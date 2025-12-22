# AlloyDB Management Guide

This guide covers managing AlloyDB for PostgreSQL clusters and instances using the gcloud CLI.

## Prerequisites

Enable the AlloyDB API:

```bash
gcloud services enable alloydb.googleapis.com
```

AlloyDB requires:
- A VPC network with Private Service Access configured
- Service Networking API enabled

```bash
gcloud services enable servicenetworking.googleapis.com
```

## Network Setup

AlloyDB uses private IP addresses and requires VPC peering:

```bash
# Allocate IP range for private services
gcloud compute addresses create google-managed-services-default \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=16 \
  --network=default

# Create private connection
gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services-default \
  --network=default
```

## Cluster Operations

### Create Cluster

```bash
# Basic cluster
gcloud alloydb clusters create my-cluster \
  --region=us-central1 \
  --password=MY_SECURE_PASSWORD \
  --network=default

# With specific database version
gcloud alloydb clusters create my-cluster \
  --region=us-central1 \
  --password=MY_SECURE_PASSWORD \
  --network=default \
  --database-version=POSTGRES_15

# With Private Service Connect
gcloud alloydb clusters create my-cluster \
  --region=us-central1 \
  --password=MY_SECURE_PASSWORD \
  --enable-private-service-connect \
  --network=default

# Async (returns immediately)
gcloud alloydb clusters create my-cluster \
  --region=us-central1 \
  --password=MY_SECURE_PASSWORD \
  --network=default \
  --async
```

### List Clusters

```bash
# List all clusters in region
gcloud alloydb clusters list --region=us-central1

# List all clusters
gcloud alloydb clusters list

# With specific format
gcloud alloydb clusters list \
  --region=us-central1 \
  --format="table(name,state,databaseVersion)"
```

### Describe Cluster

```bash
gcloud alloydb clusters describe my-cluster \
  --region=us-central1

# Get specific field
gcloud alloydb clusters describe my-cluster \
  --region=us-central1 \
  --format="value(state)"
```

### Update Cluster

```bash
# Update automated backup policy
gcloud alloydb clusters update my-cluster \
  --region=us-central1 \
  --automated-backup-enabled \
  --automated-backup-start-time=02:00 \
  --automated-backup-days-of-week=SUNDAY

# Update maintenance window
gcloud alloydb clusters update my-cluster \
  --region=us-central1 \
  --maintenance-window-day=SUNDAY \
  --maintenance-window-hour=3
```

### Delete Cluster

```bash
# Delete cluster (must delete instances first)
gcloud alloydb clusters delete my-cluster \
  --region=us-central1

# Force delete (deletes instances too)
gcloud alloydb clusters delete my-cluster \
  --region=us-central1 \
  --force
```

## Instance Operations

### Create Primary Instance

```bash
# Basic primary instance
gcloud alloydb instances create my-primary \
  --cluster=my-cluster \
  --region=us-central1 \
  --instance-type=PRIMARY \
  --cpu-count=2

# With specific machine type
gcloud alloydb instances create my-primary \
  --cluster=my-cluster \
  --region=us-central1 \
  --instance-type=PRIMARY \
  --cpu-count=4 \
  --availability-type=REGIONAL

# With database flags
gcloud alloydb instances create my-primary \
  --cluster=my-cluster \
  --region=us-central1 \
  --instance-type=PRIMARY \
  --cpu-count=2 \
  --database-flags="max_connections=200,log_min_duration_statement=1000"
```

### Create Read Pool Instance

```bash
# Create read pool
gcloud alloydb instances create my-read-pool \
  --cluster=my-cluster \
  --region=us-central1 \
  --instance-type=READ_POOL \
  --cpu-count=2 \
  --read-pool-node-count=2
```

### List Instances

```bash
gcloud alloydb instances list \
  --cluster=my-cluster \
  --region=us-central1

# With format
gcloud alloydb instances list \
  --cluster=my-cluster \
  --region=us-central1 \
  --format="table(name,instanceType,state,ipAddress)"
```

### Describe Instance

```bash
gcloud alloydb instances describe my-primary \
  --cluster=my-cluster \
  --region=us-central1

# Get IP address
gcloud alloydb instances describe my-primary \
  --cluster=my-cluster \
  --region=us-central1 \
  --format="value(ipAddress)"
```

### Update Instance

```bash
# Scale up CPU
gcloud alloydb instances update my-primary \
  --cluster=my-cluster \
  --region=us-central1 \
  --cpu-count=4

# Update database flags
gcloud alloydb instances update my-primary \
  --cluster=my-cluster \
  --region=us-central1 \
  --database-flags="max_connections=500"
```

### Delete Instance

```bash
gcloud alloydb instances delete my-primary \
  --cluster=my-cluster \
  --region=us-central1
```

### Restart Instance

```bash
gcloud alloydb instances restart my-primary \
  --cluster=my-cluster \
  --region=us-central1
```

## User Management

### Create User

```bash
# Create database user
gcloud alloydb users create myuser \
  --cluster=my-cluster \
  --region=us-central1 \
  --password=MY_USER_PASSWORD \
  --db-roles=alloydbsuperuser

# Create user with specific roles
gcloud alloydb users create readonly_user \
  --cluster=my-cluster \
  --region=us-central1 \
  --password=READONLY_PASSWORD \
  --db-roles=pg_read_all_data
```

### List Users

```bash
gcloud alloydb users list \
  --cluster=my-cluster \
  --region=us-central1
```

### Update User Password

```bash
gcloud alloydb users set-password myuser \
  --cluster=my-cluster \
  --region=us-central1 \
  --password=NEW_PASSWORD
```

### Delete User

```bash
gcloud alloydb users delete myuser \
  --cluster=my-cluster \
  --region=us-central1
```

## Backup Operations

### Create Backup

```bash
# Manual backup
gcloud alloydb backups create my-backup \
  --cluster=my-cluster \
  --region=us-central1

# With description
gcloud alloydb backups create pre-upgrade-backup \
  --cluster=my-cluster \
  --region=us-central1 \
  --description="Backup before major upgrade"
```

### List Backups

```bash
gcloud alloydb backups list --region=us-central1

# Filter by cluster
gcloud alloydb backups list \
  --region=us-central1 \
  --filter="clusterName:my-cluster"
```

### Describe Backup

```bash
gcloud alloydb backups describe my-backup \
  --region=us-central1
```

### Delete Backup

```bash
gcloud alloydb backups delete my-backup \
  --region=us-central1
```

## Connecting to AlloyDB

AlloyDB instances use private IPs. Connection options:

### From GCE VM in Same VPC

```bash
# Get instance IP
ALLOYDB_IP=$(gcloud alloydb instances describe my-primary \
  --cluster=my-cluster \
  --region=us-central1 \
  --format="value(ipAddress)")

# Connect with psql
psql -h $ALLOYDB_IP -U postgres -d postgres
```

### Using AlloyDB Auth Proxy

```bash
# Download AlloyDB Auth Proxy
curl -o alloydb-auth-proxy https://storage.googleapis.com/alloydb-auth-proxy/v1.8.1/alloydb-auth-proxy.darwin.arm64
chmod +x alloydb-auth-proxy

# Start proxy
./alloydb-auth-proxy \
  projects/PROJECT_ID/locations/us-central1/clusters/my-cluster/instances/my-primary

# Connect via proxy
psql -h 127.0.0.1 -U postgres -d postgres
```

### From Cloud Run

```bash
# Deploy Cloud Run with VPC connector
gcloud run deploy my-app \
  --image IMAGE \
  --vpc-connector my-connector \
  --set-env-vars="DATABASE_URL=postgresql://user:pass@ALLOYDB_IP:5432/db"
```

## High Availability

### Regional Availability

```bash
# Create instance with regional availability
gcloud alloydb instances create my-primary \
  --cluster=my-cluster \
  --region=us-central1 \
  --instance-type=PRIMARY \
  --cpu-count=4 \
  --availability-type=REGIONAL

# This provides:
# - Automatic failover
# - Synchronous replication
# - 99.99% SLA
```

### Promote Read Pool

```bash
# In case of primary failure, promote read pool
gcloud alloydb instances failover my-read-pool \
  --cluster=my-cluster \
  --region=us-central1
```

## Monitoring

### View Operations

```bash
# List ongoing operations
gcloud alloydb operations list \
  --region=us-central1

# Describe operation
gcloud alloydb operations describe OPERATION_ID \
  --region=us-central1
```

### Wait for Operation

```bash
# Wait for async operation to complete
gcloud alloydb operations wait OPERATION_ID \
  --region=us-central1
```

## Common Patterns

### Full Cluster Setup Script

```bash
#!/bin/bash

PROJECT_ID="my-project"
REGION="us-central1"
CLUSTER_NAME="production"
PRIMARY_NAME="primary"
PASSWORD="SecurePassword123!"

# Create cluster
gcloud alloydb clusters create $CLUSTER_NAME \
  --region=$REGION \
  --password=$PASSWORD \
  --network=default \
  --database-version=POSTGRES_15

# Wait for cluster
gcloud alloydb clusters describe $CLUSTER_NAME \
  --region=$REGION \
  --format="value(state)"

# Create primary instance
gcloud alloydb instances create $PRIMARY_NAME \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --instance-type=PRIMARY \
  --cpu-count=4 \
  --availability-type=REGIONAL

# Get connection info
gcloud alloydb instances describe $PRIMARY_NAME \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --format="table(ipAddress,state)"

echo "AlloyDB cluster ready!"
```

### Migration from Cloud SQL

```bash
# 1. Create AlloyDB cluster
gcloud alloydb clusters create migrated-db \
  --region=us-central1 \
  --password=PASSWORD \
  --network=default

# 2. Create instance
gcloud alloydb instances create primary \
  --cluster=migrated-db \
  --region=us-central1 \
  --instance-type=PRIMARY \
  --cpu-count=4

# 3. Use Database Migration Service
# https://cloud.google.com/database-migration
```

## Troubleshooting

### Cluster Creation Fails

```bash
# Check VPC peering status
gcloud services vpc-peerings list \
  --network=default

# Verify IP range allocation
gcloud compute addresses list --global

# Check for quota issues
gcloud compute project-info describe --project=PROJECT_ID
```

### Connection Issues

```bash
# Verify instance is running
gcloud alloydb instances describe my-primary \
  --cluster=my-cluster \
  --region=us-central1

# Check firewall rules
gcloud compute firewall-rules list \
  --filter="network:default"

# Test connectivity from VM
gcloud compute ssh my-vm --command="nc -zv ALLOYDB_IP 5432"
```

### Performance Issues

```bash
# Check instance metrics
gcloud monitoring dashboards list

# Update database flags
gcloud alloydb instances update my-primary \
  --cluster=my-cluster \
  --region=us-central1 \
  --database-flags="shared_buffers=2GB,effective_cache_size=6GB"
```

## Required IAM Roles

```bash
# AlloyDB Admin (full control)
roles/alloydb.admin

# AlloyDB Client (connect)
roles/alloydb.client

# AlloyDB Viewer (read-only)
roles/alloydb.viewer
```

Grant permissions:

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:admin@example.com" \
  --role="roles/alloydb.admin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:app@PROJECT.iam.gserviceaccount.com" \
  --role="roles/alloydb.client"
```
