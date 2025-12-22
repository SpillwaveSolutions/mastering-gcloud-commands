# Google Cloud CLI Installation on Windows

This guide covers installation of the Google Cloud CLI (gcloud) on Windows,
including multiple installation methods and troubleshooting.

## Prerequisites

### Python Runtime

The gcloud CLI requires Python 3.9–3.14. The Windows installer includes a bundled Python,
but you can also use your own:

```powershell
python --version
```

### System Requirements

- Windows 10 or later (64-bit)
- Administrator access for system-wide installation (optional)
- PowerShell 5.0 or later (for PowerShell installation method)

## Installation Methods

### Method 1: Interactive Installer (Recommended)

Download and run the Google Cloud CLI installer:

1. **Download** the installer from:
   https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe

2. **Run the installer** (`GoogleCloudSDKInstaller.exe`)

3. **Follow the prompts**:
   - Accept the license agreement
   - Choose installation location (default: `%LOCALAPPDATA%\Google\Cloud SDK`)
   - Select components to install
   - Optionally install bundled Python if not present

4. **Complete setup** by running `gcloud init` in a new terminal

The installer automatically:
- Installs the SDK and required dependencies
- Adds gcloud to your PATH
- Creates Start Menu shortcuts
- Offers to run `gcloud init` after installation

### Method 2: PowerShell Installation

For automated or scripted installations:

```powershell
# Download installer
(New-Object Net.WebClient).DownloadFile(
    "https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe",
    "$env:Temp\GoogleCloudSDKInstaller.exe"
)

# Run installer (interactive)
& "$env:Temp\GoogleCloudSDKInstaller.exe"
```

### Method 3: ZIP File Installation

For portable or custom installations without running an installer:

```powershell
# Download ZIP archive (replace VERSION with desired version)
$VERSION = "503.0.0"
$URL = "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${VERSION}-windows-x86_64.zip"

Invoke-WebRequest -Uri $URL -OutFile "$env:Temp\google-cloud-cli.zip"

# Extract to desired location
Expand-Archive -Path "$env:Temp\google-cloud-cli.zip" -DestinationPath "C:\"

# Run install script (adds to PATH, enables completion)
& "C:\google-cloud-sdk\install.bat"

# Initialize
gcloud init
```

### Method 4: Silent Installation

For enterprise deployments, CI/CD pipelines, or unattended installations:

```powershell
# Download installer
Invoke-WebRequest -Uri "https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe" `
    -OutFile "$env:Temp\GoogleCloudSDKInstaller.exe"

# Silent install with default options
Start-Process -FilePath "$env:Temp\GoogleCloudSDKInstaller.exe" -ArgumentList "/S" -Wait

# Silent install with custom path
Start-Process -FilePath "$env:Temp\GoogleCloudSDKInstaller.exe" `
    -ArgumentList "/S /D=C:\gcloud" -Wait
```

Silent installer options:
- `/S` - Silent mode (no UI)
- `/D=PATH` - Custom installation directory
- `/allusers` - Install for all users (requires admin)

### Method 5: Chocolatey Package Manager

If using Chocolatey:

```powershell
# Install via Chocolatey
choco install gcloudsdk -y

# Verify installation
gcloud --version
```

### Method 6: Scoop Package Manager

If using Scoop:

```powershell
# Add extras bucket
scoop bucket add extras

# Install gcloud
scoop install gcloud

# Verify installation
gcloud --version
```

## PATH Configuration

The installer automatically adds gcloud to PATH. To verify or add manually:

### GUI Method

1. Press `Win + X` → System → Advanced system settings
2. Click "Environment Variables"
3. Under "User variables" or "System variables", select "Path" and click "Edit"
4. Add: `%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin`
5. Click OK to save

### PowerShell Method

```powershell
# Add to user PATH (persists across sessions)
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$gcloudPath = "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin"
if ($currentPath -notlike "*$gcloudPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$gcloudPath", "User")
}

# Refresh current session
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
```

### Command Prompt Method

```cmd
setx PATH "%PATH%;%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin"
```

## Post-Installation Setup

### Initialize gcloud

Open a new Command Prompt or PowerShell window:

```powershell
gcloud init
```

This interactive wizard:
1. Opens browser for Google account authorization
2. Selects or creates a configuration
3. Sets default project
4. Optionally sets default compute region/zone

For non-interactive initialization (CI/CD):

```powershell
gcloud init --console-only
```

### Install Additional Components

```powershell
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

```powershell
# Check version
gcloud --version

# View current configuration
gcloud config list

