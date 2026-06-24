#Requires -RunAsAdministrator
# One-time cleanup: remove Chocolatey packages installed by MIP init.ps1
$ErrorActionPreference = 'Continue'

$packages = @(
  'nodejs',
  'docker-desktop',
  'minikube',
  'kubernetes-cli',
  'kubernetes-helm',
  'git',
  'python',
  'openssl'
)

Write-Host '[INFO] Uninstalling MIP init Chocolatey packages...' -ForegroundColor Cyan

foreach ($id in $packages) {
  $installed = choco list --local-only $id -r 2>$null
  if ($installed -match "^$([regex]::Escape($id))\|") {
    Write-Host "[INFO] choco uninstall $id -y"
    choco uninstall $id -y --remove-dependencies
  } else {
    Write-Host "[SKIP] $id not installed via Chocolatey"
  }
}

Write-Host ''
Write-Host '[OK] Done. Reboot recommended if Docker Desktop was removed.' -ForegroundColor Green
Write-Host 'Workspace folder was already cleared. Run bootstrap again from an empty project folder.'
