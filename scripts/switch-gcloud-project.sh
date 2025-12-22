#!/usr/bin/env bash
# switch-gcloud-project.sh
# Multi-project management utility with JSON configuration storage
# Part of gcloud-expert skill

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CONFIG_FILE="$HOME/.gcloud-projects.json"
DEFAULT_REGION="us-central1"

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

# Check prerequisites
check_prerequisites() {
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not installed"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_error "jq is required for configuration management"
        print_info "Install with: brew install jq"
        exit 1
    fi
}

# Initialize config file
init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
{
  "projects": {}
}
EOF
        print_info "Created configuration file: $CONFIG_FILE"
    fi
}

# Usage function
usage() {
    cat << EOF
Usage: $0 COMMAND [OPTIONS]

Multi-project management utility for gcloud

Commands:
    switch PROJECT_ID          Switch to a specific project
    list                       List all configured projects
    add PROJECT_ID            Add a new project configuration
    remove PROJECT_ID         Remove a project configuration
    status                    Show current GCP status
    save                      Save current configuration
    load PROJECT_ID           Load saved configuration

Options:
    -r, --region REGION       Set region for project (default: us-central1)
    -d, --description DESC    Description for the project (with add)
    --adc                     Also update Application Default Credentials
    --docker                  Configure Docker for Artifact Registry
    -h, --help               Show this help message

Examples:
    # Switch to a project
    $0 switch my-project

    # Switch and update ADC
    $0 switch my-project --adc

    # Add a new project
    $0 add my-project --region us-east1 --description "My Project"

    # List all configured projects
    $0 list

    # Show current status
    $0 status

    # Save current gcloud config
    $0 save

    # Load saved config for a project
    $0 load my-project

EOF
    exit 0
}

# List projects
cmd_list() {
    init_config

    print_color "$CYAN" "=== Configured Projects ==="
    echo

    if [ -s "$CONFIG_FILE" ]; then
        local count=$(jq '.projects | length' "$CONFIG_FILE")
        if [ "$count" -gt 0 ]; then
            jq -r '.projects | to_entries[] | "  \(.key): \(.value.description // "No description") [\(.value.region // "no region")]"' "$CONFIG_FILE"
        else
            echo "  No projects configured"
        fi
    else
        echo "  No projects configured"
    fi

    echo
    print_color "$CYAN" "=== Available GCP Projects ==="
    echo
    gcloud projects list --format="table(projectId, name)" 2>/dev/null || \
        print_warning "Could not list GCP projects (check authentication)"
}

# Add project
cmd_add() {
    local project_id=$1
    local region=${REGION:-$DEFAULT_REGION}
    local description=${DESCRIPTION:-""}

    init_config

    # Check if project exists in GCP
    if ! gcloud projects describe "$project_id" &> /dev/null; then
        print_warning "Project $project_id not found in GCP"
        read -p "Add anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    # Add to config
    local tmp_file=$(mktemp)
    jq --arg proj "$project_id" \
       --arg reg "$region" \
       --arg desc "$description" \
       '.projects[$proj] = {region: $reg, description: $desc, account: ""}' \
       "$CONFIG_FILE" > "$tmp_file" && mv "$tmp_file" "$CONFIG_FILE"

    print_success "Added project: $project_id"
    print_info "  Region: $region"
    [ -n "$description" ] && print_info "  Description: $description"
}

# Remove project
cmd_remove() {
    local project_id=$1

    init_config

    # Check if exists
    if ! jq -e --arg proj "$project_id" '.projects[$proj]' "$CONFIG_FILE" > /dev/null 2>&1; then
        print_error "Project $project_id not in configuration"
        exit 1
    fi

    # Remove from config
    local tmp_file=$(mktemp)
    jq --arg proj "$project_id" 'del(.projects[$proj])' "$CONFIG_FILE" > "$tmp_file" && mv "$tmp_file" "$CONFIG_FILE"

    print_success "Removed project: $project_id"
}

