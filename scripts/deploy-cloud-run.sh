#!/bin/bash
# Deploy to Cloud Run with common options
# Usage: ./deploy-cloud-run.sh <service-name> [options]

set -e

# Default values
REGION="${GCLOUD_REGION:-us-central1}"
MEMORY="512Mi"
CPU="1"
MIN_INSTANCES="0"
MAX_INSTANCES="10"
TIMEOUT="300"
ALLOW_UNAUTH="false"

# Help message
show_help() {
    cat << EOF
Deploy to Cloud Run with common options

Usage: $0 <service-name> [options]

Required:
  service-name       Name of the Cloud Run service

Options:
  --source DIR       Source directory (default: current directory)
  --image IMAGE      Container image URL (if not using --source)
  --region REGION    Deployment region (default: $REGION)
  --memory SIZE      Memory allocation (default: $MEMORY)
  --cpu COUNT        CPU allocation (default: $CPU)
  --min-instances N  Minimum instances (default: $MIN_INSTANCES)
  --max-instances N  Maximum instances (default: $MAX_INSTANCES)
  --timeout SECS     Request timeout (default: $TIMEOUT)
  --env KEY=VALUE    Environment variable (can be repeated)
  --secret KEY=SECRET  Secret from Secret Manager (can be repeated)
  --service-account SA  Runtime service account
  --allow-unauth     Allow unauthenticated access
  --tag TAG          Revision tag (for traffic splitting)
  --no-traffic       Deploy without routing traffic
  --help             Show this help message

Examples:
  $0 my-api --source . --allow-unauth
  $0 my-api --image gcr.io/project/image:v1 --env API_KEY=abc
  $0 my-api --source . --no-traffic --tag canary
EOF
}

# Parse arguments
if [ $# -lt 1 ]; then
    show_help
    exit 1
fi

SERVICE_NAME=$1
shift

SOURCE_DIR=""
IMAGE=""
ENV_VARS=()
SECRETS=()
SERVICE_ACCOUNT=""
TAG=""
NO_TRAFFIC="false"

while [ $# -gt 0 ]; do
    case $1 in
        --source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        --image)
            IMAGE="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --cpu)
            CPU="$2"
            shift 2
            ;;
        --min-instances)
            MIN_INSTANCES="$2"
            shift 2
            ;;
        --max-instances)
            MAX_INSTANCES="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --env)
            ENV_VARS+=("$2")
            shift 2
            ;;
        --secret)
            SECRETS+=("$2")
            shift 2
            ;;
        --service-account)
            SERVICE_ACCOUNT="$2"
            shift 2
            ;;
        --allow-unauth)
            ALLOW_UNAUTH="true"
            shift
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --no-traffic)
            NO_TRAFFIC="true"
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate inputs
if [ -z "$SOURCE_DIR" ] && [ -z "$IMAGE" ]; then
    SOURCE_DIR="."
fi

if [ -n "$SOURCE_DIR" ] && [ -n "$IMAGE" ]; then
    echo "Error: Cannot specify both --source and --image"
    exit 1
fi

# Build command
CMD="gcloud run deploy $SERVICE_NAME"
CMD="$CMD --region=$REGION"
CMD="$CMD --memory=$MEMORY"
CMD="$CMD --cpu=$CPU"
CMD="$CMD --min-instances=$MIN_INSTANCES"
CMD="$CMD --max-instances=$MAX_INSTANCES"
CMD="$CMD --timeout=${TIMEOUT}s"
CMD="$CMD --platform=managed"

if [ -n "$SOURCE_DIR" ]; then
    CMD="$CMD --source=$SOURCE_DIR"
fi

if [ -n "$IMAGE" ]; then
    CMD="$CMD --image=$IMAGE"
fi

if [ ${#ENV_VARS[@]} -gt 0 ]; then
    ENV_STRING=$(IFS=,; echo "${ENV_VARS[*]}")
    CMD="$CMD --set-env-vars=$ENV_STRING"
fi

if [ ${#SECRETS[@]} -gt 0 ]; then
    SECRET_STRING=$(IFS=,; echo "${SECRETS[*]}")
    CMD="$CMD --set-secrets=$SECRET_STRING"
fi

if [ -n "$SERVICE_ACCOUNT" ]; then
    CMD="$CMD --service-account=$SERVICE_ACCOUNT"
fi

if [ "$ALLOW_UNAUTH" = "true" ]; then
    CMD="$CMD --allow-unauthenticated"
else
    CMD="$CMD --no-allow-unauthenticated"
fi

if [ -n "$TAG" ]; then
    CMD="$CMD --tag=$TAG"
fi

if [ "$NO_TRAFFIC" = "true" ]; then
    CMD="$CMD --no-traffic"
fi

CMD="$CMD --quiet"

# Show command
echo "=== Deploying to Cloud Run ==="
echo "Service: $SERVICE_NAME"
echo "Region: $REGION"
echo "Memory: $MEMORY"
echo "CPU: $CPU"
echo ""
echo "Command:"
echo "  $CMD"
echo ""

# Confirm
read -p "Proceed with deployment? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Deployment cancelled."
    exit 0
fi

# Execute
echo ""
echo "Deploying..."
eval $CMD

# Show result
echo ""
echo "=== Deployment Complete ==="
gcloud run services describe "$SERVICE_NAME" --region="$REGION" --format="table(status.url,status.conditions[0].status)"

if [ "$NO_TRAFFIC" = "true" ] && [ -n "$TAG" ]; then
    echo ""
    echo "Tagged URL:"
    gcloud run services describe "$SERVICE_NAME" --region="$REGION" --format="value(status.traffic[].tag,status.traffic[].url)" | grep "$TAG"
fi
