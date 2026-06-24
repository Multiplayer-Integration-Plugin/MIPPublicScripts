@echo off
setlocal EnableExtensions

set "RAW=https://raw.githubusercontent.com/Multiplayer-Integration-Plugin/MIPPublicScripts/main"
set "PS1=%~dp0bootstrap-mip.ps1"

echo.
echo ========================================
echo   MIP bootstrap
echo ========================================
echo [INFO] Workspace: %CD%
echo.

where curl >nul 2>&1
if errorlevel 1 (
  echo [ERROR] curl not found. Use Windows 10+ or install Git for Windows.
  goto :fail
)

where git >nul 2>&1
if errorlevel 1 (
  echo [ERROR] git not on PATH. Install Git for Windows first.
  goto :fail
)

echo [INFO] Downloading latest bootstrap-mip.ps1...
curl -fsSL "%RAW%/bootstrap-mip.ps1" -o "%PS1%"
if errorlevel 1 (
  echo [ERROR] Download failed. Check the URL and your network.
  goto :fail
)
echo [OK]   Downloaded bootstrap-mip.ps1
echo.

echo [INFO] Starting bootstrap (clone MIPScripts, install tools, mip-be)...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -WorkspaceRoot "%CD%" -NoPause
set "EXITCODE=%ERRORLEVEL%"
echo.

if "%EXITCODE%"=="0" (
  echo ========================================
  echo   MIP BOOTSTRAP: SUCCESS
  echo ========================================
  goto :done
)

echo ========================================
echo   MIP BOOTSTRAP: FAILED ^(exit %EXITCODE%^)
echo ========================================
goto :done

:fail
set "EXITCODE=1"

:done
echo.
pause
exit /b %EXITCODE%
