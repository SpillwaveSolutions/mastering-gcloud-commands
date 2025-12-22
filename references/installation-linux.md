# Google Cloud CLI Installation on Linux

This guide covers installation of the Google Cloud CLI (gcloud) on Linux distributions,
including package manager methods, manual installation, and Docker usage.

## Prerequisites

### Python Runtime

The gcloud CLI requires Python 3.9–3.14. Most Linux distributions include a compatible version:

```bash
python3 --version
```

If needed, install Python:

```bash
# Debian/Ubuntu
sudo apt-get install python3

# RHEL/CentOS/Fedora
sudo dnf install python3

# Arch Linux
sudo pacman -S python
```

### System Requirements

- 64-bit Linux distribution (x86_64 or ARM64)
- curl or wget for downloads
- sudo access for package manager installation (optional)

## Installation Methods

### Method 1: Package Manager - Debian/Ubuntu (Recommended)

Using apt for Debian-based distributions (Ubuntu, Debian, Linux Mint, Pop!_OS):

```bash
# Install prerequisites
sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates gnupg curl

# Add the Google Cloud public key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

# Add the gcloud CLI distribution URI
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Update and install
sudo apt-get update
sudo apt-get install google-cloud-cli

# Verify installation
gcloud --version
```

#### Install Additional Components (Debian/Ubuntu)

```bash
# Install kubectl
sudo apt-get install google-cloud-cli-kubectl

# Install GKE auth plugin
sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin

# Install App Engine components
sudo apt-get install google-cloud-cli-app-engine-python
sudo apt-get install google-cloud-cli-app-engine-java

# List all available packages
apt-cache search google-cloud-cli
```

### Method 2: Package Manager - RHEL/CentOS/Fedora

Using dnf or yum for Red Hat-based distributions:

```bash
# Add the Cloud SDK repository
sudo tee /etc/yum.repos.d/google-cloud-sdk.repo << 'EOM'
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM

# Install using dnf (Fedora, RHEL 8+, CentOS Stream)
sudo dnf install google-cloud-cli

# Or using yum (older systems)
sudo yum install google-cloud-cli

# Verify installation
gcloud --version
```

#### Repository URLs by Distribution

Replace `el9-x86_64` in the baseurl based on your system:

| Distribution | Architecture | baseurl suffix |
|-------------|--------------|----------------|
| RHEL/CentOS 9 | x86_64 | `el9-x86_64` |
| RHEL/CentOS 9 | ARM64 | `el9-aarch64` |
| RHEL/CentOS 8 | x86_64 | `el8-x86_64` |
| RHEL/CentOS 7 | x86_64 | `el7-x86_64` |
| Fedora | x86_64 | `el9-x86_64` |

#### Install Additional Components (RHEL/CentOS/Fedora)

```bash
sudo dnf install google-cloud-cli-kubectl
sudo dnf install google-cloud-cli-gke-gcloud-auth-plugin
```

### Method 3: Package Manager - openSUSE/SLES

```bash
# Add repository
sudo zypper addrepo https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64 google-cloud-sdk

# Import GPG key
sudo rpm --import https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg

# Install
sudo zypper install google-cloud-cli
```

### Method 4: Package Manager - Arch Linux (AUR)

Using an AUR helper like yay:

```bash
# Install from AUR
yay -S google-cloud-cli

# Or manually
git clone https://aur.archlinux.org/google-cloud-cli.git
cd google-cloud-cli
makepkg -si
```

### Method 5: Interactive Script Installation

Universal method that works on any Linux distribution:

```bash
# Download and run the installer
curl https://sdk.cloud.google.com | bash

# Restart shell to update PATH
exec -l $SHELL

# Initialize gcloud
gcloud init
```

The interactive installer:
1. Downloads the latest SDK version
2. Extracts to `~/google-cloud-sdk`
3. Offers to update your shell profile (.bashrc, .zshrc, etc.)
4. Enables command completion

Options for the interactive installer:

```bash
# Non-interactive installation
curl https://sdk.cloud.google.com | bash -s -- --disable-prompts

# Install to custom directory
curl https://sdk.cloud.google.com | bash -s -- --install-dir=/opt
```

### Method 6: Versioned Archive (Reproducible)

For CI/CD, containers, or reproducible environments:

