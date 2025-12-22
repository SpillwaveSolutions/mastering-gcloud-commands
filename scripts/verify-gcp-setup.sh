#!/usr/bin/env bash
# verify-gcp-setup.sh
# Comprehensive GCP setup verification with pass/fail tracking
# Part of gcloud-expert skill

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values - override with environment variables or arguments
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"
VERBOSE=false

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Helper functions
print_color() {
    echo -e "${1}${2}${NC}"
}

print_check() {
    echo -n "  Checking $1... "
}

print_pass() {
    echo -e "${GREEN}✅ PASS${NC}"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

print_fail() {
    echo -e "${RED}❌ FAIL${NC}"
    if [ -n "${1:-}" ]; then
        echo -e "    ${RED}Error: $1${NC}"
    fi
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING${NC}"
    if [ -n "${1:-}" ]; then
        echo -e "    ${YELLOW}Warning: $1${NC}"
    fi
    ((WARNING_CHECKS++))
    ((TOTAL_CHECKS++))
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Comprehensive GCP setup verification

Options:
    -p, --project-id PROJECT_ID    GCP project ID (required or set GCP_PROJECT_ID)
    -r, --region REGION            GCP region (default: us-central1)
    -v, --verbose                  Show detailed output
    -h, --help                     Show this help message

Examples:
    # Basic verification
    $0 --project-id my-project

    # With environment variable
    export GCP_PROJECT_ID=my-project
    $0

    # Verbose output
    $0 --project-id my-project --verbose

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project-id)
            PROJECT_ID="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_color "$RED" "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate project ID
if [ -z "$PROJECT_ID" ]; then
    print_color "$RED" "Error: Project ID is required"
    print_color "$YELLOW" "Set GCP_PROJECT_ID environment variable or use --project-id"
    exit 1
fi

# Check prerequisites
check_prerequisites() {
    print_color "$CYAN" "=== Prerequisites Check ==="

    print_check "gcloud CLI"
    if command -v gcloud &> /dev/null; then
        print_pass
        if [ "$VERBOSE" = true ]; then
            echo "    Version: $(gcloud version --format='value(version.core)' 2>/dev/null || echo 'unknown')"
        fi
    else
        print_fail "gcloud CLI not installed"
        exit 1
    fi

    print_check "Docker"
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            print_pass
        else
            print_warning "Docker installed but not running"
        fi
    else
        print_warning "Docker not installed (optional)"
    fi

    print_check "jq"
    if command -v jq &> /dev/null; then
        print_pass
    else
        print_warning "jq not installed (optional but recommended)"
    fi

    print_check "GitHub CLI"
    if command -v gh &> /dev/null; then
        if gh auth status &> /dev/null 2>&1; then
            print_pass
        else
            print_warning "GitHub CLI installed but not authenticated"
        fi
    else
        print_warning "GitHub CLI not installed (optional)"
    fi
}

# Check GCP project
check_project() {
    print_color "$CYAN" "=== Project Configuration ==="

    print_check "Project exists"
    if gcloud projects describe "$PROJECT_ID" &> /dev/null; then
        print_pass
        PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)" 2>/dev/null || echo "")
        if [ "$VERBOSE" = true ]; then
            echo "    Project ID: $PROJECT_ID"
            echo "    Project Number: $PROJECT_NUMBER"
        fi
    else
        print_fail "Project $PROJECT_ID not found"
        return
    fi

    print_check "Project is active"
    local state=$(gcloud projects describe "$PROJECT_ID" --format="value(lifecycleState)" 2>/dev/null || echo "UNKNOWN")
    if [ "$state" = "ACTIVE" ]; then
        print_pass
    else
        print_fail "Project state: $state (should be ACTIVE)"
    fi

    print_check "Billing enabled"
    if gcloud billing projects describe "$PROJECT_ID" 2>/dev/null | grep -q "billingEnabled: true"; then
        print_pass
    else
        print_warning "Could not verify billing status"
    fi
}

# Check enabled APIs
check_apis() {
    print_color "$CYAN" "=== API Status ==="

    local required_apis=(
        "iam.googleapis.com"
        "iamcredentials.googleapis.com"
        "sts.googleapis.com"
        "run.googleapis.com"
        "artifactregistry.googleapis.com"
        "cloudbuild.googleapis.com"
        "compute.googleapis.com"
        "storage.googleapis.com"
        "logging.googleapis.com"
        "monitoring.googleapis.com"
    )

    local enabled_apis=$(gcloud services list --enabled --format="value(config.name)" --project="$PROJECT_ID" 2>/dev/null || echo "")

    for api in "${required_apis[@]}"; do
        print_check "$api"
        if echo "$enabled_apis" | grep -q "^$api$"; then
            print_pass
        else
            print_fail "API not enabled"
        fi
    done
}

