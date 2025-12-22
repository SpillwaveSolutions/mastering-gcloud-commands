#!/usr/bin/env bash
# setup-wif-github.sh
# Setup Workload Identity Federation for GitHub Actions
# Part of gcloud-expert skill
#
# Features:
# - Idempotent (safe to run multiple times)
# - Dry-run mode for safe preview
# - Proper existence checks before creation
# - Color-coded output

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
POOL_NAME="github-pool"
PROVIDER_NAME="github-provider"
SA_NAME="github-deploy-sa"
DRY_RUN=false

# Helper functions
print_color() {
    echo -e "${1}${2}${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_dry_run() {
    echo -e "${CYAN}[DRY-RUN]${NC} Would: $1"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <project-id> <github-org> <github-repo>

Setup Workload Identity Federation for GitHub Actions

Arguments:
    project-id    GCP project ID
    github-org    GitHub organization or username
    github-repo   GitHub repository name

Options:
    -n, --dry-run     Show what would be done without making changes
    -p, --pool NAME   Workload Identity Pool name (default: github-pool)
    -r, --provider NAME   Provider name (default: github-provider)
    -s, --sa NAME     Service account name (default: github-deploy-sa)
    -h, --help        Show this help message

Examples:
    # Standard setup
    $0 my-project my-org my-repo

    # Dry-run to preview
    $0 --dry-run my-project my-org my-repo

    # Custom names
    $0 --pool ci-pool --sa ci-deploy-sa my-project my-org my-repo

EOF
    exit 0
}

# Check if Workload Identity Pool exists
pool_exists() {
    local project_id=$1
    local pool_name=$2
    gcloud iam workload-identity-pools describe "$pool_name" \
        --location="global" \
        --project="$project_id" &> /dev/null
}

# Check if OIDC Provider exists
provider_exists() {
    local project_id=$1
    local pool_name=$2
    local provider_name=$3
    gcloud iam workload-identity-pools providers describe "$provider_name" \
        --workload-identity-pool="$pool_name" \
        --location="global" \
        --project="$project_id" &> /dev/null
}

# Check if Service Account exists
sa_exists() {
    local project_id=$1
    local sa_name=$2
    gcloud iam service-accounts describe \
        "${sa_name}@${project_id}.iam.gserviceaccount.com" \
        --project="$project_id" &> /dev/null
}

# Check if role is already granted
has_project_role() {
    local project_id=$1
    local member=$2
    local role=$3
    gcloud projects get-iam-policy "$project_id" \
        --flatten="bindings[].members" \
        --filter="bindings.role:$role AND bindings.members:$member" \
        --format="value(bindings.role)" 2>/dev/null | grep -q .
}

# Parse command line arguments
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -p|--pool)
            POOL_NAME="$2"
            shift 2
            ;;
        -r|--provider)
            PROVIDER_NAME="$2"
            shift 2
            ;;
        -s|--sa)
            SA_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            print_error "Unknown option: $1"
            usage
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Restore positional parameters
set -- "${POSITIONAL_ARGS[@]}"

