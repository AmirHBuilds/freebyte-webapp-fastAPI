# FreeByte FastAPI App

## Security and secrets
- Sensitive values were removed from `private.py` (file deleted).
- App reads config from `.env` via `settings.py` (Pydantic Settings).

Edit `.env` before production use.

## One-click host run (systemd, no Docker)

If you want Nginx to proxy to localhost on port `8005`, run:

```bash
bash scripts/setup_host_systemd.sh
```

What this script does:
1. Creates `.venv-host`
2. Installs `requirements.txt`
3. Runs `alembic upgrade head`
4. Creates and enables `freebyte-web.service`
5. Starts Uvicorn on `127.0.0.1:8005` permanently via systemd

Useful systemd commands:

```bash
sudo systemctl status freebyte-web
sudo journalctl -u freebyte-web -f
sudo systemctl restart freebyte-web
```

Nginx upstream should be:

```nginx
proxy_pass http://127.0.0.1:8005;
```

## Run with Docker (db -> migrate -> web)

```bash
docker compose up --build
```

Startup order:
1. `db` starts (PostgreSQL)
2. `migrate` runs `alembic upgrade head`
3. `web` starts only after migration succeeds

No custom entrypoint script is used; each service runs its own explicit command in `docker-compose.yml`.

App URL:
- http://localhost:${APP_PORT:-8005}/home

## Stop Docker

```bash
docker compose down
```

## Reset Docker database volume

```bash
docker compose down -v
```

## Migration notes

If you change models, create and apply migration:

```bash
alembic revision --autogenerate -m "describe change"
alembic upgrade head
```
