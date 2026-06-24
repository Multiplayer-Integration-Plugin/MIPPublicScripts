#Requires -Version 5.1
<#
.SYNOPSIS
  MIP workspace bootstrap for PowerShell (Windows).

.DESCRIPTION
  Clones MIPScripts into the current workspace, then runs init/init.ps1.

  Usage (Command Prompt, from your UE workspace root):
    cd /d D:\Dev\YourProject
    curl -fsSL .../bootstrap-mip.bat -o bootstrap-mip.bat
    bootstrap-mip.bat
#>
param(
  [string]$WorkspaceRoot = (Get-Location).Path,
  [string]$MipScriptsRepo = 'https://github.com/Multiplayer-Integration-Plugin/MIPScripts.git'
)

$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) {
  Write-Host "[INFO] $Message"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host '[ERROR] git is not on PATH. Install Git for Windows first (https://git-scm.com/download/win) or: choco install git -y' -ForegroundColor Red
  exit 1
}

$WorkspaceRoot = (Resolve-Path $WorkspaceRoot).Path
$MipScriptsDir = Join-Path $WorkspaceRoot 'MIPScripts'

Write-Info "Workspace root: $WorkspaceRoot"

if (-not (Test-Path (Join-Path $MipScriptsDir '.git'))) {
  if (Test-Path $MipScriptsDir) {
    Write-Host "[ERROR] $MipScriptsDir exists but is not a git repo. Remove it and re-run bootstrap." -ForegroundColor Red
    exit 1
  }
  Write-Info "Cloning MIPScripts into $MipScriptsDir"
  & git clone $MipScriptsRepo $MipScriptsDir
  if ($LASTEXITCODE -ne 0) {
    throw "git clone MIPScripts failed with exit code $LASTEXITCODE"
  }
} else {
  Write-Info "MIPScripts already present at $MipScriptsDir"
}

$InitPs1 = Join-Path $MipScriptsDir 'init\init.ps1'
if (-not (Test-Path -LiteralPath $InitPs1)) {
  throw "Missing $InitPs1 — pull latest MIPScripts (git pull in MIPScripts/) and re-run bootstrap."
}

Write-Info 'Running MIPScripts/init/init.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $InitPs1 -WorkspaceRoot $WorkspaceRoot
exit $LASTEXITCODE