# Show status
cmd_status() {
    print_color "$CYAN" "=== Current GCP Configuration ==="
    echo

    # Current settings
    local current_project=$(gcloud config get-value project 2>/dev/null || echo "Not set")
    local current_account=$(gcloud config get-value account 2>/dev/null || echo "Not set")
    local current_region=$(gcloud config get-value compute/region 2>/dev/null || echo "Not set")
    local active_config=$(gcloud config configurations list --format='value(name)' --filter='is_active=true' 2>/dev/null || echo "default")

    print_info "Project: $current_project"
    print_info "Account: $current_account"
    print_info "Region: $current_region"
    print_info "Configuration: $active_config"

    echo
    print_color "$CYAN" "=== Authentication Status ==="
    echo

    gcloud auth list --format="table(account, status)" 2>/dev/null || echo "  No accounts authenticated"

    # Check ADC
    echo
    if [ -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
        print_info "Application Default Credentials: Present"
        local adc_project=$(jq -r '.quota_project_id // "Not set"' "$HOME/.config/gcloud/application_default_credentials.json" 2>/dev/null)
        print_info "  Quota Project: $adc_project"
    else
        print_info "Application Default Credentials: Not configured"
    fi

    # Check Docker
    echo
    print_color "$CYAN" "=== Docker Configuration ==="
    if [ -f "$HOME/.docker/config.json" ] && grep -q "docker.pkg.dev" "$HOME/.docker/config.json" 2>/dev/null; then
        print_info "Artifact Registry authentication: Configured"
    else
        print_info "Artifact Registry authentication: Not configured"
    fi
}

# Switch project
cmd_switch() {
    local project_id=$1

    print_info "Switching to project: $project_id"

    # Set project
    if ! gcloud config set project "$project_id" 2>/dev/null; then
        print_error "Failed to set project"
        exit 1
    fi

    # Get region from config if available
    local region=${REGION:-}
    if [ -z "$region" ] && [ -f "$CONFIG_FILE" ]; then
        region=$(jq -r --arg proj "$project_id" '.projects[$proj].region // ""' "$CONFIG_FILE" 2>/dev/null)
    fi

    # Set region if available
    if [ -n "$region" ]; then
        print_info "Setting region: $region"
        gcloud config set compute/region "$region"
    fi

    # Update .env file if it exists
    if [ -f ".env" ]; then
        print_info "Updating .env file..."
        if grep -q "^GCP_PROJECT_ID=" .env 2>/dev/null; then
            sed -i.bak "s/^GCP_PROJECT_ID=.*/GCP_PROJECT_ID=$project_id/" .env
        fi
        if [ -n "$region" ] && grep -q "^GCP_REGION=" .env 2>/dev/null; then
            sed -i.bak "s/^GCP_REGION=.*/GCP_REGION=$region/" .env
        fi
        rm -f .env.bak
        print_success ".env file updated"
    fi

    # Update ADC if requested
    if [ "${UPDATE_ADC:-false}" = true ]; then
        print_info "Updating Application Default Credentials..."
        gcloud auth application-default login --project="$project_id" --quiet 2>/dev/null || \
            gcloud auth application-default login --project="$project_id"
        gcloud auth application-default set-quota-project "$project_id"
        print_success "ADC updated"
    fi

    # Configure Docker if requested
    if [ "${CONFIGURE_DOCKER:-false}" = true ] && [ -n "$region" ]; then
        print_info "Configuring Docker for Artifact Registry..."
        gcloud auth configure-docker "${region}-docker.pkg.dev" --quiet
        print_success "Docker configured"
    fi

    print_success "Switched to project: $project_id"

    echo
    cmd_status
}

# Save current configuration
cmd_save() {
    local project_id=$(gcloud config get-value project 2>/dev/null)
    local region=$(gcloud config get-value compute/region 2>/dev/null)
    local account=$(gcloud config get-value account 2>/dev/null)

    if [ -z "$project_id" ]; then
        print_error "No active project to save"
        exit 1
    fi

    init_config

    # Update config
    local tmp_file=$(mktemp)
    jq --arg proj "$project_id" \
       --arg reg "$region" \
       --arg acc "$account" \
       '.projects[$proj] = (.projects[$proj] // {}) + {region: $reg, account: $acc}' \
       "$CONFIG_FILE" > "$tmp_file" && mv "$tmp_file" "$CONFIG_FILE"

    print_success "Saved configuration for: $project_id"
    print_info "  Region: $region"
    print_info "  Account: $account"
}

# Load saved configuration
cmd_load() {
    local project_id=$1

    init_config

    # Get saved config
    local config=$(jq -r --arg proj "$project_id" '.projects[$proj] // {}' "$CONFIG_FILE")

    if [ "$config" = "{}" ]; then
        print_error "No saved configuration for: $project_id"
        exit 1
    fi

    local region=$(echo "$config" | jq -r '.region // ""')
    local account=$(echo "$config" | jq -r '.account // ""')

    # Set options from saved config
    REGION="$region"

    # Switch to project
    cmd_switch "$project_id"
}

# Main function
main() {
    check_prerequisites

    # Parse command
    COMMAND=${1:-status}
    shift || true

    # Parse options
    UPDATE_ADC=false
    CONFIGURE_DOCKER=false
    REGION=""
    DESCRIPTION=""
    PROJECT_ARG=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -d|--description)
                DESCRIPTION="$2"
                shift 2
                ;;
            --adc)
                UPDATE_ADC=true
                shift
                ;;
            --docker)
                CONFIGURE_DOCKER=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                ;;
            *)
                PROJECT_ARG="$1"
                shift
                ;;
        esac
    done

    # Execute command
    case $COMMAND in
        switch)
            if [ -z "$PROJECT_ARG" ]; then
                print_error "Project ID required"
                usage
            fi
            cmd_switch "$PROJECT_ARG"
            ;;
        list)
            cmd_list
            ;;
        add)
            if [ -z "$PROJECT_ARG" ]; then
                print_error "Project ID required"
                usage
            fi
            cmd_add "$PROJECT_ARG"
            ;;
        remove)
            if [ -z "$PROJECT_ARG" ]; then
                print_error "Project ID required"
                usage
            fi
            cmd_remove "$PROJECT_ARG"
            ;;
        status)
            cmd_status
            ;;
        save)
            cmd_save
            ;;
        load)
            if [ -z "$PROJECT_ARG" ]; then
                print_error "Project ID required"
                usage
            fi
            cmd_load "$PROJECT_ARG"
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            usage
            ;;
    esac
}

# Run main function
main "$@"
