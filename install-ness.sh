#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Simple installer for the Ness stack + privatenesstools
# Target: fresh-ish Debian/Ubuntu (apt-based) system with bash.
# Responsibilities:
#   - Install OS packages: git, curl, python3, python3-venv, python3-pip, docker (best-effort)
#   - Clone or update the EIP4361 repo under ~/ness.cx/EIP4361
#   - Create a Python virtualenv and install privatenesstools/requirements.txt
#   - Launch menu-v3.sh using the venv Python (PYTHON_BIN)

REPO_URL="https://github.com/ness-network/EIP4361.git"
BASE_DIR="${HOME}/ness.cx"
TARGET_DIR="${BASE_DIR}/EIP4361"
VENV_DIR="${TARGET_DIR}/.venv"

log() {
  printf '[installer] %s\n' "$*"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_apt() {
  if ! have_cmd apt-get; then
    log "This installer currently supports only apt-based systems (Debian/Ubuntu)."
    log "Please install: git, curl, python3, python3-venv, python3-pip, docker manually, then run menu-v3.sh."
    exit 1
  fi
}

sudo_prefix() {
  if [ "${EUID:-$(id -u)}" -ne 0 ] && have_cmd sudo; then
    printf 'sudo '
  else
    printf ''
  fi
}

install_os_packages() {
  require_apt
  local SUDO
  SUDO=$(sudo_prefix)

  log "Updating apt package index..."
  ${SUDO}apt-get update -y

  log "Installing base packages (git, curl, python3, venv, pip)..."
  ${SUDO}apt-get install -y git curl python3 python3-venv python3-pip

  log "Attempting to install Docker engine (docker.io) and docker-compose (best-effort)..."
  ${SUDO}apt-get install -y docker.io docker-compose || true

  if have_cmd systemctl; then
    log "Enabling and starting docker service (if available)..."
    ${SUDO}systemctl enable docker >/dev/null 2>&1 || true
    ${SUDO}systemctl start docker >/dev/null 2>&1 || true
  fi

  if have_cmd docker; then
    if ! docker ps >/dev/null 2>&1; then
      log "Docker is installed but not usable without root; you may need to re-login after adding your user to the 'docker' group."
      log "For example: sudo usermod -aG docker $USER && newgrp docker"
    fi
  else
    log "Docker CLI not found. You will be able to use privatenesstools, but Docker-based stack features will not work until Docker is installed."
  fi
}

clone_or_update_repo() {
  mkdir -p "$BASE_DIR"

  if [ -d "$TARGET_DIR/.git" ]; then
    log "Repository already exists at $TARGET_DIR, pulling latest changes..."
    (
      cd "$TARGET_DIR"
      git pull --ff-only || log "Warning: git pull failed (non-fast-forward or network issue). Continuing with existing checkout."
    )
  else
    log "Cloning repository into $TARGET_DIR..."
    git clone "$REPO_URL" "$TARGET_DIR"
  fi
}

setup_venv_and_python() {
  log "Setting up Python virtual environment at $VENV_DIR..."
  local PY_BIN
  if have_cmd python3; then
    PY_BIN="python3"
  else
    log "python3 not found even after apt install. Please install Python 3 and re-run."
    exit 1
  fi

  if [ ! -d "$VENV_DIR" ]; then
    "$PY_BIN" -m venv "$VENV_DIR"
  fi

  # shellcheck disable=SC1090
  source "$VENV_DIR/bin/activate"

  log "Upgrading pip inside venv..."
  pip install --upgrade pip

  if [ -f "$TARGET_DIR/privatenesstools/requirements.txt" ]; then
    log "Installing Python dependencies from privatenesstools/requirements.txt..."
    pip install -r "$TARGET_DIR/privatenesstools/requirements.txt"
  else
    log "requirements.txt not found at privatenesstools/requirements.txt; skipping pip install."
  fi
}

launch_menu() {
  # Use the venv Python for menu-v3.sh tests and helpers
  export PYTHON_BIN="$VENV_DIR/bin/python"

  cd "$TARGET_DIR"
  chmod +x menu-v3.sh || true

  log "Launching Menu V3..."
  ./menu-v3.sh
}

main() {
  log "Starting Ness installer (apt-based systems)..."
  install_os_packages
  clone_or_update_repo
  setup_venv_and_python
  log "Base installation complete."
  launch_menu
}

main "$@"
