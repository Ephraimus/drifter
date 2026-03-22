# install-powershell.ps1
# Drifter - One-command installer for Windows PowerShell
#
# Usage:
#   irm https://raw.githubusercontent.com/Ephraimus/chezmoi/main/scripts/install-powershell.ps1 | iex

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoUser = 'Ephraimus'
$RepoName = 'chezmoi'
$RepoBranch = 'main'

$BootstrapUrl = "https://raw.githubusercontent.com/$RepoUser/$RepoName/$RepoBranch/scripts/bootstrap-powershell.ps1"
$DefaultRepoUrl = "https://github.com/$RepoUser/$RepoName.git"
$TempScript = Join-Path ([System.IO.Path]::GetTempPath()) "drifter-bootstrap-powershell-$RepoBranch.ps1"

function Test-IsWindowsHost {
  if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
    return [bool]$IsWindows
  }

  return $env:OS -eq 'Windows_NT'
}

if (-not (Test-IsWindowsHost)) {
  throw 'install-powershell.ps1 supports Windows only.'
}

if (($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion.Major -lt 7) -or
    ($PSVersionTable.PSEdition -ne 'Core' -and $PSVersionTable.PSEdition -ne 'Desktop')) {
  throw 'Supported hosts: PowerShell 7+ or Windows PowerShell 5.1.'
}

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "  Drifter - Windows One-Command Installer" -ForegroundColor Cyan
Write-Host "  Bootstrap URL: $BootstrapUrl" -ForegroundColor Cyan
Write-Host "  Repo URL     : $DefaultRepoUrl" -ForegroundColor Cyan
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[INFO] Downloading bootstrap-powershell.ps1 ..." -ForegroundColor Yellow
Invoke-RestMethod -Uri $BootstrapUrl -OutFile $TempScript

Write-Host "[INFO] Running bootstrap-powershell.ps1 ..." -ForegroundColor Yellow
& $TempScript -RepoUrl $DefaultRepoUrl -RepoBranch $RepoBranch
