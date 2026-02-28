#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="freebyte-web"
APP_PORT="8005"
APP_HOST="127.0.0.1"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$REPO_DIR/.venv-host"
UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "Error: run as root or install sudo." >&2
    exit 1
  fi
fi

RUN_USER="${SUDO_USER:-$(id -un)}"

cd "$REPO_DIR"

if [[ ! -f "$REPO_DIR/.env" ]]; then
  echo "Error: .env file not found in $REPO_DIR" >&2
  echo "Create .env first, then re-run this script." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is not installed." >&2
  exit 1
fi

python3 -m venv "$VENV_DIR"

# Some hosts create venv without pip when python3-venv/ensurepip is missing.
if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  echo "Error: virtualenv python not found at $VENV_DIR/bin/python" >&2
  exit 1
fi

if ! "$VENV_DIR/bin/python" -m pip --version >/dev/null 2>&1; then
  "$VENV_DIR/bin/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
fi

if ! "$VENV_DIR/bin/python" -m pip --version >/dev/null 2>&1; then
  echo "Error: pip is unavailable in the virtualenv." >&2
  echo "Install OS package 'python3-venv' (and python3-pip if needed), then re-run." >&2
  exit 1
fi

"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install -r "$REPO_DIR/requirements.txt"

# Apply DB migrations before service start
"$VENV_DIR/bin/alembic" upgrade head

$SUDO tee "$UNIT_FILE" >/dev/null <<UNIT
[Unit]
Description=FreeByte FastAPI (host runtime)
After=network.target

[Service]
Type=simple
User=$RUN_USER
WorkingDirectory=$REPO_DIR
EnvironmentFile=$REPO_DIR/.env
ExecStart=$VENV_DIR/bin/uvicorn main:app --host $APP_HOST --port $APP_PORT
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

$SUDO systemctl daemon-reload
$SUDO systemctl enable --now "$SERVICE_NAME"

$SUDO systemctl --no-pager --full status "$SERVICE_NAME" || true

if command -v curl >/dev/null 2>&1; then
  echo ""
  echo "Health check:"
  curl -I "http://${APP_HOST}:${APP_PORT}/home" || true
fi

echo ""
echo "Done. Nginx upstream should target: http://${APP_HOST}:${APP_PORT}"
