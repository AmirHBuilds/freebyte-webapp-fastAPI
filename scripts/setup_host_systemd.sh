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

# Load env vars for optional host DB override inputs (POSTGRES_* / DATABASE_URL).
set -a
source "$REPO_DIR/.env"
set +a

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is not installed." >&2
  exit 1
fi

# Prefer app/runtime dependency list; fallback to legacy requirements if needed.
REQUIREMENTS_FILE="$REPO_DIR/requirements.docker.txt"
if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
  REQUIREMENTS_FILE="$REPO_DIR/requirements.txt"
fi

python3 -m venv "$VENV_DIR"

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  echo "Error: virtualenv python not found at $VENV_DIR/bin/python" >&2
  exit 1
fi

# Some hosts create venv without pip when python3-venv/ensurepip is missing.
if ! "$VENV_DIR/bin/python" -m pip --version >/dev/null 2>&1; then
  "$VENV_DIR/bin/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
fi

if ! "$VENV_DIR/bin/python" -m pip --version >/dev/null 2>&1; then
  echo "Error: pip is unavailable in the virtualenv." >&2
  echo "Install OS package 'python3-venv' (and python3-pip if needed), then re-run." >&2
  exit 1
fi

"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install -r "$REQUIREMENTS_FILE"

# Ensure critical runtime tools are present even if requirements drift.
"$VENV_DIR/bin/python" -m pip install fastapi "uvicorn[standard]" alembic

HOST_DATABASE_URL="$(
  DATABASE_URL="${DATABASE_URL:-}" \
  POSTGRES_DB="${POSTGRES_DB:-freebyte_app}" \
  POSTGRES_USER="${POSTGRES_USER:-postgres}" \
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}" \
  POSTGRES_PORT="${POSTGRES_PORT:-5432}" \
  python3 - <<'PY'
import os
from urllib.parse import urlparse

raw = os.getenv("DATABASE_URL", "").strip()
postgres_port = os.getenv("POSTGRES_PORT", "5432")

if not raw:
    user = os.getenv("POSTGRES_USER", "postgres")
    password = os.getenv("POSTGRES_PASSWORD", "postgres")
    db = os.getenv("POSTGRES_DB", "freebyte_app")
    print(f"postgresql://{user}:{password}@127.0.0.1:{postgres_port}/{db}")
    raise SystemExit(0)

parsed = urlparse(raw)
host = parsed.hostname or "127.0.0.1"
if host == "db":
    host = "127.0.0.1"

port = parsed.port
if port is None:
    port = int(postgres_port)
elif parsed.hostname == "db" and str(port) == "5432" and postgres_port:
    port = int(postgres_port)

username = parsed.username or os.getenv("POSTGRES_USER", "postgres")
password = parsed.password or os.getenv("POSTGRES_PASSWORD", "postgres")
db_name = (parsed.path or "/").lstrip("/") or os.getenv("POSTGRES_DB", "freebyte_app")
scheme = parsed.scheme or "postgresql"

print(f"{scheme}://{username}:{password}@{host}:{port}/{db_name}")
PY
)"

echo "Using host DATABASE_URL: $HOST_DATABASE_URL"

# Apply DB migrations before service start
DATABASE_URL="$HOST_DATABASE_URL" "$VENV_DIR/bin/python" -m alembic upgrade head

$SUDO tee "$UNIT_FILE" >/dev/null <<UNIT
[Unit]
Description=FreeByte FastAPI (host runtime)
After=network.target

[Service]
Type=simple
User=$RUN_USER
WorkingDirectory=$REPO_DIR
EnvironmentFile=$REPO_DIR/.env
Environment=DATABASE_URL=$HOST_DATABASE_URL
ExecStart=$VENV_DIR/bin/python -m uvicorn main:app --host $APP_HOST --port $APP_PORT
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
echo "Dependencies installed from: $REQUIREMENTS_FILE"
