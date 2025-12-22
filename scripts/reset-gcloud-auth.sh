#!/usr/bin/env bash
# reset-gcloud-auth.sh
# Complete authentication reset utility for gcloud CLI
# Part of gcloud-expert skill

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"
CLEAR_CONFIGS=false
FULL_RESET=false

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

# Function to confirm action
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

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

GCP Authentication Reset Tool

Options:
    -p, --project-id PROJECT_ID    GCP project ID to set after reset
    -r, --region REGION            GCP region (default: us-central1)
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
        -c|--clear-configs)
            CLEAR_CONFIGS=true
            shift
            ;;
        -f|--full-reset)
            FULL_RESET=true
            CLEAR_CONFIGS=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Function to show current auth state
show_auth_state() {
    print_info "Current authentication state:"
    echo

    echo "  Active account(s):"
    gcloud auth list --format="table(account, status)" 2>/dev/null || echo "    No accounts found"
    echo

    echo "  Current project: $(gcloud config get-value project 2>/dev/null || echo 'Not set')"
    echo "  Current region: $(gcloud config get-value compute/region 2>/dev/null || echo 'Not set')"
    echo "  Current configuration: $(gcloud config configurations list --format='value(name)' --filter='is_active=true' 2>/dev/null || echo 'default')"
    echo

    # Check for ADC
    local adc_file="$HOME/.config/gcloud/application_default_credentials.json"
    if [ -f "$adc_file" ]; then
        echo "  Application Default Credentials: Present"
        if command -v jq &> /dev/null; then
            local adc_account=$(jq -r '.client_email // .client_id // "user credentials"' "$adc_file" 2>/dev/null)
            echo "    Account: $adc_account"
        fi
    else
        echo "  Application Default Credentials: Not found"
    fi
    echo
}

# Function to clear credentials
clear_credentials() {
    print_info "Clearing authentication credentials..."

    # Revoke all credentials
    if gcloud auth list --format='value(account)' 2>/dev/null | grep -q .; then
        print_info "  Revoking all existing credentials..."
        gcloud auth revoke --all 2>/dev/null || true
        print_success "  All credentials revoked"
    else
        print_info "  No credentials to revoke"
    fi

    # Clear Application Default Credentials
    local adc_file="$HOME/.config/gcloud/application_default_credentials.json"
    if [ -f "$adc_file" ]; then
        print_info "  Removing Application Default Credentials..."
        rm -f "$adc_file"
        print_success "  Application Default Credentials removed"
    else
        print_info "  No Application Default Credentials file found"
    fi

    # Clear access token cache
    local token_cache="$HOME/.config/gcloud/credentials.db"
    if [ -f "$token_cache" ]; then
        print_info "  Clearing token cache..."
        rm -f "$token_cache"
        print_success "  Token cache cleared"
    fi

    # Clear access tokens
    local access_tokens="$HOME/.config/gcloud/access_tokens.db"
    if [ -f "$access_tokens" ]; then
        print_info "  Clearing access tokens..."
        rm -f "$access_tokens"
        print_success "  Access tokens cleared"
    fi

    # Clear legacy credentials
    local legacy_dir="$HOME/.config/gcloud/legacy_credentials"
    if [ -d "$legacy_dir" ]; then
        print_info "  Clearing legacy credentials..."
        rm -rf "$legacy_dir"
        print_success "  Legacy credentials cleared"
    fi
}

# Function to clear configurations
clear_configurations() {
    print_info "Clearing gcloud configurations..."

    # List all configurations
    local configs
    configs=($(gcloud config configurations list --format='value(name)' 2>/dev/null || echo "default"))

    for config in "${configs[@]}"; do
        if [ "$config" != "default" ]; then
            print_info "  Deleting configuration: $config"
            gcloud config configurations delete "$config" --quiet 2>/dev/null || true
        fi
    done

    # Reset default configuration
    print_info "  Resetting default configuration..."
    gcloud config unset project 2>/dev/null || true
    gcloud config unset account 2>/dev/null || true
    gcloud config unset compute/zone 2>/dev/null || true
    gcloud config unset compute/region 2>/dev/null || true

    print_success "  Configurations cleared"
}

# Function to re-authenticate
re_authenticate() {
    print_info "Re-authenticating with Google Cloud..."
    echo

    # Login to gcloud
    print_info "Please login to your Google account:"
    gcloud auth login

    # Set project if provided
    if [ -n "$PROJECT_ID" ]; then
        print_info "Setting project to: $PROJECT_ID"
        gcloud config set project "$PROJECT_ID"
    else
        print_warning "No project specified. Set it with: gcloud config set project PROJECT_ID"
    fi

    # Set region
    if [ -n "$REGION" ]; then
        print_info "Setting region to: $REGION"
        gcloud config set compute/region "$REGION"
    fi
}

# Function to setup ADC
setup_adc() {
    print_info "Setting up Application Default Credentials..."

    if [ -n "$PROJECT_ID" ]; then
        gcloud auth application-default login --project="$PROJECT_ID"
        gcloud auth application-default set-quota-project "$PROJECT_ID"
    else
        gcloud auth application-default login
    fi

    print_success "Application Default Credentials configured"
}

# Function to setup Docker
setup_docker() {
    print_info "Configuring Docker authentication for Artifact Registry..."
    gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
    print_success "Docker configured for ${REGION}-docker.pkg.dev"
}

# Main function
main() {
    print_color "$CYAN" "========================================="
    print_color "$CYAN" "  GCP Authentication Reset Tool"
    print_color "$CYAN" "========================================="
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
    elif [ "$CLEAR_CONFIGS" = true ]; then
        print_warning "Will clear configurations in addition to credentials."
    fi
    echo

    if ! confirm "Do you want to continue?"; then
        print_info "Reset cancelled."
        exit 0
    fi

    echo

    # Perform reset
    clear_credentials

    if [ "$CLEAR_CONFIGS" = true ]; then
        echo
        clear_configurations
    fi

    echo
    print_success "Authentication reset complete!"
    echo

    # Ask about re-authentication
    if confirm "Do you want to re-authenticate now?" "Y"; then
        echo
        re_authenticate

        echo
        if confirm "Set up Application Default Credentials?" "Y"; then
            setup_adc
        fi

        echo
        if confirm "Configure Docker for Artifact Registry?"; then
            setup_docker
        fi
    else
        print_info "You can re-authenticate later with:"
        print_color "$CYAN" "  gcloud auth login"
        print_color "$CYAN" "  gcloud auth application-default login"
    fi

    echo
    print_info "Final authentication state:"
    show_auth_state

    print_success "Reset process complete!"
}

# Run main function
main
