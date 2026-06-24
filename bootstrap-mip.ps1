#Requires -Version 5.1
<#
.SYNOPSIS
  MIP workspace bootstrap for PowerShell (Windows).

.DESCRIPTION
  Clones MIPScripts into the current workspace, then runs init/init.ps1.

  Usage (PowerShell, from your UE workspace root):
    cd D:\Dev\YourProject
    irm https://raw.githubusercontent.com/Multiplayer-Integration-Plugin/MIPPublicScripts/main/bootstrap-mip.ps1 -OutFile bootstrap-mip.ps1
    .\bootstrap-mip.ps1

  Or one line (requires git on PATH):
    irm .../bootstrap-mip.ps1 | iex
#>
param(
  [string]$WorkspaceRoot = (Get-Location).Path,
  [string]$MipScriptsRepo = 'https://github.com/Multiplayer-Integration-Plugin/MIPScripts.git',
  [string]$MipScriptsBranch = 'main'
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
  Write-Info "Cloning MIPScripts into $MipScriptsDir"
  & git clone --branch $MipScriptsBranch --single-branch $MipScriptsRepo $MipScriptsDir
  if ($LASTEXITCODE -ne 0) {
    throw "git clone MIPScripts failed with exit code $LASTEXITCODE"
  }
} else {
  Write-Info "MIPScripts already present at $MipScriptsDir"
}

$InitPs1 = Join-Path $MipScriptsDir 'init\init.ps1'
if (-not (Test-Path -LiteralPath $InitPs1)) {
  throw "Missing $InitPs1 — update MIPScripts or re-run bootstrap after pulling latest MIPScripts."
}

Write-Info 'Running MIPScripts/init/init.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $InitPs1 -WorkspaceRoot $WorkspaceRoot
exit $LASTEXITCODE
