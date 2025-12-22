# Google Cloud CLI Authentication

This guide covers all authentication methods for gcloud CLI, from interactive browser login
to service accounts and Workload Identity Federation.

## Authentication Methods Overview

| Method | Use Case | Security Level |
|--------|----------|----------------|
| Browser Login | Interactive development | High (uses MFA) |
| Service Account Key | Legacy automation | Medium (key exposure risk) |
| Service Account Impersonation | Secure automation | High (short-lived tokens) |
| Workload Identity Federation | CI/CD pipelines | Highest (keyless) |

## User Authentication (OAuth 2.0)

### Standard Browser Login

For interactive use on local workstations:

```bash
# Opens browser for authentication
gcloud auth login

# Verify logged in accounts
gcloud auth list
```

The login flow:
1. Opens default browser to Google sign-in
2. User authenticates (including MFA if configured)
3. Refresh token stored locally in `~/.config/gcloud/`

### Remote/SSH Session Login

When browser access is unavailable:

```bash
gcloud auth login --no-launch-browser
```

This provides a URL to copy to another machine's browser, then paste the authorization code back.

### Application Default Credentials (ADC)

For local development with client libraries:

```bash
# Set up ADC for local code
gcloud auth application-default login

# Verify ADC
gcloud auth application-default print-access-token
```

**Important**: ADC is separate from gcloud's own auth. Use it when:
- Running Python/Go/Java code locally that uses Google Cloud client libraries
- Testing Terraform with Google provider
- Running local development servers

### Managing Multiple User Accounts

```bash
# List all authenticated accounts
gcloud auth list

# OUTPUT:
# Credentialed Accounts
# ACTIVE  ACCOUNT
# *       user1@example.com
#         user2@example.com

# Switch active account
gcloud config set account user2@example.com

# Revoke specific account
gcloud auth revoke user1@example.com

# Revoke all accounts
gcloud auth revoke --all
```

## Service Account Authentication

Service accounts are non-human identities for automation and services.

### Creating Service Accounts

```bash
# Create service account
gcloud iam service-accounts create my-service-account \
  --display-name="My Service Account" \
  --description="Used for CI/CD deployments"

# List service accounts
gcloud iam service-accounts list

# Get service account email
# Format: NAME@PROJECT_ID.iam.gserviceaccount.com
```

### Key-Based Authentication (Use Sparingly)

**Security Warning**: JSON keys are long-lived credentials. Prefer impersonation or Workload Identity.

```bash
# Create and download key
gcloud iam service-accounts keys create ~/keys/sa-key.json \
  --iam-account=my-sa@PROJECT_ID.iam.gserviceaccount.com

# Set restrictive permissions
chmod 600 ~/keys/sa-key.json

# Activate service account
gcloud auth activate-service-account \
  my-sa@PROJECT_ID.iam.gserviceaccount.com \
  --key-file=~/keys/sa-key.json

# Alternative: use login with cred-file (newer method)
gcloud auth login --cred-file=~/keys/sa-key.json
```

### Key Management Best Practices

```bash
# List keys for service account
gcloud iam service-accounts keys list \
  --iam-account=my-sa@PROJECT_ID.iam.gserviceaccount.com

# Delete old/compromised keys
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=my-sa@PROJECT_ID.iam.gserviceaccount.com

# Set key expiration (organization policy)
# Requires Org Admin - keys auto-expire after configured period
```

## Service Account Impersonation (Recommended)

Impersonation allows using service account permissions without managing keys.

### Setting Up Impersonation

```bash
# Grant user permission to impersonate
gcloud iam service-accounts add-iam-policy-binding \
  my-sa@PROJECT_ID.iam.gserviceaccount.com \
  --member="user:developer@example.com" \
  --role="roles/iam.serviceAccountTokenCreator"
```

### Using Impersonation

