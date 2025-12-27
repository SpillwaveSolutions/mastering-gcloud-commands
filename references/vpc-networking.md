# VPC Networking

## Contents

- [Network Management](#network-management)
- [Subnet Management](#subnet-management)
- [Firewall Rules](#firewall-rules)
- [VPC Peering](#vpc-peering)
- [Private Service Connection](#private-service-connection)
- [Serverless VPC Connector](#serverless-vpc-connector)
- [Private Google Access](#private-google-access)
- [Best Practices](#best-practices)

---

## Network Management

```bash
# Create custom VPC (recommended over auto mode)
gcloud compute networks create my-vpc \
  --subnet-mode=custom \
  --bgp-routing-mode=regional

# List networks
gcloud compute networks list

# Describe network
gcloud compute networks describe my-vpc

# Delete network (must delete subnets first)
gcloud compute networks delete my-vpc --quiet
```

## Subnet Management

```bash
# Create subnet
gcloud compute networks subnets create my-subnet \
  --network=my-vpc \
  --region=us-central1 \
  --range=10.0.1.0/24 \
  --enable-private-ip-google-access

# Create subnet with secondary ranges (for GKE)
gcloud compute networks subnets create gke-subnet \
  --network=my-vpc \
  --region=us-central1 \
  --range=10.0.0.0/24 \
  --secondary-range=pods=10.1.0.0/16,services=10.2.0.0/20 \
  --enable-private-ip-google-access

# List subnets
gcloud compute networks subnets list --network=my-vpc

# List subnets in region
gcloud compute networks subnets list \
  --network=my-vpc \
  --regions=us-central1

# Describe subnet
gcloud compute networks subnets describe my-subnet \
  --region=us-central1

# Expand subnet range (can only increase, not decrease)
gcloud compute networks subnets expand-ip-range my-subnet \
  --region=us-central1 \
  --prefix-length=20

# Delete subnet
gcloud compute networks subnets delete my-subnet \
  --region=us-central1 --quiet
```

## Firewall Rules

```bash
# Create ingress rule (allow incoming)
gcloud compute firewall-rules create allow-https \
  --network=my-vpc \
  --direction=INGRESS \
  --allow=tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=web-server \
  --priority=1000

# Create rule with multiple ports
gcloud compute firewall-rules create allow-web \
  --network=my-vpc \
  --allow=tcp:80,tcp:443,tcp:8080 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=web-server

# Create internal-only rule
gcloud compute firewall-rules create allow-internal \
  --network=my-vpc \
  --allow=tcp,udp,icmp \
  --source-ranges=10.0.0.0/8

# Create egress rule (allow outgoing)
gcloud compute firewall-rules create deny-external-egress \
  --network=my-vpc \
  --direction=EGRESS \
  --action=DENY \
  --rules=all \
  --destination-ranges=0.0.0.0/0 \
  --priority=65534

# List firewall rules
gcloud compute firewall-rules list --filter="network:my-vpc"

# Describe rule
gcloud compute firewall-rules describe allow-https

# Update rule
gcloud compute firewall-rules update allow-https \
  --allow=tcp:443,tcp:80

# Delete rule
gcloud compute firewall-rules delete allow-https --quiet
```

**Firewall Rule Evaluation:**
- Lower priority number = higher priority
- Default priority is 1000
- Range: 0 (highest) to 65535 (lowest)

## VPC Peering

```bash
# Create peering connection (bidirectional - must create on both sides)
gcloud compute networks peerings create peer-to-vpc-b \
  --network=my-vpc-a \
  --peer-project=PROJECT_ID \
  --peer-network=my-vpc-b \
  --auto-create-routes

# Create peering on the other side
gcloud compute networks peerings create peer-to-vpc-a \
  --network=my-vpc-b \
  --peer-project=PROJECT_ID \
  --peer-network=my-vpc-a \
  --auto-create-routes

# List peerings
gcloud compute networks peerings list --network=my-vpc-a

# Describe peering
gcloud compute networks peerings describe peer-to-vpc-b \
  --network=my-vpc-a

# Delete peering
gcloud compute networks peerings delete peer-to-vpc-b \
  --network=my-vpc-a --quiet
```

## Private Service Connection

Required for AlloyDB, Cloud SQL, Memorystore, and other managed services:

```bash
# 1. Allocate IP range for Google services
gcloud compute addresses create google-managed-services-range \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=16 \
  --network=my-vpc \
  --description="Reserved for Google managed services"

# 2. Create private service connection
gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services-range \
  --network=my-vpc

# 3. Verify connection (may take a few minutes)
gcloud services vpc-peerings list --network=my-vpc

# List allocated ranges
gcloud compute addresses list \
  --global \
  --filter="purpose=VPC_PEERING"

# Update connection (add more ranges)
gcloud services vpc-peerings update \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services-range,another-range \
  --network=my-vpc
```

## Serverless VPC Connector

Enables Cloud Run, Cloud Functions, and App Engine to access VPC resources:

```bash
# Create VPC connector
gcloud compute networks vpc-access connectors create my-connector \
  --region=us-central1 \
  --network=my-vpc \
  --range=10.8.0.0/28 \
  --min-instances=2 \
  --max-instances=10 \
  --machine-type=e2-micro

# List connectors
gcloud compute networks vpc-access connectors list --region=us-central1

# Describe connector
gcloud compute networks vpc-access connectors describe my-connector \
  --region=us-central1

# Delete connector
gcloud compute networks vpc-access connectors delete my-connector \
  --region=us-central1 --quiet
```

**Connector IP Range Requirements:**
- Must be /28 CIDR (16 IPs)
- Must not overlap with existing subnets
- Must not be used by other connectors
- Common ranges: `10.8.0.0/28`, `10.9.0.0/28`

## Private Google Access

Allows VMs without external IPs to reach Google APIs:

```bash
# Enable on existing subnet
gcloud compute networks subnets update my-subnet \
  --region=us-central1 \
  --enable-private-ip-google-access

# Check if enabled
gcloud compute networks subnets describe my-subnet \
  --region=us-central1 \
  --format="value(privateIpGoogleAccess)"

# Disable (not recommended)
gcloud compute networks subnets update my-subnet \
  --region=us-central1 \
  --no-enable-private-ip-google-access
```

## Best Practices

| Category | Recommendation |
|:---------|:---------------|
| **VPC Mode** | Use custom subnet mode for production |
| **IP Planning** | Plan non-overlapping CIDR ranges upfront |
| **Private Access** | Enable Private Google Access on all subnets |
| **Firewall** | Use target tags for granular rule application |
| **Firewall** | Start restrictive, add exceptions as needed |
| **Peering** | Remember peering is non-transitive (A↔B, B↔C ≠ A↔C) |
| **Connectors** | Size VPC connectors based on expected traffic |
| **Security** | Use VPC Service Controls for data exfiltration protection |
| **Naming** | Use consistent naming: `{env}-{purpose}-{resource}` |