```bash
# Set version and architecture
VERSION="503.0.0"
ARCH="x86_64"  # or "arm" for ARM64

# Download specific version
curl -O "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${VERSION}-linux-${ARCH}.tar.gz"

# Verify checksum (optional but recommended)
curl -O "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${VERSION}-linux-${ARCH}.tar.gz.sha256"
sha256sum -c google-cloud-cli-${VERSION}-linux-${ARCH}.tar.gz.sha256

# Extract to home directory
tar -xzf google-cloud-cli-${VERSION}-linux-${ARCH}.tar.gz -C ~/

# Or extract system-wide
sudo tar -xzf google-cloud-cli-${VERSION}-linux-${ARCH}.tar.gz -C /opt/

# Run install script (non-interactive)
~/google-cloud-sdk/install.sh --quiet --path-update=true --command-completion=true

# Add to PATH immediately
source ~/google-cloud-sdk/path.bash.inc
```

### Method 7: Docker Installation

For containerized workflows:

```bash
# Pull official Google Cloud SDK image
docker pull gcr.io/google.com/cloudsdktool/cloud-sdk:latest

# Run gcloud commands via Docker
docker run --rm gcr.io/google.com/cloudsdktool/cloud-sdk gcloud version

# Interactive session with mounted credentials
docker run -it --rm \
  -v ~/.config/gcloud:/root/.config/gcloud \
  gcr.io/google.com/cloudsdktool/cloud-sdk:latest \
  /bin/bash

# Slim image (smaller, no extras)
docker pull gcr.io/google.com/cloudsdktool/cloud-sdk:slim

# Alpine-based image (smallest)
docker pull gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
```

#### Docker Image Variants

| Image Tag | Size | Use Case |
|-----------|------|----------|
| `latest` | ~2.5GB | Full SDK with all components |
| `slim` | ~500MB | Core SDK without extras |
| `alpine` | ~200MB | Minimal Alpine-based image |
| `emulators` | ~2.5GB | Includes Pub/Sub, Datastore emulators |

#### Docker Compose Example

```yaml
version: '3.8'
services:
  gcloud:
    image: gcr.io/google.com/cloudsdktool/cloud-sdk:slim
    volumes:
      - ~/.config/gcloud:/root/.config/gcloud
      - ./:/workspace
    working_dir: /workspace
    entrypoint: /bin/bash
```

### Method 8: Snap Installation

For distributions supporting Snap:

```bash
# Install via Snap
sudo snap install google-cloud-cli --classic

# Verify installation
gcloud --version
```

## Shell Integration

### Bash (Default on Most Distributions)

Add to `~/.bashrc`:

```bash
# Google Cloud SDK
if [ -f "$HOME/google-cloud-sdk/path.bash.inc" ]; then
    source "$HOME/google-cloud-sdk/path.bash.inc"
fi

if [ -f "$HOME/google-cloud-sdk/completion.bash.inc" ]; then
    source "$HOME/google-cloud-sdk/completion.bash.inc"
fi
```

Then reload:

```bash
source ~/.bashrc
```

### Zsh

Add to `~/.zshrc`:

```bash
# Google Cloud SDK
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then
    source "$HOME/google-cloud-sdk/path.zsh.inc"
fi

if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then
    source "$HOME/google-cloud-sdk/completion.zsh.inc"
fi
```

### Fish

Add to `~/.config/fish/config.fish`:

```fish
# Google Cloud SDK
if test -f "$HOME/google-cloud-sdk/path.fish.inc"
    source "$HOME/google-cloud-sdk/path.fish.inc"
end
```

### System-Wide Installation Path

If installed to `/opt/google-cloud-sdk`:

```bash
# Bash/Zsh
source /opt/google-cloud-sdk/path.bash.inc
source /opt/google-cloud-sdk/completion.bash.inc
```

Or create a profile script:

```bash
sudo tee /etc/profile.d/gcloud.sh << 'EOF'
if [ -f /opt/google-cloud-sdk/path.bash.inc ]; then
    source /opt/google-cloud-sdk/path.bash.inc
fi
if [ -f /opt/google-cloud-sdk/completion.bash.inc ]; then
    source /opt/google-cloud-sdk/completion.bash.inc
fi
EOF
```

## Post-Installation Setup

### Initialize gcloud

```bash
gcloud init
```

This interactive wizard:
1. Opens browser for Google account authorization
2. Selects or creates a configuration
3. Sets default project
4. Optionally sets default compute region/zone

For headless servers (no browser):

```bash
gcloud init --console-only
```

### Install Additional Components

For manual/script installations:

```bash
# List available components
gcloud components list

# Install common components
gcloud components install alpha beta kubectl gke-gcloud-auth-plugin

# Update all components
gcloud components update
```

**Note**: Package manager installations use system packages for components instead.

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
# Add to ~/.bashrc or ~/.profile

# Force specific Python interpreter
export CLOUDSDK_PYTHON=/usr/bin/python3.11