```bash
# Single command with impersonation
gcloud compute instances list \
  --impersonate-service-account=my-sa@PROJECT_ID.iam.gserviceaccount.com

# Set as default for configuration
gcloud config set auth/impersonate_service_account \
  my-sa@PROJECT_ID.iam.gserviceaccount.com

# All subsequent commands use impersonated identity
gcloud storage buckets list  # Uses my-sa permissions

# Clear impersonation
gcloud config unset auth/impersonate_service_account
```

### Benefits of Impersonation

1. **No keys to manage**: Eliminates key rotation requirements
2. **Short-lived tokens**: Credentials expire quickly
3. **Audit trail**: Clear record of who impersonated what
4. **Revocable access**: Remove impersonation permission to revoke

## Workload Identity Federation (WIF)

WIF enables external identities (GitHub, AWS, Azure, etc.) to access GCP without keys.

### Create Workload Identity Pool

```bash
# Create identity pool
gcloud iam workload-identity-pools create "github-pool" \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --description="Pool for GitHub Actions workflows"

# Get pool name for later use
gcloud iam workload-identity-pools describe "github-pool" \
  --location="global" \
  --format="value(name)"
```

### Create OIDC Provider for GitHub

```bash
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --workload-identity-pool="github-pool" \
  --location="global" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --allowed-audiences="https://github.com/OWNER" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == 'YOUR_GITHUB_ORG'"
```

### Grant Service Account Access

```bash
# Get the principal identifier
PROJECT_NUMBER=$(gcloud projects describe PROJECT_ID --format='value(projectNumber)')

# Grant service account impersonation to GitHub repo
gcloud iam service-accounts add-iam-policy-binding \
  deploy-sa@PROJECT_ID.iam.gserviceaccount.com \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/OWNER/REPO" \
  --role="roles/iam.workloadIdentityUser"
```

### GitHub Actions Configuration

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write  # Required for WIF

    steps:
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
          service_account: 'deploy-sa@PROJECT_ID.iam.gserviceaccount.com'

      - uses: google-github-actions/setup-gcloud@v2

      - run: gcloud run deploy ...
```

## Environment Variables

```bash
# Application Default Credentials file
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json

# Force specific Python
export CLOUDSDK_PYTHON=/usr/bin/python3.11

# Disable prompts in scripts
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

# Set active configuration
export CLOUDSDK_ACTIVE_CONFIG_NAME=production
```

## Credential Storage

Credentials are stored in `~/.config/gcloud/`:

```
~/.config/gcloud/
├── access_tokens.db       # Cached access tokens (SQLite)
├── credentials.db         # Refresh tokens (SQLite)
├── properties             # SDK properties
├── configurations/        # Named configurations
│   ├── config_default
│   └── config_production
└── legacy_credentials/    # Legacy credential files
```

## Idempotent Service Account Creation

When scripting service account creation, use check-before-create patterns for safe re-execution:

### Check If Service Account Exists

```bash
# Check before creating
sa_exists() {
    local sa_name=$1
    local project_id=$2
    gcloud iam service-accounts describe \
        "${sa_name}@${project_id}.iam.gserviceaccount.com" \
        --project="$project_id" &> /dev/null
}

# Idempotent create
create_service_account_if_not_exists() {
    local sa_name=$1
    local project_id=$2
    local display_name=${3:-$sa_name}

    if sa_exists "$sa_name" "$project_id"; then
        echo "  ✓ Service account $sa_name already exists"
        return 0
    fi

    echo "  Creating service account $sa_name..."
    gcloud iam service-accounts create "$sa_name" \
        --display-name="$display_name" \
        --project="$project_id"
}
```

### Idempotent IAM Binding

```bash
# Check if role is already granted (avoids duplicate bindings)
has_role() {
    local member=$1
    local role=$2
    local project_id=$3

    gcloud projects get-iam-policy "$project_id" \
        --flatten="bindings[].members" \
        --filter="bindings.role:$role AND bindings.members:$member" \
        --format="value(bindings.role)" 2>/dev/null | grep -q .
}

