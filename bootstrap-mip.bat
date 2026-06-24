@echo off
setlocal EnableExtensions

set "RAW=https://raw.githubusercontent.com/Multiplayer-Integration-Plugin/MIPPublicScripts/main"
set "PS1=%~dp0bootstrap-mip.ps1"

echo [INFO] MIP bootstrap
echo [INFO] Workspace: %CD%

where curl >nul 2>&1
if errorlevel 1 (
  echo [ERROR] curl not found. Use Windows 10+ or install Git for Windows.
  exit /b 1
)

where git >nul 2>&1
if errorlevel 1 (
  echo [ERROR] git not on PATH. Install Git for Windows first.
  exit /b 1
)

if not exist "%PS1%" (
  echo [INFO] Downloading bootstrap-mip.ps1...
  curl -fsSL "%RAW%/bootstrap-mip.ps1" -o "%PS1%"
  if errorlevel 1 (
    echo [ERROR] Download failed. Check the URL and your network.
    exit /b 1
  )
)

echo [INFO] Starting bootstrap (clone MIPScripts, install tools, mip-be)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -WorkspaceRoot "%CD%"
exit /b %ERRORLEVEL%
