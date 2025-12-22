# GCP Authentication Reset Guide

This guide covers complete authentication reset procedures for gcloud CLI, including
credential clearing, configuration reset, and re-authentication workflows.

## When to Reset Authentication

Reset authentication when:
- Switching between accounts or organizations
- Troubleshooting permission errors
- After credential expiration or revocation
- Cleaning up stale configurations
- Moving to a new machine or environment

## Credential Locations

Understanding where gcloud stores credentials:

```
~/.config/gcloud/
├── access_tokens.db              # Cached access tokens (SQLite)
├── credentials.db                # Refresh tokens (SQLite)
├── application_default_credentials.json  # ADC file
├── properties                    # SDK properties
├── configurations/               # Named configurations
│   ├── config_default
│   └── config_production
└── legacy_credentials/           # Legacy credential files
```

## Show Current Authentication State

Before resetting, understand current state:

```bash
show_auth_state() {
    echo "Current authentication state:"
    echo

    # Active accounts
    echo "  Active account(s):"
    gcloud auth list --format="table(account, status)" 2>/dev/null || echo "    No accounts found"
    echo

    # Current configuration
    echo "  Current project: $(gcloud config get-value project 2>/dev/null || echo 'Not set')"
    echo "  Current configuration: $(gcloud config configurations list --format='value(name)' --filter='is_active=true' 2>/dev/null || echo 'default')"
    echo

    # Check for ADC
    local adc_file="$HOME/.config/gcloud/application_default_credentials.json"
    if [ -f "$adc_file" ]; then
        echo "  Application Default Credentials: Present"
        if command -v jq &> /dev/null; then
            local adc_account=$(jq -r '.client_email // .client_id // "unknown"' "$adc_file" 2>/dev/null)
            echo "    Account: $adc_account"
        fi
    else
        echo "  Application Default Credentials: Not found"
    fi
}
```

## Clear Credentials

### Revoke All Accounts

```bash
clear_credentials() {
    echo "Clearing authentication credentials..."

    # Revoke all credentials
    if gcloud auth list --format='value(account)' 2>/dev/null | grep -q .; then
        echo "  Revoking all existing credentials..."
        gcloud auth revoke --all 2>/dev/null || true
        echo "  ✅ All credentials revoked"
    else
        echo "  No credentials to revoke"
    fi
}
```

### Clear Application Default Credentials

```bash
clear_adc() {
    local adc_file="$HOME/.config/gcloud/application_default_credentials.json"
    if [ -f "$adc_file" ]; then
        echo "  Removing Application Default Credentials..."
        rm -f "$adc_file"
        echo "  ✅ ADC removed"
    else
        echo "  No ADC file found"
    fi
}
```

### Clear Token Cache

```bash
clear_token_cache() {
    local token_cache="$HOME/.config/gcloud/credentials.db"
    if [ -f "$token_cache" ]; then
        echo "  Clearing token cache..."
        rm -f "$token_cache"
        echo "  ✅ Token cache cleared"
    fi

    local access_tokens="$HOME/.config/gcloud/access_tokens.db"
    if [ -f "$access_tokens" ]; then
        echo "  Clearing access tokens..."
        rm -f "$access_tokens"
        echo "  ✅ Access tokens cleared"
    fi
}
```

### Clear Legacy Credentials

```bash
clear_legacy_credentials() {
    local legacy_dir="$HOME/.config/gcloud/legacy_credentials"
    if [ -d "$legacy_dir" ]; then
        echo "  Clearing legacy credentials..."
        rm -rf "$legacy_dir"
        echo "  ✅ Legacy credentials cleared"
    fi
}
```

## Clear Configurations

### Delete Non-Default Configurations

```bash
clear_configurations() {
    echo "Clearing gcloud configurations..."

    # List all configurations
    local configs=($(gcloud config configurations list --format='value(name)' 2>/dev/null))

    for config in "${configs[@]}"; do
        if [ "$config" != "default" ]; then
            echo "  Deleting configuration: $config"
            gcloud config configurations delete "$config" --quiet 2>/dev/null || true
        fi
    done

    # Reset default configuration
    echo "  Resetting default configuration..."
    gcloud config unset project 2>/dev/null || true
    gcloud config unset account 2>/dev/null || true
    gcloud config unset compute/zone 2>/dev/null || true
    gcloud config unset compute/region 2>/dev/null || true

    echo "  ✅ Configurations cleared"
}
```

## Re-Authentication

### Interactive Re-Authentication

```bash
re_authenticate() {
    local project_id=${1:-}

    echo "Re-authenticating with Google Cloud..."
    echo

    # Login to gcloud
    echo "Please login to your Google account:"
    gcloud auth login

    # Set project
    if [ -n "$project_id" ]; then
        echo "Setting project to: $project_id"
        gcloud config set project "$project_id"
    else
        echo "No project specified. Set it with: gcloud config set project PROJECT_ID"
    fi
}
```

### Setup Application Default Credentials

