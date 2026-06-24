#Requires -RunAsAdministrator
# Full cleanup for MIP init retest: Chocolatey packages + standalone Docker/Minikube leftovers.
$ErrorActionPreference = 'Continue'

function Write-Step([string]$Message) {
  Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Stop-DockerDesktop {
  Write-Step 'Stopping Docker Desktop (if running)...'
  Get-Process -Name 'Docker Desktop','com.docker.backend','com.docker.service','docker' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Stop-Service -Name 'com.docker.service' -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
}

function Uninstall-DockerDesktop {
  Stop-DockerDesktop

  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Step 'winget uninstall Docker.DockerDesktop...'
    winget uninstall --id Docker.DockerDesktop -e --accept-source-agreements --disable-interactivity 2>&1 | Out-Host
  }

  $dockerExe = "${env:ProgramFiles}\Docker\Docker\Docker Desktop Installer.exe"
  if (Test-Path $dockerExe) {
    Write-Step 'Running Docker Desktop Installer uninstall...'
    & $dockerExe uninstall --quiet 2>&1 | Out-Host
    Start-Sleep -Seconds 5
  }

  $chocoDocker = choco list --local-only docker-desktop -r 2>$null
  if ($chocoDocker -match '^docker-desktop\|') {
    Write-Step 'choco uninstall docker-desktop (normal)...'
    choco uninstall docker-desktop -y --remove-dependencies 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
      Write-Step 'choco uninstall docker-desktop (packaging only, MSI already removed)...'
      choco uninstall docker-desktop -y -n --skip-autouninstaller 2>&1 | Out-Host
    }
  }

  $dockerRoot = "${env:ProgramFiles}\Docker"
  if (Test-Path $dockerRoot) {
    Write-Step "Removing leftover folder: $dockerRoot"
    Remove-Item $dockerRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  $chocoLib = "$env:ChocolateyInstall\lib\docker-desktop"
  if (Test-Path $chocoLib) {
    Write-Step "Removing choco lib stub: $chocoLib"
    Remove-Item $chocoLib -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Remove-StandaloneMinikube {
  $paths = @(
    "${env:ProgramFiles}\Kubernetes\Minikube",
    "${env:ProgramFiles(x86)}\Kubernetes\Minikube",
    "$env:LOCALAPPDATA\minikube"
  )
  foreach ($p in $paths) {
    if (Test-Path $p) {
      Write-Step "Removing $p"
      Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

function Uninstall-ChocoInitPackages {
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

  foreach ($id in $packages) {
    $installed = choco list --local-only $id -r 2>$null
    if ($installed -match "^$([regex]::Escape($id))\|") {
      Write-Step "choco uninstall $id -y"
      choco uninstall $id -y --remove-dependencies 2>&1 | Out-Host
      if ($LASTEXITCODE -ne 0) {
        choco uninstall $id -y -n --skip-autouninstaller 2>&1 | Out-Host
      }
    }
  }
}

Write-Host ''
Write-Host '=== MIP init full cleanup ===' -ForegroundColor Yellow
Write-Host ''

Uninstall-DockerDesktop
Remove-StandaloneMinikube
Uninstall-ChocoInitPackages

Write-Host ''
Write-Host '=== Verification ===' -ForegroundColor Yellow
$tools = @('node', 'npm', 'docker', 'minikube', 'kubectl', 'helm')
foreach ($t in $tools) {
  $cmd = Get-Command $t -ErrorAction SilentlyContinue
  if ($cmd) {
    Write-Host "[STILL ON PATH] $t -> $($cmd.Source)" -ForegroundColor Red
  } else {
    Write-Host "[OK] $t not on PATH" -ForegroundColor Green
  }
}

$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if ($openssl) {
  Write-Host "[NOTE] openssl still on PATH: $($openssl.Source)" -ForegroundColor Yellow
  Write-Host '       If this is Strawberry Perl (not choco OpenSSL-Win64), it predates MIP init.' -ForegroundColor Yellow
  Write-Host '       init.ps1 installs choco openssl to Program Files\OpenSSL-Win64.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host '[OK] Cleanup finished. Reboot if Docker was installed.' -ForegroundColor Green
Write-Host 'Git via winget was kept so bootstrap can clone repos. Uninstall with: winget uninstall Git.Git' -ForegroundColor Gray
