# FreeByte FastAPI App (Dockerized)

## Security and secrets
- Sensitive values were removed from `private.py` (file deleted).
- App reads config from `.env` via `settings.py` (Pydantic Settings).

Edit `.env` before production use.

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

## Stop

```bash
docker compose down
```

## Reset database volume

```bash
docker compose down -v
```

## Notes

If you change models, create and apply migration:

```bash
alembic revision --autogenerate -m "describe change"
alembic upgrade head
```