# Grant role only if not present
grant_role_if_needed() {
    local member=$1
    local role=$2
    local project_id=$3

    if has_role "$member" "$role" "$project_id"; then
        echo "  ✓ $role already granted"
        return 0
    fi

    echo "  Granting $role..."
    gcloud projects add-iam-policy-binding "$project_id" \
        --member="$member" \
        --role="$role" \
        --condition=None \
        --quiet
}
```

### Complete Idempotent Setup Script

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:-$(gcloud config get-value project)}"
SA_NAME="my-service-account"

# Check and create
if ! sa_exists "$SA_NAME" "$PROJECT_ID"; then
    gcloud iam service-accounts create "$SA_NAME" \
        --display-name="My Service Account" \
        --project="$PROJECT_ID"
    echo "Created service account: $SA_NAME"
else
    echo "Service account already exists: $SA_NAME"
fi

# Grant roles idempotently
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
for role in "roles/run.invoker" "roles/storage.objectViewer"; do
    grant_role_if_needed "serviceAccount:$SA_EMAIL" "$role" "$PROJECT_ID"
done
```

## ADC File Locations and Cleanup

Application Default Credentials are stored in specific locations:

### ADC File Locations

```
~/.config/gcloud/
├── application_default_credentials.json  # Main ADC file
├── access_tokens.db                      # Cached access tokens (SQLite)
├── credentials.db                        # Refresh tokens (SQLite)
└── legacy_credentials/                   # Legacy credential files
```

### Checking ADC Status

```bash
# Check if ADC exists
if [ -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
    echo "ADC configured"

    # Check quota project (if jq available)
    if command -v jq &> /dev/null; then
        jq -r '.quota_project_id // "not set"' \
            "$HOME/.config/gcloud/application_default_credentials.json"
    fi
else
    echo "ADC not configured"
fi
```

### Clearing ADC and Credentials

```bash
# Clear ADC only
rm -f "$HOME/.config/gcloud/application_default_credentials.json"

# Clear all cached tokens
rm -f "$HOME/.config/gcloud/access_tokens.db"
rm -f "$HOME/.config/gcloud/credentials.db"

# Clear legacy credentials
rm -rf "$HOME/.config/gcloud/legacy_credentials/"

# Complete credential reset (use reset script)
# See: scripts/reset-gcloud-auth.sh
```

### Setting ADC Quota Project

```bash
# Set quota project for ADC
gcloud auth application-default set-quota-project PROJECT_ID

# Verify quota project
gcloud auth application-default print-access-token 2>&1 | head -1
```

## Security Best Practices

1. **Use impersonation over keys** whenever possible
2. **Implement WIF for CI/CD** - eliminates key management
3. **Set key expiration policies** at organization level
4. **Never commit keys to git** - use `.gitignore`
5. **Rotate keys regularly** if keys are required
6. **Audit auth logs** via Cloud Logging
7. **Use short-lived tokens** via impersonation
8. **Restrict service account permissions** to least privilege
9. **Use idempotent scripts** - check-before-create patterns
10. **Clean up credentials** when switching projects or troubleshooting

## Troubleshooting

### "Permission denied" Errors

```bash
# Verify active account
gcloud auth list

# Check account has required roles
gcloud projects get-iam-policy PROJECT_ID \
  --filter="bindings.members:ACCOUNT_EMAIL"
```

### Token Refresh Failures

```bash
# Re-authenticate
gcloud auth login

# For service accounts, re-activate
gcloud auth activate-service-account --key-file=key.json
```

### ADC Not Working with Client Libraries

```bash
# Ensure ADC is set up
gcloud auth application-default login

# Verify token works
gcloud auth application-default print-access-token

# Check GOOGLE_APPLICATION_CREDENTIALS
echo $GOOGLE_APPLICATION_CREDENTIALS
```
