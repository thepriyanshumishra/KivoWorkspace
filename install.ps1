# Kivo Workspace — Windows Terminal Installer
# Purpose: Downloads the latest pre-compiled production release from GitHub, extracts it, and creates Start Menu & Desktop shortcuts.

$ErrorActionPreference = "Stop"

# --- Configuration ---
# Customize this to match your GitHub repository path (owner/repo)
$GitHubRepo = "thepriyanshumishra/KivoWorkspace"

Write-Host "=========================================" -ForegroundColor Green
Write-Host "      Installing Kivo Workspace          " -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

Write-Host "Checking latest release from GitHub ($GitHubRepo)..."

# Fetch release JSON
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ReleaseUrl = "https://api.github.com/repos/$GitHubRepo/releases/latest"

try {
    $ReleaseInfo = Invoke-RestMethod -Uri $ReleaseUrl -UseBasicParsing
} catch {
    Write-Error "Error: Could not connect to GitHub API. Please check your internet connection or repository path."
    exit 1
}

# Find download URL for Windows x64 zip asset
$Assets = $ReleaseInfo.assets
$DownloadAsset = $null
foreach ($Asset in $Assets) {
    if ($Asset.name -like "*Windows*" -and $Asset.name -like "*.zip") {
        $DownloadAsset = $Asset
        break
    }
}

if (-not $DownloadAsset) {
    # Try general zip fallback
    foreach ($Asset in $Assets) {
        if ($Asset.name -like "*.zip") {
            $DownloadAsset = $Asset
            break
        }
    }
}

if (-not $DownloadAsset) {
    Write-Error "Error: Could not find Windows release package (.zip) on GitHub Releases page."
    Write-Host "Please ensure the GitHub Action has completed compiling and uploaded the packages." -ForegroundColor Yellow
    exit 1
}

$Filename = $DownloadAsset.name
$DownloadUrl = $DownloadAsset.browser_download_url

$TempDir = Join-Path $env:TEMP "KivoInstall"
if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
$TempFile = Join-Path $TempDir $Filename

Write-Host "Downloading release archive: $Filename..." -ForegroundColor Green
Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempFile -UseBasicParsing

$InstallDir = Join-Path $env:LOCALAPPDATA "KivoWorkspace"
if (Test-Path $InstallDir) {
    Write-Host "Removing previous installation folder..." -ForegroundColor Yellow
    Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

Write-Host "Extracting files to $InstallDir..." -ForegroundColor Green
# PowerShell 5.0+ Expand-Archive
Expand-Archive -Path $TempFile -DestinationPath $InstallDir -Force

# --- Create Shortcuts ---
Write-Host "Creating application shortcuts..." -ForegroundColor Yellow

$ExePath = Join-Path $InstallDir "kivo_workspace.exe"
if (-not (Test-Path $ExePath)) {
    # If the zip packages inside a subfolder, find it
    $ChildExe = Get-ChildItem -Path $InstallDir -Filter "kivo_workspace.exe" -Recurse | Select-Object -First 1
    if ($ChildExe) {
        $ExePath = $ChildExe.FullName
        $InstallDir = $ChildExe.DirectoryName
    } else {
        Write-Error "Error: Could not find 'kivo_workspace.exe' inside the extracted package."
        exit 1
    }
}

$WshShell = New-Object -ComObject WScript.Shell

# 1. Desktop Shortcut
$DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$DesktopShortcut = $WshShell.CreateShortcut((Join-Path $DesktopPath "Kivo Workspace.lnk"))
$DesktopShortcut.TargetPath = $ExePath
$DesktopShortcut.WorkingDirectory = $InstallDir
$DesktopShortcut.Save()

# 2. Start Menu Shortcut
$StartMenuPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Programs)
$StartMenuShortcut = $WshShell.CreateShortcut((Join-Path $StartMenuPath "Kivo Workspace.lnk"))
$StartMenuShortcut.TargetPath = $ExePath
$StartMenuShortcut.WorkingDirectory = $InstallDir
$StartMenuShortcut.Save()

# Cleanup
Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nKivo Workspace installed successfully!" -ForegroundColor Green
Write-Host "Start Menu and Desktop shortcuts have been created. You can search for 'Kivo Workspace' in your Start menu or launch it from your Desktop." -ForegroundColor Green
