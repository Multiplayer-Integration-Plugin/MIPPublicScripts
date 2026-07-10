#Requires -Version 5.1
param(
  [string]$WorkspaceRoot = '',
  [string]$MipScriptsRepo = 'https://github.com/Multiplayer-Integration-Plugin/MIPScripts.git',
  [switch]$NoPause,
  [switch]$BootstrapElevated
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
  Write-Host 'Press any key to close, or wait 5 seconds...' -ForegroundColor Gray
  $deadline = (Get-Date).AddSeconds(5)
  while ((Get-Date) -lt $deadline) {
    if ([Console]::KeyAvailable) {
      $null = [Console]::ReadKey($true)
      return
    }
    Start-Sleep -Milliseconds 200
  }
}

function Test-IsAdmin {
  $identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  return $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Refresh-SessionPath {
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

function Test-CommandExists([string]$Name) {
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Resolve-WorkspaceRoot {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = (Get-Location).ProviderPath
  }

  $Path = $Path.TrimEnd('\', '/')
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Workspace path does not exist: $Path"
  }

  return (Resolve-Path -LiteralPath $Path).Path
}

function Start-PowerShellElevated {
  param(
    [string[]]$ArgumentList
  )

  return Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $ArgumentList -PassThru -Wait
}

function Stop-ChocolateyLockedProcesses {
  $chocoPath = Join-Path $env:ProgramData 'chocolatey'
  if (-not (Test-Path $chocoPath)) {
    return
  }

  Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -and $_.Path.StartsWith($chocoPath, [StringComparison]::OrdinalIgnoreCase)
  } | ForEach-Object {
    Write-Info "Stopping process locking Chocolatey: $($_.Name)"
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
  }

  foreach ($name in @('syncthing', 'nssm')) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
      Write-Info "Stopping $name"
      Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
  }

  Start-Sleep -Seconds 1
}

function Clear-ChocolateyPathEntries {
  foreach ($scope in @('Machine', 'User')) {
    $path = [Environment]::GetEnvironmentVariable('Path', $scope)
    if ($path -and $path -match 'chocolatey') {
      $newPath = ($path -split ';' | Where-Object { $_ -and $_ -notmatch 'chocolatey' }) -join ';'
      [Environment]::SetEnvironmentVariable('Path', $newPath, $scope)
    }
  }

  [Environment]::SetEnvironmentVariable('ChocolateyInstall', $null, 'Machine')
  [Environment]::SetEnvironmentVariable('ChocolateyLastPathUpdate', $null, 'Machine')
  Refresh-SessionPath
}

function Remove-BrokenChocolateyInstall {
  $chocoPath = Join-Path $env:ProgramData 'chocolatey'
  if (-not (Test-Path $chocoPath)) {
    Clear-ChocolateyPathEntries
    return
  }

  $chocoExe = Join-Path $chocoPath 'choco.exe'
  if ((Test-Path $chocoExe) -and (Test-CommandExists 'choco')) {
    return
  }

  Write-Info "Removing broken Chocolatey installation at $chocoPath"
  Stop-ChocolateyLockedProcesses

  & takeown.exe /f $chocoPath /r /d y 2>$null | Out-Null
  & icacls.exe $chocoPath /grant 'Administrators:F' /t /c /q 2>$null | Out-Null

  Remove-Item $chocoPath -Recurse -Force -ErrorAction SilentlyContinue

  if (Test-Path $chocoPath) {
    $trashPath = Join-Path $env:ProgramData ('chocolatey.removed.{0}' -f ([Guid]::NewGuid().ToString('N').Substring(0, 8)))
    try {
      Rename-Item -LiteralPath $chocoPath -NewName (Split-Path $trashPath -Leaf) -Force -ErrorAction Stop
      Remove-Item $trashPath -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
      # fall through to verification error below
    }
  }

  Clear-ChocolateyPathEntries

  if (Test-Path $chocoPath) {
    throw "Could not remove broken Chocolatey folder at $chocoPath. Stop Syncthing or other services using it, delete that folder manually as Administrator, then re-run bootstrap."
  }

  Write-Ok 'Broken Chocolatey folder removed'
}

function Install-Chocolatey {
  Remove-BrokenChocolateyInstall

  Write-Info 'Downloading Chocolatey from https://community.chocolatey.org/install.ps1 ...'
  Set-ExecutionPolicy Bypass -Scope Process -Force
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  Refresh-SessionPath
}

