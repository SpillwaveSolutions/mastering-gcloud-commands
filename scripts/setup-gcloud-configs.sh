#!/bin/bash
# Setup gcloud configurations for multiple environments
# Usage: ./setup-gcloud-configs.sh

set -e

echo "=== gcloud Multi-Environment Configuration Setup ==="
echo ""

# Function to create and configure a profile
create_config() {
    local config_name=$1
    local project_id=$2
    local region=$3
    local auth_type=$4  # "user" or "service-account"
    local sa_key_file=$5  # Only for service-account

    echo "Creating configuration: $config_name"

    # Create configuration
    gcloud config configurations create "$config_name" 2>/dev/null || {
        echo "  Configuration '$config_name' already exists, activating..."
    }

    gcloud config configurations activate "$config_name"

    # Set project and region
    gcloud config set project "$project_id"
    gcloud config set compute/region "$region"
    gcloud config set run/region "$region"

    # Authenticate
    if [ "$auth_type" = "service-account" ] && [ -n "$sa_key_file" ]; then
        echo "  Activating service account..."
        gcloud auth activate-service-account --key-file="$sa_key_file"
    elif [ "$auth_type" = "user" ]; then
        echo "  User authentication required..."
        gcloud auth login
    fi

    echo "  Configuration '$config_name' created successfully!"
    echo ""
}

# Interactive setup
echo "This script will help you set up multiple gcloud configurations."
echo "Press Ctrl+C to cancel at any time."
echo ""

# Development environment
read -p "Create development configuration? (y/n): " create_dev
if [ "$create_dev" = "y" ]; then
    read -p "  Development project ID: " dev_project
    read -p "  Development region [us-central1]: " dev_region
    dev_region=${dev_region:-us-central1}
    create_config "dev" "$dev_project" "$dev_region" "user"
fi

# Staging environment
read -p "Create staging configuration? (y/n): " create_staging
if [ "$create_staging" = "y" ]; then
    read -p "  Staging project ID: " staging_project
    read -p "  Staging region [us-east1]: " staging_region
    staging_region=${staging_region:-us-east1}
    create_config "staging" "$staging_project" "$staging_region" "user"
fi

# Production environment
read -p "Create production configuration? (y/n): " create_prod
if [ "$create_prod" = "y" ]; then
    read -p "  Production project ID: " prod_project
    read -p "  Production region [us-central1]: " prod_region
    prod_region=${prod_region:-us-central1}
    read -p "  Use service account for production? (y/n): " use_sa
    if [ "$use_sa" = "y" ]; then
        read -p "  Service account key file path: " sa_key
        create_config "prod" "$prod_project" "$prod_region" "service-account" "$sa_key"
    else
        create_config "prod" "$prod_project" "$prod_region" "user"
    fi
fi

# List all configurations
echo ""
echo "=== Configuration Summary ==="
gcloud config configurations list

echo ""
echo "Setup complete! Use 'gcloud config configurations activate <name>' to switch."
echo ""
echo "Quick switch commands you can add to your shell profile:"
echo "  alias gdev='gcloud config configurations activate dev'"
echo "  alias gstaging='gcloud config configurations activate staging'"
echo "  alias gprod='gcloud config configurations activate prod'"
