# Google Cloud CLI Installation on macOS

This guide covers installation of the Google Cloud CLI (gcloud) on macOS, including considerations
for Apple Silicon and Python runtime dependencies.

## Prerequisites

### Python Runtime Foundation

The gcloud CLI requires Python 3.9–3.14. Verify your Python version:

```bash
python3 --version
```

**Important**: Avoid relying on system Python. Use a version manager like `pyenv` or Homebrew:

```bash
# Using Homebrew
brew install python@3.11

# Using pyenv
pyenv install 3.11.6
pyenv global 3.11.6
```

### Xcode Command Line Tools

Required for some components:

```bash
xcode-select --install
```

### Apple Silicon Considerations

For M1/M2/M3 Macs, ensure Rosetta 2 is installed for x86_64 binary compatibility:

```bash
softwareupdate --install-rosetta
```

Modern gcloud releases include native ARM64 binaries for most components.

## Installation Methods

### Method 1: Homebrew (Recommended)

The simplest installation method:

```bash
# Update Homebrew
brew update

# Install gcloud CLI
brew install --cask google-cloud-sdk

# Verify installation
gcloud --version
```

**Note**: When installed via Homebrew, the internal component manager is disabled. Use Homebrew for updates:

```bash
brew upgrade --cask google-cloud-sdk
```

### Method 2: Interactive Script Installation

For more control over the installation:

```bash
# Download and run the installer
curl https://sdk.cloud.google.com | bash

# Restart shell or source the profile
exec -l $SHELL

# Initialize
gcloud init
```

The installer:
1. Detects OS and architecture (Darwin, arm64/x86_64)
2. Extracts SDK to `~/google-cloud-sdk`
3. Modifies shell profile for PATH updates
4. Enables command autocompletion

### Method 3: Versioned Archive (Deterministic)

For reproducible environments in CI/CD or team settings:

```bash
# Download specific version
VERSION="450.0.0"
ARCH="arm"  # or "x86_64" for Intel

curl -O "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${VERSION}-darwin-${ARCH}.tar.gz"

# Extract to specific location
sudo tar -xzf google-cloud-cli-*.tar.gz -C /opt/

# Run install script
/opt/google-cloud-sdk/install.sh --quiet

# Add to PATH
echo 'source /opt/google-cloud-sdk/path.zsh.inc' >> ~/.zshrc
echo 'source /opt/google-cloud-sdk/completion.zsh.inc' >> ~/.zshrc
```

## Shell Integration

### Zsh (macOS default since Catalina)

The installer modifies `~/.zshrc`. Verify these lines are present:

```bash
# The next line updates PATH for the Google Cloud SDK.
if [ -f '/path/to/google-cloud-sdk/path.zsh.inc' ]; then . '/path/to/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/path/to/google-cloud-sdk/completion.zsh.inc' ]; then . '/path/to/google-cloud-sdk/completion.zsh.inc'; fi
```

### Bash

For Bash users, add to `~/.bash_profile` or `~/.bashrc`:

```bash
source '/path/to/google-cloud-sdk/path.bash.inc'
source '/path/to/google-cloud-sdk/completion.bash.inc'
```

### Oh My Zsh Considerations

If using Oh My Zsh, add the gcloud plugin to `~/.zshrc`:

```bash
plugins=(... gcloud)
```

Or ensure the SDK path is sourced before Oh My Zsh initialization.

## Post-Installation Setup

### Initialize gcloud

```bash
gcloud init
```

This interactive wizard:
1. Authorizes with your Google account
2. Selects or creates a configuration
3. Sets default project
4. Optionally sets default compute region/zone

For non-interactive initialization:

```bash
gcloud init --console-only
```

### Install Additional Components

```bash
# List available components
gcloud components list

# Install common components
gcloud components install alpha beta kubectl gke-gcloud-auth-plugin

# Update all components
gcloud components update
```

**Key components**:
- `alpha`, `beta`: Preview features
- `kubectl`: Kubernetes management
- `gke-gcloud-auth-plugin`: GKE authentication
- `bq`: BigQuery CLI
- `gsutil`: Legacy Cloud Storage CLI (prefer `gcloud storage`)

### Verify Installation

```bash
# Check version
gcloud --version

# View current configuration
gcloud config list

# Test API access
gcloud projects list
```

## Environment Variables

Useful environment variables for customization:

```bash
# Force specific Python interpreter
export CLOUDSDK_PYTHON=/usr/local/bin/python3.11

# Set configuration directory
export CLOUDSDK_CONFIG=/custom/path/gcloud

# Set active configuration
export CLOUDSDK_ACTIVE_CONFIG_NAME=production

# Disable prompts (for scripting)
export CLOUDSDK_CORE_DISABLE_PROMPTS=1
```

## Troubleshooting

### Python Version Issues

If gcloud fails with Python errors:

```bash
# Check which Python gcloud is using
which python3

# Force specific Python
export CLOUDSDK_PYTHON=/path/to/python3.11
```

### PATH Conflicts

If `gcloud` command not found after installation:

```bash
# Verify SDK path
echo $PATH | grep google-cloud-sdk

# Manually add to current session
export PATH="$PATH:$HOME/google-cloud-sdk/bin"

# Check for shadowing
which -a gcloud
```

### Component Installation Failures on Apple Silicon

If components fail to install on M1/M2/M3:

```bash
# Ensure Rosetta is installed
softwareupdate --install-rosetta

# Try installing with architecture flag
arch -x86_64 gcloud components install COMPONENT
```

### Homebrew Installation Issues

If Homebrew cask is outdated:

```bash
brew update
brew upgrade --cask google-cloud-sdk

# If issues persist, reinstall
brew uninstall --cask google-cloud-sdk
brew install --cask google-cloud-sdk
```

## Uninstallation

### Homebrew Installation

```bash
brew uninstall --cask google-cloud-sdk
```

### Manual Installation

```bash
# Remove SDK directory
rm -rf ~/google-cloud-sdk

# Remove configuration directory
rm -rf ~/.config/gcloud

# Remove shell profile entries
# Edit ~/.zshrc or ~/.bash_profile to remove gcloud lines
```
