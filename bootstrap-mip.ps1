#Requires -Version 5.1
param(
  [string]$WorkspaceRoot = (Get-Location).Path,
  [string]$MipScriptsRepo = 'https://github.com/Multiplayer-Integration-Plugin/MIPScripts.git',
  [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) {
  Write-Host "[INFO] $Message"
}

function Write-Ok([string]$Message) {
  Write-Host "[OK]   $Message" -ForegroundColor Green
}

function Write-Err([string]$Message) {
  Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Step([string]$Message) {
  Write-Host ''
  Write-Host '========================================' -ForegroundColor Cyan
  Write-Host "  $Message" -ForegroundColor Cyan
  Write-Host '========================================' -ForegroundColor Cyan
}

function Wait-IfInteractive {
  if ($NoPause) { return }
  Write-Host ''
  Read-Host 'Press Enter to close this window'
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Err 'git is not on PATH. Install Git for Windows first (https://git-scm.com/download/win).'
  Wait-IfInteractive
  exit 1
}

$bootstrapSuccess = $false
try {
  Write-Step 'MIP bootstrap starting'

  $WorkspaceRoot = (Resolve-Path $WorkspaceRoot).Path
  $MipScriptsDir = Join-Path $WorkspaceRoot 'MIPScripts'

  Write-Info "Workspace root: $WorkspaceRoot"

  if (-not (Test-Path (Join-Path $MipScriptsDir '.git'))) {
    if (Test-Path $MipScriptsDir) {
      throw "$MipScriptsDir exists but is not a git repo. Remove it and re-run bootstrap."
    }
    Write-Step 'Cloning MIPScripts'
    Write-Info "Repository: $MipScriptsRepo"
    Write-Info "Target:     $MipScriptsDir"
    & git clone --progress $MipScriptsRepo $MipScriptsDir
    if ($LASTEXITCODE -ne 0) {
      throw "git clone MIPScripts failed with exit code $LASTEXITCODE"
    }
    Write-Ok 'MIPScripts cloned'
  } else {
    Write-Ok "MIPScripts already present at $MipScriptsDir"
  }

  $InitPs1 = Join-Path $MipScriptsDir 'init\init.ps1'
  if (-not (Test-Path -LiteralPath $InitPs1)) {
    throw ('Missing {0} - pull latest MIPScripts (git pull in MIPScripts/) and re-run bootstrap.' -f $InitPs1)
  }

  Write-Step 'Running MIPScripts/init/init.ps1'
  $initArgs = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $InitPs1,
    '-WorkspaceRoot', $WorkspaceRoot,
    '-NoPause'
  )

  & powershell.exe @initArgs
  if ($LASTEXITCODE -ne 0) {
    throw "init.ps1 failed with exit code $LASTEXITCODE"
  }

  $bootstrapSuccess = $true
  Write-Host ''
  Write-Host '========================================' -ForegroundColor Cyan
  Write-Host '  MIP BOOTSTRAP: SUCCESS' -ForegroundColor Green
  Write-Host '========================================' -ForegroundColor Cyan
} catch {
  Write-Host ''
  Write-Host '========================================' -ForegroundColor Cyan
  Write-Host '  MIP BOOTSTRAP: FAILED' -ForegroundColor Red
  Write-Host '========================================' -ForegroundColor Cyan
  Write-Err $_.Exception.Message
  if (-not $NoPause) { Wait-IfInteractive }
  exit 1
}

if (-not $NoPause) { Wait-IfInteractive }
exit 0
