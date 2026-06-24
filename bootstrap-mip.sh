#!/usr/bin/env bash
# MIP workspace bootstrap (stage 1)
# Clone or update MIPScripts, then run init/init.ps1 for Windows tool + repo setup.
#
# Usage (Command Prompt, from your UE workspace root):
#   curl -fsSL https://raw.githubusercontent.com/Multiplayer-Integration-Plugin/MIPPublicScripts/main/bootstrap-mip.bat -o bootstrap-mip.bat
#   bootstrap-mip.bat
#
# Git Bash:
#   curl -fsSL https://raw.githubusercontent.com/Multiplayer-Integration-Plugin/MIPPublicScripts/main/bootstrap-mip.sh | bash
#
# Requires: Git Bash on Windows, GitHub access to MIPScripts and mip-be-users.

set -euo pipefail

MIPSCRIPTS_REPO="${MIPSCRIPTS_REPO:-https://github.com/Multiplayer-Integration-Plugin/MIPScripts.git}"
WORKSPACE_ROOT="$(pwd)"
MIPSCRIPTS_DIR="$WORKSPACE_ROOT/MIPScripts"

echo "[INFO] Workspace root: $WORKSPACE_ROOT"

if [[ ! -d "$MIPSCRIPTS_DIR/.git" ]]; then
  if [[ -e "$MIPSCRIPTS_DIR" ]]; then
    echo "[ERROR] $MIPSCRIPTS_DIR exists but is not a git repo. Remove it and re-run bootstrap."
    exit 1
  fi
  echo "[INFO] Cloning MIPScripts into $MIPSCRIPTS_DIR"
  git clone "$MIPSCRIPTS_REPO" "$MIPSCRIPTS_DIR"
else
  echo "[INFO] MIPScripts already present at $MIPSCRIPTS_DIR"
fi

INIT_PS1="$MIPSCRIPTS_DIR/init/init.ps1"
if [[ ! -f "$INIT_PS1" ]]; then
  echo "[ERROR] Missing $INIT_PS1"
  exit 1
fi

echo "[INFO] Running Windows init (MIPScripts/init/init.ps1)"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$INIT_PS1" -WorkspaceRoot "$WORKSPACE_ROOT"
