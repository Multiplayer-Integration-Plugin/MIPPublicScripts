@echo off
setlocal EnableExtensions

set "RAW=https://raw.githubusercontent.com/Multiplayer-Integration-Plugin/MIPPublicScripts/main"
set "PS1=%~dp0bootstrap-mip.ps1"
rem Workspace = folder containing this batch file (works with spaces; not %%CD%%)
set "WORKSPACE=%~dp0"
if "%WORKSPACE:~-1%"=="\" set "WORKSPACE=%WORKSPACE:~0,-1%"

echo.
echo ========================================
echo   MIP bootstrap
echo ========================================
echo [INFO] Workspace: "%WORKSPACE%"
echo.

where curl >nul 2>&1
if errorlevel 1 (
  echo [ERROR] curl not found. Use Windows 10+ or install Git for Windows.
  goto :fail
)

echo [INFO] Downloading latest bootstrap-mip.ps1...
del "%PS1%" >nul 2>&1
curl -fsSL -H "Cache-Control: no-cache" "%RAW%/bootstrap-mip.ps1?v=7" -o "%PS1%"
if errorlevel 1 (
  echo [ERROR] Download failed. Check the URL and your network.
  goto :fail
)
echo [OK]   Downloaded bootstrap-mip.ps1
echo.

echo [INFO] Starting bootstrap (clone MIPScripts, install tools, mip-be)...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -WorkspaceRoot "%WORKSPACE%" -NoPause
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
powershell -NoProfile -Command "Write-Host 'Press any key to close, or wait 5 seconds...' -ForegroundColor Gray; $d=(Get-Date).AddSeconds(5); while((Get-Date) -lt $d){ if([Console]::KeyAvailable){ $null=[Console]::ReadKey($true); break }; Start-Sleep -Milliseconds 200 }"
exit /b %EXITCODE%