# Test API access
gcloud projects list
```

## PowerShell Integration

### PowerShell Profile Setup

Add to your PowerShell profile (`$PROFILE`):

```powershell
# Check if profile exists, create if not
if (!(Test-Path -Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force
}

# Add gcloud to profile
Add-Content -Path $PROFILE -Value @'

# Google Cloud SDK
$gcloudPath = "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk"
if (Test-Path $gcloudPath) {
    $env:Path = "$gcloudPath\bin;$env:Path"
}
'@
```

### Tab Completion (PowerShell)

Enable command completion in PowerShell:

```powershell
# Add to PowerShell profile
. "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\completion.ps1.inc"
```

## Windows Terminal Integration

For Windows Terminal with multiple shells:

### PowerShell Profile

```json
{
    "name": "PowerShell (gcloud)",
    "commandline": "powershell.exe -NoExit -Command \"gcloud config list\"",
    "startingDirectory": "%USERPROFILE%"
}
```

### Command Prompt Profile

```json
{
    "name": "CMD (gcloud)",
    "commandline": "cmd.exe /k gcloud config list",
    "startingDirectory": "%USERPROFILE%"
}
```

## Environment Variables

Useful environment variables for customization:

```powershell
# Force specific Python interpreter
$env:CLOUDSDK_PYTHON = "C:\Python311\python.exe"

# Set configuration directory
$env:CLOUDSDK_CONFIG = "C:\custom\gcloud"

# Set active configuration
$env:CLOUDSDK_ACTIVE_CONFIG_NAME = "production"

# Disable prompts (for scripting)
$env:CLOUDSDK_CORE_DISABLE_PROMPTS = "1"
```

To persist environment variables:

```powershell
[Environment]::SetEnvironmentVariable("CLOUDSDK_PYTHON", "C:\Python311\python.exe", "User")
```

## Troubleshooting

### gcloud Command Not Found

```powershell
# Verify installation path exists
Test-Path "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"

# Check PATH
$env:Path -split ";"

# Manually add to current session
$env:Path += ";$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin"
```

### Python Version Issues

```powershell
# Check which Python gcloud is using
gcloud info --format="value(config.python)"

# Force specific Python
$env:CLOUDSDK_PYTHON = "C:\Python311\python.exe"
```

### Permission Issues

If encountering "Access Denied" errors:

1. Run PowerShell as Administrator
2. Or install to user directory (default behavior)

```powershell
# Check current user permissions on install directory
Get-Acl "$env:LOCALAPPDATA\Google\Cloud SDK"
```

### Component Installation Failures

```powershell
# Run as Administrator for system-wide components
Start-Process powershell -Verb RunAs -ArgumentList "gcloud components install kubectl"

# Or update SDK first
gcloud components update
```

### SSL Certificate Issues

If encountering SSL errors (common in corporate environments):

```powershell
# Disable SSL verification (not recommended for production)
$env:CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE = "C:\path\to\corporate-ca.crt"

# Or
gcloud config set core/custom_ca_certs_file C:\path\to\corporate-ca.crt
```

### Proxy Configuration

For corporate proxy environments:

```powershell
# Set proxy
$env:HTTP_PROXY = "http://proxy.company.com:8080"
$env:HTTPS_PROXY = "http://proxy.company.com:8080"

# Or configure in gcloud
gcloud config set proxy/type http
gcloud config set proxy/address proxy.company.com
gcloud config set proxy/port 8080
```

## Uninstallation

### Via Control Panel

1. Press `Win + X` → Apps and Features (or Control Panel → Programs)
2. Find "Google Cloud SDK"
3. Click Uninstall

### Via Command Line

```powershell
# Run uninstaller
& "$env:LOCALAPPDATA\Google\Cloud SDK\uninstall.exe"
```

### Manual Cleanup

After uninstallation, remove remaining files:

```powershell
# Remove SDK directory
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Google\Cloud SDK" -ErrorAction SilentlyContinue

# Remove configuration directory
Remove-Item -Recurse -Force "$env:APPDATA\gcloud" -ErrorAction SilentlyContinue

# Remove from PATH (if manually added)
# Edit Environment Variables via System Properties
```

## CI/CD Integration

### GitHub Actions

```yaml
- name: Setup gcloud CLI
  uses: google-github-actions/setup-gcloud@v2
  with:
    version: 'latest'
```

### Azure DevOps

```yaml
- task: GoogleCloudSdkTool@0
  inputs:
    version: 'latest'
```

### Jenkins (Windows Agent)

```groovy
bat '''
    powershell -Command "& {
        if (!(Test-Path 'C:\\gcloud')) {
            Invoke-WebRequest -Uri 'https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe' -OutFile '$env:Temp\\GoogleCloudSDKInstaller.exe'
            Start-Process -FilePath '$env:Temp\\GoogleCloudSDKInstaller.exe' -ArgumentList '/S /D=C:\\gcloud' -Wait
        }
    }"
    set PATH=C:\\gcloud\\google-cloud-sdk\\bin;%PATH%
    gcloud --version
'''
```