function Ensure-Chocolatey {
  if (Test-CommandExists 'choco') {
    $version = (& choco --version 2>$null | Select-Object -First 1)
    if ($version) {
      Write-Ok "Chocolatey $version"
      return
    }
  }

  Remove-BrokenChocolateyInstall

  Write-Step 'Installing Chocolatey'
  Write-Info 'Chocolatey is required to install Git and other MIP tools.'

  if (-not (Test-IsAdmin)) {
    throw 'Chocolatey is not installed. Administrator approval is required (click Yes on UAC).'
  }

  Install-Chocolatey

  if (-not (Test-CommandExists 'choco')) {
    throw 'Chocolatey install finished but choco is still not on PATH. Open a new Administrator terminal and re-run bootstrap.'
  }

  Write-Ok "Chocolatey $(choco --version) installed"
}

function Install-GitViaWinget {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    return $false
  }

  Write-Step 'Installing Git (winget)'
  Write-Info 'Running: winget install Git.Git'
  & winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements --disable-interactivity
  if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
    # -1978335189 = already installed
    Write-Info "winget exited with code $LASTEXITCODE"
    return $false
  }

  Refresh-SessionPath
  return (Test-CommandExists 'git')
}

function Install-GitViaChocolatey {
  Ensure-Chocolatey

  if (Test-CommandExists 'git') {
    Write-Ok 'git already on PATH'
    return
  }

  Write-Step 'Installing Git (Chocolatey)'
  Write-Info 'Running: choco install git -y'
  & choco install git -y
  if ($LASTEXITCODE -ne 0) {
    throw "choco install git failed with exit code $LASTEXITCODE"
  }

  Refresh-SessionPath

  if (-not (Test-CommandExists 'git')) {
    throw 'git install finished but git is still not on PATH. Open a new Command Prompt and re-run bootstrap-mip.bat.'
  }

  Write-Ok "git $(git --version)"
}

function Install-GitForBootstrap {
  if (Test-CommandExists 'git') {
    Write-Ok "git $(git --version)"
    return
  }

  if (Install-GitViaWinget) {
    Write-Ok "git $(git --version)"
    return
  }

  Write-Info 'winget install unavailable or failed; trying Chocolatey...'
  Install-GitViaChocolatey
}

function Wait-ElevatedWindow {
  Write-Host ''
  Write-Host "Log file: $ElevatedLogFile" -ForegroundColor Gray
  Write-Host 'Press any key to close this Administrator window...' -ForegroundColor Gray
  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Show-ElevatedLog {
  if (-not (Test-Path -LiteralPath $ElevatedLogFile)) {
    Write-Host "[WARN] No elevated log found at $ElevatedLogFile" -ForegroundColor Yellow
    return
  }

  Write-Host ''
  Write-Host '--- Administrator window log ---' -ForegroundColor Yellow
  Get-Content $ElevatedLogFile -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
  Write-Host '--- end log ---' -ForegroundColor Yellow
  Write-Info "Full log: $ElevatedLogFile"
}

function Invoke-ElevatedBootstrapPass {
  param([string]$Root)

  Remove-Item -LiteralPath $ElevatedLogFile -Force -ErrorAction SilentlyContinue

  $elevatedArgs = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $PSCommandPath,
    '-WorkspaceRoot', $Root,
    '-BootstrapElevated'
  )
  if ($NoPause) {
    $elevatedArgs += '-NoPause'
  }

  Write-Info 'Opening an Administrator PowerShell window (Git install)...'
  Write-Info 'Click Yes on the UAC prompt.'
  Write-Info "Administrator log: $ElevatedLogFile"

  try {
    $proc = Start-PowerShellElevated -ArgumentList $elevatedArgs
  } catch {
    if ($_.Exception.Message -match 'canceled by the user|operation was canceled') {
      throw 'UAC prompt was cancelled. Administrator approval is required to install Git.'
    }
    throw
  }

  if ($null -eq $proc.ExitCode -or $proc.ExitCode -ne 0) {
    $code = if ($null -eq $proc.ExitCode) { '(unknown)' } else { $proc.ExitCode }
    Show-ElevatedLog
    throw "Administrator install failed (exit $code). See log above or $ElevatedLogFile"
  }

  Write-Ok 'Administrator install finished.'
}

