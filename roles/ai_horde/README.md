# AI-Horde Deploy Role

Deploys the **AI-Horde backend** (Flask + PostgreSQL + Redis) as a Docker
Compose stack managed by systemd.

## Requirements

- **Docker** + **Docker Compose V2** (the role verifies both are present)
- **Ansible 2.14+**
- **Git** (to clone the AI-Horde source for the Docker build)

## How It Works

1. **Validate** — Fails fast if `ai_horde_postgres_password` or
   `ai_horde_secret_key` are not set.
2. **Clone source** — Clones the AI-Horde Git repo into
   `{{ ai_horde_base_dir }}/src` (used as the Docker build context).
3. **Create directories** — Sets up `base_dir` and `data_dir` with
   restrictive permissions (`0750`).
4. **Render configs** — Templates `.env` (credentials, feature flags),
   `docker-compose.yml` (three services with health checks), and a
   systemd unit file.
5. **Start services** — Enables and starts the systemd unit, which runs
   `docker compose build --pull && docker compose up -d`.
6. **Wait for readiness** — Waits for PostgreSQL, Redis, and the AI-Horde
   heartbeat endpoint before declaring success.

Steps 5–6 are skipped when `ai_horde_start_services: false` (useful for
CI/test environments where only config rendering is needed).

## Role Variables

### Required (no default — fail-fast)

| Variable                     | Description                          |
| ---------------------------- | ------------------------------------ |
| `ai_horde_postgres_password` | PostgreSQL password                  |
| `ai_horde_secret_key`        | Flask secret key for session signing |

### Optional

| Variable                  | Default                                       | Description                                      |
| ------------------------- | --------------------------------------------- | ------------------------------------------------ |
| `ai_horde_repo`           | `https://github.com/Haidra-Org/AI-Horde.git`  | Git repo URL                                     |
| `ai_horde_repo_version`   | `main`                                        | Git ref (branch, tag, or SHA)                    |
| `ai_horde_postgres_image` | `ghcr.io/haidra-org/ai-horde-postgres:latest` | PostgreSQL Docker image                          |
| `ai_horde_redis_image`    | `redis:7-alpine`                              | Redis Docker image                               |
| `ai_horde_port`           | `7001`                                        | Published HTTP port                              |
| `ai_horde_listen`         | `127.0.0.1`                                   | Bind address for host port mapping               |
| `ai_horde_horde_type`     | `stable`                                      | Horde type identifier                            |
| `ai_horde_verbosity`      | `-vvvvi`                                      | Application log verbosity                        |
| `ai_horde_base_dir`       | `/opt/ai-horde`                               | Working directory for compose and source         |
| `ai_horde_data_dir`       | `/var/lib/ai-horde`                           | Persistent data directory (postgres, redis)      |
| `ai_horde_postgres_user`  | `postgres`                                    | PostgreSQL username                              |
| `ai_horde_postgres_db`    | `postgres`                                    | PostgreSQL database name                         |
| `ai_horde_admins`         | `[]`                                          | List of admin usernames (written to .env ADMINS) |
| `ai_horde_env_overrides`  | `{}`                                          | Dict of extra env vars merged into .env          |
| `ai_horde_log_driver`     | `local`                                       | Docker log driver                                |
| `ai_horde_log_max_size`   | `50m`                                         | Max log file size per container                  |
| `ai_horde_log_max_file`   | `5`                                           | Number of rotated log files to keep              |
| `ai_horde_start_services` | `true`                                        | Set false to render configs without starting     |
| `ai_horde_force_build`    | `false`                                       | Force Docker image rebuild                       |

## Security Notes

- The `.env` file is rendered with mode `0600` (root-only readable) since
  it contains database credentials and the Flask secret key.
- The `docker-compose.yml` is also `0600` to protect the image references.
- The role **refuses to run** if `ai_horde_postgres_password` or
  `ai_horde_secret_key` are undefined or empty — no silent fallback to
  insecure defaults.

## Example Playbook

```yaml
- name: Deploy AI-Horde backend
  hosts: horde_server
  become: true
  roles:
    - role: ai_horde
      vars:
        ai_horde_postgres_password: "{{ vault_ai_horde_pg_password }}"
        ai_horde_secret_key: "{{ vault_ai_horde_secret_key }}"
        ai_horde_listen: "127.0.0.1"
        ai_horde_admins: ["admin_user#1"]
```

## Relationship to Other Roles

The AI-Horde backend is the hub that workers and frontends connect to:

```
Worker (horde_regen_worker)  ──[horde_url]──▶  AI-Horde  ◀──[API]──  Artbot
```

- **`horde_regen_worker`** connects via `horde_url` in `bridgeData.yaml`.
  Deploy AI-Horde first, then point workers at it.
- **`artbot`** connects via the public API URL.
- **`horde_stats_exporter`** scrapes the public API for Prometheus metrics.

## Testing

```bash
# Render-only test (no Docker daemon needed)
./tests/run_tests.sh ai_horde

# Integration smoke test (config coherence)
./tests/run_tests.sh integration

# Local deploy (requires Docker)
./tests/ai_horde/local_deploy.sh up
./tests/ai_horde/local_deploy.sh down

# Full integration with probe
./tests/integration/local_deploy.sh up
./tests/integration/local_deploy.sh down
```

## License

AGPL-3.0-or-later
