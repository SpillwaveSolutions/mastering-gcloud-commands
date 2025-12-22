# GCP Setup Verification Patterns

This guide covers comprehensive verification patterns for validating GCP project configurations,
ensuring all required components are properly set up before deployment.

## Verification Framework

### Counter-Based Tracking

Track verification results with pass/fail/warning counters:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Helper functions
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
```

### Summary with Success Rate

Calculate and display success percentage:

```bash
print_summary() {
    echo
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  Verification Summary${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo
    echo -e "${CYAN}Total checks: $TOTAL_CHECKS${NC}"
    echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
    echo -e "${YELLOW}Warnings: $WARNING_CHECKS${NC}"
    echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
    echo

    if [ $TOTAL_CHECKS -gt 0 ]; then
        local percentage=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
        echo -e "${CYAN}Success rate: ${percentage}%${NC}"
        echo
    fi

    # Overall status
    if [ $FAILED_CHECKS -eq 0 ]; then
        if [ $WARNING_CHECKS -eq 0 ]; then
            echo -e "${GREEN}✅ All checks passed!${NC}"
        else
            echo -e "${YELLOW}✅ Setup is functional with $WARNING_CHECKS warnings.${NC}"
        fi
    else
        echo -e "${RED}❌ Setup incomplete: $FAILED_CHECKS critical checks failed.${NC}"
    fi
}
```

## Component Verification

### Prerequisites Check

Verify required tools are installed:

```bash
check_prerequisites() {
    echo -e "${CYAN}=== Prerequisites Check ===${NC}"

    # gcloud CLI
    print_check "gcloud CLI"
    if command -v gcloud &> /dev/null; then
        print_pass
        if [ "$VERBOSE" = true ]; then
            echo "    Version: $(gcloud version --format='value(version.core)')"
        fi
    else
        print_fail "gcloud CLI not installed"
    fi

    # Docker
    print_check "Docker"
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            print_pass
        else
            print_warning "Docker installed but not running"
        fi
    else
        print_fail "Docker not installed"
    fi

    # jq (for JSON processing)
    print_check "jq"
    if command -v jq &> /dev/null; then
        print_pass
    else
        print_warning "jq not installed (optional but recommended)"
    fi

    # GitHub CLI (optional)
    print_check "GitHub CLI"
    if command -v gh &> /dev/null; then
        if gh auth status &> /dev/null; then
            print_pass
        else
            print_warning "GitHub CLI installed but not authenticated"
        fi
    else
        print_warning "GitHub CLI not installed (optional)"
    fi
}
```

### Project Verification

```bash
check_project() {
    echo -e "${CYAN}=== Project Configuration ===${NC}"

    print_check "Project exists"
    if gcloud projects describe "$PROJECT_ID" &> /dev/null; then
        print_pass
        PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
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
    if gcloud billing projects describe "$PROJECT_ID" 2>/dev/null | grep -q billingEnabled; then
        print_pass
    else
        print_warning "Could not verify billing status"
    fi
}
```

### API Verification

```bash
check_apis() {
    echo -e "${CYAN}=== API Status ===${NC}"

    local required_apis=(
        "aiplatform.googleapis.com"
        "run.googleapis.com"
        "artifactregistry.googleapis.com"
        "cloudbuild.googleapis.com"
        "iam.googleapis.com"
        "iamcredentials.googleapis.com"
        "sts.googleapis.com"
        "compute.googleapis.com"
        "storage.googleapis.com"
    )

    # Get enabled APIs once (efficient)
    local enabled_apis=$(gcloud services list --enabled \
        --format="value(config.name)" \
        --project="$PROJECT_ID" 2>/dev/null || echo "")

    for api in "${required_apis[@]}"; do
        print_check "$api"
        if echo "$enabled_apis" | grep -q "^$api$"; then
            print_pass
        else
            print_fail "API not enabled"
        fi
    done
}
```

### Service Account Verification

```bash
check_service_accounts() {
    echo -e "${CYAN}=== Service Accounts ===${NC}"

    local service_accounts=(
        "github-deploy-sa"
        "api-runtime-sa"
        "scheduler-sa"
    )

    # Get existing accounts once (efficient)
    local existing_accounts=$(gcloud iam service-accounts list \
        --format="value(email)" \
        --project="$PROJECT_ID" 2>/dev/null || echo "")

    for sa in "${service_accounts[@]}"; do
        print_check "$sa"
        if echo "$existing_accounts" | grep -q "^${sa}@"; then
            print_pass
            if [ "$VERBOSE" = true ]; then
                echo "    Email: ${sa}@${PROJECT_ID}.iam.gserviceaccount.com"
            fi
        else
            print_fail "Service account not found"
        fi
    done
}
```

### IAM Permissions Verification

```bash
check_iam_permissions() {
    echo -e "${CYAN}=== IAM Permissions ===${NC}"

    print_check "Deployer service account roles"

    local sa_email="github-deploy-sa@${PROJECT_ID}.iam.gserviceaccount.com"
    local assigned_roles=$(gcloud projects get-iam-policy "$PROJECT_ID" \
        --flatten="bindings[].members" \
        --filter="bindings.members:serviceAccount:${sa_email}" \
        --format="value(bindings.role)" 2>/dev/null || echo "")

    local required_roles=(
        "roles/run.admin"
        "roles/artifactregistry.writer"
        "roles/iam.serviceAccountUser"
    )

    local missing_roles=0
    for role in "${required_roles[@]}"; do
        if ! echo "$assigned_roles" | grep -q "$role"; then
            ((missing_roles++))
        fi
    done

    if [ $missing_roles -eq 0 ]; then
        print_pass
    else
        print_warning "$missing_roles required roles missing"
    fi
}
```

### Workload Identity Federation Verification

```bash
check_wif() {
    echo -e "${CYAN}=== Workload Identity Federation ===${NC}"

    print_check "WIF pool exists"
    if gcloud iam workload-identity-pools describe github-pool \
        --location=global \
        --project="$PROJECT_ID" &> /dev/null; then
        print_pass
    else
        print_fail "WIF pool not found"
        return
    fi

    print_check "WIF provider exists"
    if gcloud iam workload-identity-pools providers describe github-provider \
        --workload-identity-pool=github-pool \
        --location=global \
        --project="$PROJECT_ID" &> /dev/null; then
        print_pass
    else
        print_fail "WIF provider not found"
        return
    fi

    print_check "Service account WIF binding"
    local sa_policy=$(gcloud iam service-accounts get-iam-policy \
        "github-deploy-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
        --format=json \
        --project="$PROJECT_ID" 2>/dev/null || echo "{}")

    if echo "$sa_policy" | grep -q "workloadIdentityUser"; then
        print_pass
    else
        print_fail "WIF binding not configured"
    fi
}
```

### Artifact Registry Verification

```bash
check_artifact_registry() {
    echo -e "${CYAN}=== Artifact Registry ===${NC}"

    print_check "Repository exists"
    if gcloud artifacts repositories describe my-containers \
        --location="$REGION" \
        --project="$PROJECT_ID" &> /dev/null; then
        print_pass
    else
        print_fail "Repository not found"
    fi

    print_check "Docker authentication"
    local docker_config="$HOME/.docker/config.json"
    if [ -f "$docker_config" ]; then
        if grep -q "${REGION}-docker.pkg.dev" "$docker_config"; then
            print_pass
        else
            print_warning "Docker not configured for ${REGION}-docker.pkg.dev"
        fi
    else
        print_warning "Docker config not found"
    fi
}
```

### Authentication Status Verification

```bash
check_authentication() {
    echo -e "${CYAN}=== Authentication Status ===${NC}"

    print_check "gcloud authentication"
    if gcloud auth list --filter="status:ACTIVE" --format="value(account)" | grep -q .; then
        print_pass
        if [ "$VERBOSE" = true ]; then
            echo "    Active account: $(gcloud config get-value account)"
        fi
    else
        print_fail "Not authenticated with gcloud"
    fi

    print_check "Application Default Credentials"
    if [ -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
        print_pass
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
```

## Fix Suggestions

Generate actionable fix suggestions:

```bash
generate_fixes() {
    if [ $FAILED_CHECKS -eq 0 ] && [ $WARNING_CHECKS -eq 0 ]; then
        return
    fi

    echo -e "${CYAN}\n=== Suggested Fixes ===${NC}"

    if [ $FAILED_CHECKS -gt 0 ]; then
        echo -e "${YELLOW}To fix failed checks:${NC}"
        echo "  ./scripts/setup-gcp.sh --full-setup"
        echo
    fi

    if [ $WARNING_CHECKS -gt 0 ]; then
        echo -e "${YELLOW}For optional components:${NC}"
        echo "  - Configure Docker: gcloud auth configure-docker ${REGION}-docker.pkg.dev"
        echo "  - Set up ADC: gcloud auth application-default login"
        echo "  - Install GitHub CLI: brew install gh"
    fi
}
```

## Complete Verification Script Structure

```bash
#!/usr/bin/env bash
# verify-gcp-setup.sh - Complete GCP setup verification

set -euo pipefail

# Configuration with defaults
PROJECT_ID="${GCP_PROJECT_ID:-my-project}"
REGION="${GCP_REGION:-us-central1}"
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project-id) PROJECT_ID="$2"; shift 2 ;;
        -r|--region) REGION="$2"; shift 2 ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Include all functions above, then:

main() {
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  GCP Setup Verification${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo
    echo -e "${YELLOW}Project: $PROJECT_ID${NC}"
    echo -e "${YELLOW}Region: $REGION${NC}"
    echo

    check_prerequisites
    echo
    check_project
    echo
    check_apis
    echo
    check_service_accounts
    echo
    check_iam_permissions
    echo
    check_wif
    echo
    check_artifact_registry
    echo
    check_authentication

    print_summary
    generate_fixes

    # Exit code based on failures
    [ $FAILED_CHECKS -eq 0 ]
}

main
```

## Best Practices

1. **Batch API calls** - Get lists once, then check in-memory
2. **Use verbose mode** - Add detailed output behind `$VERBOSE` flag
3. **Distinguish warnings from failures** - Not all issues are critical
4. **Provide actionable fixes** - Tell users exactly what to run
5. **Exit codes matter** - Return non-zero when critical checks fail
6. **Check prerequisites first** - Fail fast if required tools are missing