function Ensure-BootstrapPrerequisites {
  Refresh-SessionPath

  if (Test-CommandExists 'git') {
    Write-Ok "git $(git --version)"
    return
  }

  Write-Step 'Git required before clone'
  Write-Info 'Git is not installed. Bootstrap will install Git (winget or Chocolatey).'

  if (Test-IsAdmin) {
    Install-GitForBootstrap
    return
  }

  Invoke-ElevatedBootstrapPass -Root $WorkspaceRoot
  Refresh-SessionPath

  if (-not (Test-CommandExists 'git')) {
    throw 'git is still not on PATH after install. Open a new Command Prompt and re-run bootstrap-mip.bat.'
  }

  Write-Ok "git $(git --version)"
}

if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
  $WorkspaceRoot = (Get-Location).ProviderPath
}
$WorkspaceRoot = Resolve-WorkspaceRoot -Path $WorkspaceRoot
$MainLogFile = Join-Path $WorkspaceRoot 'mip-bootstrap.log'
$ElevatedLogFile = Join-Path $WorkspaceRoot 'mip-bootstrap-elevated.log'

if ($BootstrapElevated) {
  $elevatedTranscriptStarted = $false
  $elevatedExitCode = 0
  try {
    Remove-Item -LiteralPath $ElevatedLogFile -Force -ErrorAction SilentlyContinue
    Start-Transcript -Path $ElevatedLogFile -Force | Out-Null
    $elevatedTranscriptStarted = $true
    Write-Info "Administrator log: $ElevatedLogFile"
    Write-Info "Workspace root: $WorkspaceRoot"
    Write-Step 'Administrator bootstrap pass (Git install)'
    Install-GitForBootstrap
    Write-Ok 'Git install finished'
  } catch {
    $elevatedExitCode = 1
    Write-Err $_.Exception.Message
    if ($_.ScriptStackTrace) {
      Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    }
  } finally {
    if ($elevatedTranscriptStarted) {
      try { Stop-Transcript | Out-Null } catch { }
    }
    Wait-ElevatedWindow
  }
  exit $elevatedExitCode
}

$mainTranscriptStarted = $false
try {
  Remove-Item -LiteralPath $MainLogFile -Force -ErrorAction SilentlyContinue
  Start-Transcript -Path $MainLogFile -Force | Out-Null
  $mainTranscriptStarted = $true
  Write-Info "Install log: $MainLogFile"
  Write-Info "Administrator log (if UAC runs): $ElevatedLogFile"

  Write-Step 'MIP bootstrap starting'
  Write-Info "Workspace root: $WorkspaceRoot"
  Ensure-BootstrapPrerequisites

  $MipScriptsDir = Join-Path $WorkspaceRoot 'MIPScripts'

  if (-not (Test-Path -LiteralPath (Join-Path $MipScriptsDir '.git'))) {
    if (Test-Path -LiteralPath $MipScriptsDir) {
      throw "$MipScriptsDir exists but is not a git repo. Remove it and re-run bootstrap."
    }
    Write-Step 'Cloning MIPScripts'
    Write-Info "Repository: $MipScriptsRepo"
    Write-Info "Target:     $MipScriptsDir"
    & git clone --progress $MipScriptsRepo -- $MipScriptsDir
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
    $initLog = Join-Path $WorkspaceRoot 'mip-init.log'
    $initElevatedLog = Join-Path $WorkspaceRoot 'mip-init-elevated.log'
    if (Test-Path -LiteralPath $initElevatedLog) {
      Write-Host ''
      Write-Host '--- init.ps1 Administrator log ---' -ForegroundColor Yellow
      Get-Content $initElevatedLog -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
      Write-Host '--- end log ---' -ForegroundColor Yellow
    }
    throw "init.ps1 failed with exit code $LASTEXITCODE. Logs: $initLog and $initElevatedLog"
  }

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
  if (Test-Path -LiteralPath $ElevatedLogFile) {
    Show-ElevatedLog
  }
  Write-Info "Install log: $MainLogFile"
  if (-not $NoPause) { Wait-IfInteractive }
  exit 1
} finally {
  if ($mainTranscriptStarted) {
    try { Stop-Transcript | Out-Null } catch { }
  }
}

if (-not $NoPause) { Wait-IfInteractive }
exit 0