# Set configuration directory
export CLOUDSDK_CONFIG=/custom/path/gcloud

# Set active configuration
export CLOUDSDK_ACTIVE_CONFIG_NAME=production

# Disable prompts (for scripting)
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

# Custom CA certificates (corporate environments)
export CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE=/path/to/ca-bundle.crt
```

## Troubleshooting

### gcloud Command Not Found

```bash
# Check if SDK is installed
ls ~/google-cloud-sdk/bin/gcloud
ls /opt/google-cloud-sdk/bin/gcloud

# Verify PATH
echo $PATH | tr ':' '\n' | grep google

# Manually add to current session
export PATH="$PATH:$HOME/google-cloud-sdk/bin"

# Check for shadowing
which -a gcloud
type gcloud
```

### Python Version Issues

```bash
# Check which Python gcloud is using
gcloud info --format="value(config.python)"

# Check available Python versions
which python3
python3 --version

# Force specific Python
export CLOUDSDK_PYTHON=/usr/bin/python3.11
```

### Permission Issues

```bash
# Fix ownership for user installation
sudo chown -R $(whoami):$(whoami) ~/google-cloud-sdk

# For system-wide installation, use sudo
sudo gcloud components update
```

### Package Manager Key Issues

#### Debian/Ubuntu

```bash
# Re-import GPG key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

# Clear apt cache
sudo apt-get clean
sudo apt-get update
```

#### RHEL/CentOS/Fedora

```bash
# Re-import RPM key
sudo rpm --import https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg

# Clean cache
sudo dnf clean all
sudo dnf makecache
```

### SSL/TLS Certificate Issues

Common in corporate environments with SSL inspection:

```bash
# Use custom CA bundle
export CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE=/etc/pki/tls/certs/ca-bundle.crt

# Or configure in gcloud
gcloud config set core/custom_ca_certs_file /path/to/ca-bundle.crt

# For package downloads, also set
export REQUESTS_CA_BUNDLE=/path/to/ca-bundle.crt
```

### Proxy Configuration

```bash
# Set proxy environment variables
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
export NO_PROXY=localhost,127.0.0.1,.company.com

# Or configure in gcloud
gcloud config set proxy/type http
gcloud config set proxy/address proxy.company.com
gcloud config set proxy/port 8080
```

### Component Update Failures

```bash
# Check disk space
df -h

# Clear component cache
rm -rf ~/.config/gcloud/cache

# Reinstall problematic component
gcloud components reinstall COMPONENT_NAME
```

## Uninstallation

### Package Manager Installation

```bash
# Debian/Ubuntu
sudo apt-get remove google-cloud-cli
sudo apt-get autoremove

# RHEL/CentOS/Fedora
sudo dnf remove google-cloud-cli

# Arch Linux
sudo pacman -R google-cloud-cli
```

Remove repository:

```bash
# Debian/Ubuntu
sudo rm /etc/apt/sources.list.d/google-cloud-sdk.list
sudo rm /usr/share/keyrings/cloud.google.gpg

# RHEL/CentOS/Fedora
sudo rm /etc/yum.repos.d/google-cloud-sdk.repo
```

### Manual/Script Installation

```bash
# Remove SDK directory
rm -rf ~/google-cloud-sdk
# Or: sudo rm -rf /opt/google-cloud-sdk

# Remove configuration directory
rm -rf ~/.config/gcloud

# Remove shell profile entries
# Edit ~/.bashrc, ~/.zshrc, or ~/.profile to remove gcloud lines
```

## CI/CD Integration

### GitHub Actions

```yaml
- name: Setup gcloud CLI
  uses: google-github-actions/setup-gcloud@v2
  with:
    version: 'latest'
```

### GitLab CI

```yaml
image: gcr.io/google.com/cloudsdktool/cloud-sdk:slim

deploy:
  script:
    - gcloud --version
    - gcloud auth activate-service-account --key-file=$GCP_SA_KEY
    - gcloud run deploy ...
```

### Jenkins

```groovy
pipeline {
    agent {
        docker {
            image 'gcr.io/google.com/cloudsdktool/cloud-sdk:slim'
        }
    }
    stages {
        stage('Deploy') {
            steps {
                sh 'gcloud --version'
                sh 'gcloud run deploy ...'
            }
        }
    }
}
```

### CircleCI

```yaml
version: 2.1
orbs:
  gcp-cli: circleci/gcp-cli@3.0

jobs:
  deploy:
    executor: gcp-cli/google
    steps:
      - gcp-cli/setup
      - run: gcloud run deploy ...
```