# Validate arguments
if [ $# -lt 3 ]; then
    print_error "Missing required arguments"
    echo
    usage
fi

PROJECT_ID=$1
GITHUB_ORG=$2
GITHUB_REPO=$3

# Main setup
print_color "$CYAN" "========================================="
print_color "$CYAN" "  Workload Identity Federation Setup"
print_color "$CYAN" "========================================="
echo
print_info "Project: $PROJECT_ID"
print_info "GitHub: $GITHUB_ORG/$GITHUB_REPO"
print_info "Pool: $POOL_NAME"
print_info "Provider: $PROVIDER_NAME"
print_info "Service Account: $SA_NAME"
if [ "$DRY_RUN" = true ]; then
    print_warning "DRY-RUN MODE - No changes will be made"
fi
echo

# Step 1: Enable required APIs
print_color "$CYAN" "Step 1: Enable required APIs"
if [ "$DRY_RUN" = true ]; then
    print_dry_run "Enable iamcredentials.googleapis.com"
    print_dry_run "Enable cloudresourcemanager.googleapis.com"
    print_dry_run "Enable sts.googleapis.com"
else
    print_info "Enabling APIs..."
    gcloud services enable \
        iamcredentials.googleapis.com \
        cloudresourcemanager.googleapis.com \
        sts.googleapis.com \
        --project="$PROJECT_ID" \
        --quiet
    print_success "APIs enabled"
fi
echo

# Step 2: Create Workload Identity Pool
print_color "$CYAN" "Step 2: Create Workload Identity Pool"
if pool_exists "$PROJECT_ID" "$POOL_NAME"; then
    print_success "Pool '$POOL_NAME' already exists"
else
    if [ "$DRY_RUN" = true ]; then
        print_dry_run "Create Workload Identity Pool '$POOL_NAME'"
    else
        print_info "Creating pool '$POOL_NAME'..."
        gcloud iam workload-identity-pools create "$POOL_NAME" \
            --location="global" \
            --display-name="GitHub Actions Pool" \
            --description="Pool for GitHub Actions CI/CD" \
            --project="$PROJECT_ID"
        print_success "Pool created"
    fi
fi
echo

# Step 3: Create OIDC Provider
print_color "$CYAN" "Step 3: Create OIDC Provider"
if provider_exists "$PROJECT_ID" "$POOL_NAME" "$PROVIDER_NAME"; then
    print_success "Provider '$PROVIDER_NAME' already exists"
else
    if [ "$DRY_RUN" = true ]; then
        print_dry_run "Create OIDC Provider '$PROVIDER_NAME'"
    else
        print_info "Creating provider '$PROVIDER_NAME'..."
        gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_NAME" \
            --workload-identity-pool="$POOL_NAME" \
            --location="global" \
            --issuer-uri="https://token.actions.githubusercontent.com" \
            --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
            --attribute-condition="assertion.repository_owner == '$GITHUB_ORG'" \
            --project="$PROJECT_ID"
        print_success "Provider created"
    fi
fi
echo

# Step 4: Create Service Account
print_color "$CYAN" "Step 4: Create Service Account"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if sa_exists "$PROJECT_ID" "$SA_NAME"; then
    print_success "Service account '$SA_NAME' already exists"
else
    if [ "$DRY_RUN" = true ]; then
        print_dry_run "Create service account '$SA_NAME'"
    else
        print_info "Creating service account '$SA_NAME'..."
        gcloud iam service-accounts create "$SA_NAME" \
            --display-name="GitHub Deploy Service Account" \
            --description="Service account for GitHub Actions deployments" \
            --project="$PROJECT_ID"
        print_success "Service account created"
    fi
fi
echo

# Step 5: Grant roles to service account
print_color "$CYAN" "Step 5: Grant roles to service account"

ROLES=(
    "roles/run.admin"
    "roles/artifactregistry.writer"
    "roles/storage.objectAdmin"
    "roles/cloudbuild.builds.editor"
    "roles/iam.serviceAccountUser"
)

for ROLE in "${ROLES[@]}"; do
    if has_project_role "$PROJECT_ID" "serviceAccount:$SA_EMAIL" "$ROLE"; then
        print_success "$ROLE already granted"
    else
        if [ "$DRY_RUN" = true ]; then
            print_dry_run "Grant $ROLE to $SA_NAME"
        else
            print_info "Granting $ROLE..."
            gcloud projects add-iam-policy-binding "$PROJECT_ID" \
                --member="serviceAccount:$SA_EMAIL" \
                --role="$ROLE" \
                --condition=None \
                --quiet
            print_success "$ROLE granted"
        fi
    fi
done
echo

# Step 6: Grant Workload Identity User
print_color "$CYAN" "Step 6: Grant Workload Identity access"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
WIF_MEMBER="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}"

if [ "$DRY_RUN" = true ]; then
    print_dry_run "Grant workloadIdentityUser to $GITHUB_ORG/$GITHUB_REPO"
else
    print_info "Granting workload identity access..."
    gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
        --member="$WIF_MEMBER" \
        --role="roles/iam.workloadIdentityUser" \
        --project="$PROJECT_ID" \
        --quiet
    print_success "Workload identity access granted"
fi
echo

# Output configuration
print_color "$CYAN" "========================================="
print_color "$CYAN" "  Setup Complete!"
print_color "$CYAN" "========================================="
echo

if [ "$DRY_RUN" = true ]; then
    print_warning "DRY-RUN: No changes were made"
    echo
fi

print_info "Add these secrets to your GitHub repository:"
echo
echo "WIF_PROVIDER:"
echo "  projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/providers/${PROVIDER_NAME}"
echo
echo "WIF_SERVICE_ACCOUNT:"
echo "  ${SA_EMAIL}"
echo
echo "GCP_PROJECT_ID:"
echo "  ${PROJECT_ID}"
echo

print_info "Example GitHub Actions workflow:"
echo
cat << 'EOF'
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - uses: actions/checkout@v4

      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - uses: google-github-actions/setup-gcloud@v2

      - run: gcloud run deploy my-service --source . --region us-central1 --quiet
EOF
