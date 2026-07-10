#!/usr/bin/env bash
# MIP workspace bootstrap (stage 1) — delegates to bootstrap-mip.ps1 on Windows.
#
# Usage (Git Bash, from your UE workspace root):
#   cd "/d/Unreal Projects/YourGame"
#   curl -fsSL https://raw.githubusercontent.com/Multiplayer-Integration-Plugin/MIPPublicScripts/main/bootstrap-mip.sh | bash
#
# Or set MIP_WORKSPACE_ROOT when piping (paths with spaces must be quoted):
#   MIP_WORKSPACE_ROOT="/d/Unreal Projects/YourGame" curl ... | bash
#
# Prefer Command Prompt + bootstrap-mip.bat for the same flow with clearer output.

set -euo pipefail

RAW="${MIP_RAW:-https://raw.githubusercontent.com/Multiplayer-Integration-Plugin/MIPPublicScripts/main}"

# Prefer explicit root (required for `curl ... | bash` when pwd is wrong). Supports paths with spaces.
if [[ -n "${MIP_WORKSPACE_ROOT:-}" ]]; then
  WORKSPACE_ROOT="$MIP_WORKSPACE_ROOT"
else
  WORKSPACE_ROOT="$(pwd)"
fi
WORKSPACE_ROOT="$(cd "$WORKSPACE_ROOT" && pwd -P)"
BOOTSTRAP_PS1="$WORKSPACE_ROOT/bootstrap-mip.ps1"

echo "[INFO] Workspace root: $WORKSPACE_ROOT"
echo "[INFO] Downloading bootstrap-mip.ps1..."
curl -fsSL "$RAW/bootstrap-mip.ps1" -o "$BOOTSTRAP_PS1"

echo "[INFO] Running bootstrap (Chocolatey, Git, MIPScripts, init)..."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$BOOTSTRAP_PS1" -WorkspaceRoot "$WORKSPACE_ROOT"