# Check authentication
check_authentication() {
    print_color "$CYAN" "=== Authentication Status ==="

    print_check "gcloud authentication"
    if gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>/dev/null | grep -q .; then
        print_pass
        if [ "$VERBOSE" = true ]; then
            echo "    Active account: $(gcloud config get-value account 2>/dev/null || echo 'unknown')"
        fi
    else
        print_fail "Not authenticated with gcloud"
    fi

    print_check "Application Default Credentials"
    if [ -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
        print_pass
        if [ "$VERBOSE" = true ] && command -v jq &> /dev/null; then
            local quota_project=$(jq -r '.quota_project_id // "not set"' "$HOME/.config/gcloud/application_default_credentials.json" 2>/dev/null)
            echo "    Quota project: $quota_project"
        fi
    else
        print_warning "ADC not configured"
    fi

    print_check "Current project setting"
    local current_project=$(gcloud config get-value project 2>/dev/null || echo "")
    if [ "$current_project" = "$PROJECT_ID" ]; then
        print_pass
    else
        print_warning "Current project: $current_project (expected: $PROJECT_ID)"
    fi
}

# Check Workload Identity Federation
check_wif() {
    print_color "$CYAN" "=== Workload Identity Federation ==="

    print_check "WIF pool exists"
    if gcloud iam workload-identity-pools describe github-pool \
        --location=global \
        --project="$PROJECT_ID" &> /dev/null; then
        print_pass
    else
        print_warning "WIF pool 'github-pool' not found (optional)"
        return
    fi

    print_check "WIF provider exists"
    if gcloud iam workload-identity-pools providers describe github-provider \
        --workload-identity-pool=github-pool \
        --location=global \
        --project="$PROJECT_ID" &> /dev/null; then
        print_pass
    else
        print_warning "WIF provider 'github-provider' not found"
    fi
}

# Check Artifact Registry
check_artifact_registry() {
    print_color "$CYAN" "=== Artifact Registry ==="

    print_check "Docker authentication"
    local docker_config="$HOME/.docker/config.json"
    if [ -f "$docker_config" ]; then
        if grep -q "${REGION}-docker.pkg.dev" "$docker_config" 2>/dev/null; then
            print_pass
        else
            print_warning "Docker not configured for ${REGION}-docker.pkg.dev"
        fi
    else
        print_warning "Docker config not found"
    fi
}

# Generate fix suggestions
generate_fixes() {
    if [ $FAILED_CHECKS -eq 0 ] && [ $WARNING_CHECKS -eq 0 ]; then
        return
    fi

    print_color "$CYAN" "\n=== Suggested Fixes ==="

    if [ $FAILED_CHECKS -gt 0 ]; then
        print_color "$YELLOW" "To fix failed checks:"
        echo "  1. Enable required APIs:"
        echo "     gcloud services enable iam.googleapis.com run.googleapis.com --project=$PROJECT_ID"
        echo "  2. Authenticate:"
        echo "     gcloud auth login"
        echo
    fi

    if [ $WARNING_CHECKS -gt 0 ]; then
        print_color "$YELLOW" "For optional components:"
        echo "  - Configure Docker: gcloud auth configure-docker ${REGION}-docker.pkg.dev"
        echo "  - Set up ADC: gcloud auth application-default login"
        echo "  - Set project: gcloud config set project $PROJECT_ID"
    fi
}

# Print summary
print_summary() {
    echo
    print_color "$CYAN" "========================================="
    print_color "$CYAN" "  Verification Summary"
    print_color "$CYAN" "========================================="
    echo
    print_color "$CYAN" "Total checks: $TOTAL_CHECKS"
    print_color "$GREEN" "Passed: $PASSED_CHECKS"
    print_color "$YELLOW" "Warnings: $WARNING_CHECKS"
    print_color "$RED" "Failed: $FAILED_CHECKS"
    echo

    if [ $TOTAL_CHECKS -gt 0 ]; then
        local percentage=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
        print_color "$CYAN" "Success rate: ${percentage}%"
        echo
    fi

    if [ $FAILED_CHECKS -eq 0 ]; then
        if [ $WARNING_CHECKS -eq 0 ]; then
            print_color "$GREEN" "✅ All checks passed! Your GCP setup is complete."
        else
            print_color "$YELLOW" "✅ Setup is functional with $WARNING_CHECKS warnings."
        fi
    else
        print_color "$RED" "❌ Setup incomplete: $FAILED_CHECKS critical checks failed."
    fi
}

# Main function
main() {
    print_color "$CYAN" "========================================="
    print_color "$CYAN" "  GCP Setup Verification"
    print_color "$CYAN" "========================================="
    echo
    print_color "$YELLOW" "Project: $PROJECT_ID"
    print_color "$YELLOW" "Region: $REGION"
    echo

    check_prerequisites
    echo
    check_project
    echo
    check_apis
    echo
    check_authentication
    echo
    check_wif
    echo
    check_artifact_registry

    print_summary
    generate_fixes

    # Exit code based on failures
    if [ $FAILED_CHECKS -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main
