#!/usr/bin/env bash
# MIP workspace bootstrap (stage 1) — delegates to bootstrap-mip.ps1 on Windows.
#
# Usage (Git Bash, from your UE workspace root):
#   curl -fsSL https://raw.githubusercontent.com/Multiplayer-Integration-Plugin/MIPPublicScripts/main/bootstrap-mip.sh | bash
#
# Prefer Command Prompt + bootstrap-mip.bat for the same flow with clearer output.

set -euo pipefail

RAW="${MIP_RAW:-https://raw.githubusercontent.com/Multiplayer-Integration-Plugin/MIPPublicScripts/main}"
WORKSPACE_ROOT="$(pwd)"
PS1="$WORKSPACE_ROOT/bootstrap-mip.ps1"

echo "[INFO] Workspace root: $WORKSPACE_ROOT"
echo "[INFO] Downloading bootstrap-mip.ps1..."
curl -fsSL "$RAW/bootstrap-mip.ps1" -o "$PS1"

echo "[INFO] Running bootstrap (Chocolatey, Git, MIPScripts, init)..."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS1" -WorkspaceRoot "$WORKSPACE_ROOT"
