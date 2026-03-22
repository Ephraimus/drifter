param(
  [string]$SourceDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$RepoUrl = '',
  [string]$RepoBranch = 'main',
  [switch]$SkipBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($Message) {
  Write-Host ""
  Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Fail($Message) {
  throw $Message
}

function Refresh-Path {
  $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
  $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
  $env:PATH = @($userPath, $machinePath) -join ';'
}

function Ensure-Command($Name) {
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $command) {
    Fail "Required command not found after installation: $Name"
  }

  return $command
}

function Backup-PowerShellProfile {
  $backupDir = Join-Path $HOME ".shell-migration-backup/$(Get-Date -Format 'yyyyMMdd-HHmmss')"
  $profileDir = Split-Path -Parent $PROFILE
  $legacyProfile = Join-Path $profileDir 'Microsoft.PowerShell_profile.legacy.ps1'

  New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
  New-Item -ItemType Directory -Path $profileDir -Force | Out-Null

  if (Test-Path $PROFILE) {
    Copy-Item -Path $PROFILE -Destination $backupDir -Force
    Move-Item -Path $PROFILE -Destination $legacyProfile -Force
    Write-Host "  Existing PowerShell profile backed up and moved to: $legacyProfile" -ForegroundColor Green
  } else {
    Write-Host "  No existing PowerShell profile found, skipping profile backup." -ForegroundColor DarkGray
  }

  Write-Host "  Backup saved to: $backupDir" -ForegroundColor Green
}

function Write-ChezmoiData {
  $chezmoiConfigDir = Join-Path $HOME '.config\chezmoi'
  $chezmoiConfigFile = Join-Path $chezmoiConfigDir 'chezmoi.toml'

  New-Item -ItemType Directory -Path $chezmoiConfigDir -Force | Out-Null

  @"
[data]
use_fish = false
legacy_bash = true
legacy_zsh = true
use_blesh = true
use_powershell = true
machine_role = "$env:COMPUTERNAME"
"@ | Set-Content -Path $chezmoiConfigFile -Encoding UTF8

  Write-Host "  Wrote local chezmoi data: $chezmoiConfigFile" -ForegroundColor Green
}

function Apply-LocalSource {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ResolvedSourceDir
  )

  if (-not (Test-Path (Join-Path $ResolvedSourceDir 'dot_bashrc.tmpl'))) {
    Fail "Starter-kit directory does not look valid: $ResolvedSourceDir"
  }

  $chezmoiSourceDir = Join-Path $HOME '.local\share\chezmoi'
  if (Test-Path $chezmoiSourceDir) {
    Remove-Item -Path $chezmoiSourceDir -Recurse -Force
  }

  New-Item -ItemType Directory -Path $chezmoiSourceDir -Force | Out-Null
  Copy-Item -Path (Join-Path $ResolvedSourceDir '*') -Destination $chezmoiSourceDir -Recurse -Force
  & chezmoi apply --force --source $chezmoiSourceDir
}

function Apply-RepoSource {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Url,
    [Parameter(Mandatory = $true)]
    [string]$Branch
  )

  & chezmoi init --apply --branch $Branch $Url
}

function Test-IsWindowsHost {
  if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
    return [bool]$IsWindows
  }

  return $env:OS -eq 'Windows_NT'
}

if (-not (Test-IsWindowsHost)) {
  Fail 'bootstrap-powershell.ps1 supports Windows only.'
}

if (($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion.Major -lt 7) -or
    ($PSVersionTable.PSEdition -ne 'Core' -and $PSVersionTable.PSEdition -ne 'Desktop')) {
  Fail 'Supported hosts: PowerShell 7+ or Windows PowerShell 5.1.'
}

if ($RepoUrl -and $PSBoundParameters.ContainsKey('SourceDir')) {
  Fail 'Use either -SourceDir or -RepoUrl, not both.'
}

$mode = if ($RepoUrl) { 'repo' } else { 'local' }

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "  Drifter - Windows PowerShell Bootstrap" -ForegroundColor Cyan
Write-Host "  Target: PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
Write-Host "  Source mode: $mode" -ForegroundColor Cyan
if ($mode -eq 'repo') {
  Write-Host "  Repo URL   : $RepoUrl" -ForegroundColor Cyan
  Write-Host "  Branch     : $RepoBranch" -ForegroundColor Cyan
} else {
  Write-Host "  Source dir : $SourceDir" -ForegroundColor Cyan
}
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Scoop ---
Write-Host "[Step 1/4] Checking Scoop package manager ..." -ForegroundColor Yellow
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
  Write-Host "  Installing Scoop ..." -ForegroundColor Gray
  Invoke-RestMethod get.scoop.sh | Invoke-Expression
} else {
  Write-Host "  Scoop already installed: $(scoop --version)" -ForegroundColor Green
}

# --- Step 2: Modern CLI tools ---
Write-Host "[Step 2/4] Installing Modern CLI tools via Scoop ..." -ForegroundColor Yellow
$tools = @('git', 'starship', 'zoxide', 'eza', 'bat', 'fzf', 'fd', 'ripgrep', 'chezmoi')
foreach ($tool in $tools) {
  if (Get-Command $tool -ErrorAction SilentlyContinue) {
    Write-Host "  $tool already installed, skipping." -ForegroundColor DarkGray
  } else {
    Write-Host "  Installing $tool ..." -ForegroundColor Gray
    scoop install $tool
  }
}
Refresh-Path | Out-Null

# --- Step 3: PSFzf module (fzf PowerShell integration) ---
Write-Host "[Step 3/4] Installing PSFzf module ..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable -Name PSFzf)) {
  Install-Module -Name PSFzf -Scope CurrentUser -Force
} else {
  Write-Host "  PSFzf already installed." -ForegroundColor DarkGray
}

# --- Step 4: Backup + apply via chezmoi ---
Write-Host "[Step 4/4] Applying PowerShell profile via Chezmoi ..." -ForegroundColor Yellow
Ensure-Command chezmoi | Out-Null

if (-not $SkipBackup) {
  Backup-PowerShellProfile
} else {
  Write-Host "  Skipping profile backup." -ForegroundColor DarkGray
}

Write-ChezmoiData

if ($mode -eq 'repo') {
  Apply-RepoSource -Url $RepoUrl -Branch $RepoBranch
} else {
  Apply-LocalSource -ResolvedSourceDir (Resolve-Path $SourceDir).Path
}

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "  Done! Restart PowerShell to apply the new profile." -ForegroundColor Green
Write-Host "  Profile path: $PROFILE" -ForegroundColor Green
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host ""