```bash
setup_adc() {
    local project_id=${1:-}

    echo "Setting up Application Default Credentials..."

    if [ -n "$project_id" ]; then
        gcloud auth application-default login --project="$project_id"
        gcloud auth application-default set-quota-project "$project_id"
    else
        gcloud auth application-default login
    fi

    echo "✅ Application Default Credentials configured"
}
```

### Configure Docker for Artifact Registry

```bash
setup_docker_auth() {
    local region=${1:-us-central1}

    echo "Configuring Docker authentication..."
    gcloud auth configure-docker "${region}-docker.pkg.dev" --quiet
    echo "✅ Docker configured for Artifact Registry"
}
```

## Complete Reset Script

```bash
#!/usr/bin/env bash
# reset-gcloud-auth.sh - Complete authentication reset

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-}"
CLEAR_CONFIGS=false
FULL_RESET=false

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

confirm() {
    local message=$1
    local default=${2:-N}

    if [ "$default" = "Y" ]; then
        read -p "$(echo -e "${YELLOW}[CONFIRM]${NC} $message [Y/n]: ")" -n 1 -r
        echo
        [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]
    else
        read -p "$(echo -e "${YELLOW}[CONFIRM]${NC} $message [y/N]: ")" -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

GCP Authentication Reset Tool

Options:
    -p, --project-id PROJECT_ID    GCP project ID to set after reset
    -c, --clear-configs            Also clear all gcloud configurations
    -f, --full-reset               Perform full reset (configs + credentials)
    -h, --help                     Show this help message

Examples:
    # Basic authentication reset
    $0

    # Full reset with specific project
    $0 --full-reset --project-id my-project

    # Clear configurations only
    $0 --clear-configs

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project-id) PROJECT_ID="$2"; shift 2 ;;
        -c|--clear-configs) CLEAR_CONFIGS=true; shift ;;
        -f|--full-reset) FULL_RESET=true; CLEAR_CONFIGS=true; shift ;;
        -h|--help) usage ;;
        *) print_error "Unknown option: $1"; usage ;;
    esac
done

main() {
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  GCP Authentication Reset Tool${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo

    # Check prerequisites
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not installed"
        exit 1
    fi

    # Show current state
    show_auth_state

    # Confirm reset
    print_warning "This will reset your GCP authentication."
    if [ "$FULL_RESET" = true ]; then
        print_warning "Full reset mode: Will clear all configurations and credentials."
    fi
    echo

    if ! confirm "Do you want to continue?"; then
        print_info "Reset cancelled."
        exit 0
    fi

    echo

    # Perform reset
    clear_credentials
    clear_adc
    clear_token_cache
    clear_legacy_credentials

    if [ "$CLEAR_CONFIGS" = true ]; then
        clear_configurations
    fi

    echo
    print_success "Authentication reset complete!"
    echo

    # Re-authentication
    if confirm "Do you want to re-authenticate now?" "Y"; then
        echo
        re_authenticate "$PROJECT_ID"

        if confirm "Set up Application Default Credentials?" "Y"; then
            setup_adc "$PROJECT_ID"
        fi

        if confirm "Configure Docker for Artifact Registry?"; then
            setup_docker_auth
        fi
    else
        print_info "You can re-authenticate later with:"
        echo -e "${CYAN}  gcloud auth login${NC}"
        echo -e "${CYAN}  gcloud auth application-default login${NC}"
    fi

    echo
    print_info "Final authentication state:"
    show_auth_state

    print_success "Reset process complete!"
}

main
```

## Quick Commands

### Quick Reset (Credentials Only)

```bash
# Revoke all and re-authenticate
gcloud auth revoke --all
gcloud auth login
gcloud auth application-default login
```

### Full Reset (Everything)

```bash
# Clear everything
gcloud auth revoke --all
rm -f ~/.config/gcloud/application_default_credentials.json
rm -f ~/.config/gcloud/credentials.db
rm -f ~/.config/gcloud/access_tokens.db
rm -rf ~/.config/gcloud/legacy_credentials

# Reset configurations
gcloud config unset project
gcloud config unset account

# Re-authenticate
gcloud auth login
gcloud config set project PROJECT_ID
gcloud auth application-default login --project=PROJECT_ID
```

### Single Account Switch

```bash
# Switch without full reset
gcloud config set account other-account@gmail.com
gcloud config set project other-project
```

## Troubleshooting

### Token Refresh Failures

```bash
# Force token refresh
gcloud auth login

# For service accounts
gcloud auth activate-service-account --key-file=key.json
```

### Permission Denied After Reset

```bash
# Verify account
gcloud auth list

# Check project permissions
gcloud projects get-iam-policy PROJECT_ID \
    --filter="bindings.members:YOUR_EMAIL"
```

### ADC Not Working

```bash
# Re-create ADC
rm -f ~/.config/gcloud/application_default_credentials.json
gcloud auth application-default login

# Verify token
gcloud auth application-default print-access-token
```
