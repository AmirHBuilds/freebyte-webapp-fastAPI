# FreeByte FastAPI App (Dockerized)

This project is now Dockerized so you can run the full stack (FastAPI + PostgreSQL) with **one command**.

## One-click run with Docker

### Prerequisites
- Docker
- Docker Compose (v2)

### Run

```bash
docker compose up --build
```

Then open:
- App: http://localhost:8005/home

### Stop

```bash
docker compose down
```

### Reset everything (including database data)

```bash
docker compose down -v
```

## What runs

- `web`: FastAPI app (`uvicorn main:app --host 0.0.0.0 --port 8005`)
- `db`: PostgreSQL 16

`DATABASE_URL` is injected automatically by `docker-compose.yml`:

```text
postgresql://postgres:postgres@db:5432/freebyte_app
```

## Notes

- On container start, the app tries to run:

```bash
alembic upgrade head
```

If migration setup is incomplete for your current branch, startup will continue and print a warning.
