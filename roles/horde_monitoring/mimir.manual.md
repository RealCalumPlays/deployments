> **Historical reference only.** This manual walkthrough predates the
> `horde_monitoring` Ansible role, which now automates the entire Mimir +
> Grafana deployment. For current instructions see
> [roles/horde_monitoring/README.md](README.md) and [MONITORING.md](../../MONITORING.md).
>
> The document is retained as a reference for understanding what the role
> automates and for ad-hoc troubleshooting on hosts where Ansible is not
> available.

---

Below is a **complete hands-on walkthrough** to deploy **Grafana Mimir in monolithic mode with persistent filesystem storage using Docker Compose and managed by systemd**.

The guide assumes:

- Linux host (Ubuntu/Debian/RHEL-like)
- Docker already installed
- running as a sudo-capable user
- hostname example: `mimir01`

---

# 1. Install Docker and Docker Compose (if needed)

Check first:

```bash
docker --version
docker compose version
```

If not installed (Ubuntu/Debian):

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
```

Enable Docker at boot:

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

Then log out and back in.

---

# 2. Create Standard Linux Directory Layout

| Purpose         | Path             |
| --------------- | ---------------- |
| config          | `/etc/mimir`     |
| persistent data | `/var/lib/mimir` |
| compose stack   | `/opt/mimir`     |

Create directories:

```bash
sudo mkdir -p /etc/mimir
sudo mkdir -p /var/lib/mimir/tsdb
sudo mkdir -p /var/lib/mimir/data/{tsdb,tsdb-sync,compactor,rules}
sudo mkdir -p /opt/mimir
```

Set ownership:

```bash
sudo chown -R root:docker /var/lib/mimir
sudo chmod -R 775 /var/lib/mimir
```

---

# 3. Create the Mimir Configuration

Create:

```bash
sudo nano /etc/mimir/mimir.yaml
```

Paste:

```yaml
# Based on the official Grafana Mimir monolithic/filesystem demo config.
# Not recommended for production — use object storage (S3/GCS) for production.
multitenancy_enabled: false

server:
  http_listen_port: 9009
  log_level: info

blocks_storage:
  backend: filesystem
  bucket_store:
    sync_dir: /mimir/data/tsdb-sync
  filesystem:
    dir: /mimir/data/tsdb
  tsdb:
    dir: /mimir/tsdb

compactor:
  data_dir: /mimir/data/compactor
  sharding_ring:
    kvstore:
      store: memberlist

distributor:
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: memberlist

ingester:
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: memberlist
    replication_factor: 1

ruler_storage:
  backend: filesystem
  filesystem:
    dir: /mimir/data/rules

store_gateway:
  sharding_ring:
    replication_factor: 1

usage_stats:
  enabled: false
```

# 4. Create the Docker Compose Stack

Create:

```bash
sudo nano /opt/mimir/docker-compose.yml
```

Paste:

```yaml
version: "3.9"

services:
  mimir:
    image: grafana/mimir:latest
    container_name: mimir

    command:
      - "-config.file=/etc/mimir/mimir.yaml"
      - "-target=all"

    ports:
      - "127.0.0.1:9009:9009" # Bind to localhost for security - Mimir has no auth, so don't expose it publicly!

    volumes:
      - /etc/mimir/mimir.yaml:/etc/mimir/mimir.yaml:ro
      - /var/lib/mimir:/mimir/

    restart: unless-stopped

    ulimits:
      nofile:
        soft: 65536
        hard: 65536

    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:9009/ready"]
      interval: 30s
      timeout: 5s
      retries: 3
```

# 5. Test the Deployment Manually

Before integrating systemd, confirm it works.

```bash
cd /opt/mimir
sudo docker compose up -d

# Check containers:
sudo docker ps
> mimir   grafana/mimir

# Check logs:
sudo docker logs mimir

# Verify readiness:
curl http://localhost:9009/ready
```

Expected (without a carriage return, look at the start of the console output):

```
ready
```

If it works, stop the stack:

```bash
sudo docker compose down
```

---

# 6. Create systemd Service

Create the service:

```bash
sudo nano /etc/systemd/system/mimir.service
```

Paste:

```ini
[Unit]
Description=Grafana Mimir (Docker Compose)
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=/opt/mimir
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
RemainAfterExit=yes
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

Save and exit.

---

# 7. Register the Service

Reload systemd:

```bash
sudo systemctl daemon-reload
```

Enable at boot:

```bash
sudo systemctl enable mimir
```

---

# 8. Start Mimir

```bash
sudo systemctl start mimir
systemctl status mimir
```

You should see:

```
Active: active (exited)
```

This is expected because Compose detached the container.

---

# 9. Verify Container Is Running

Check:

```bash
sudo docker ps

curl http://localhost:9009/ready # Should return "ready" (without a carriage return)
```

---

# 10. Check Logs

Via Docker:

```bash
docker logs -f mimir
```

Or systemd:

```bash
journalctl -u mimir -f
```

---

# 11. Configure Prometheus Remote Write

Example snippet for Prometheus:

```yaml
remote_write:
  - url: http://mimir01:9009/api/v1/push
    basic_auth: # Optional, but recommended since Mimir has no built-in auth. Use a reverse proxy with basic auth if exposing publicly. See the optional section below for an example haproxy config.
      username: prom
      password: prom_password
```

---

# 12. Configure Grafana

Add a Prometheus datasource.

URL:

```
http://mimir01:9009/prometheus
```

---

# 13. Verify Data Persistence

Restart the service:

```bash
sudo systemctl restart mimir
```

Check that data still exists:

```bash
ls /var/lib/mimir
```

You should see directories like:

```
data
tsdb
```

---

# 14. Backup Strategy

Backup the entire directory:

```
/var/lib/mimir
```

Example:

```bash
sudo tar czf mimir-backup.tar.gz /var/lib/mimir
```

---

# 15. Firewall (Optional)

Allow access to the API:

```bash
sudo ufw allow 9009/tcp
```

# 16. Routing and Domain Mapping (Optional)

If you want to access Mimir via a domain name, set up a reverse proxy (e.g., Nginx, haproxy) to forward requests from your domain to `http://localhost:9009`.

Note that Mimir has no built-in authentication, so ensure you secure access appropriately if exposing it publicly.

## Example Haproxy Configuration

To your haproxy.cfg:

```bash
userlist mimir_users  # This must appear before the frontend/backend definitions where it's used
    user prom password $apr1$randomsalt$hashedpassword # Use mkpasswd to generate this
    user grafana password $apr1$randomsalt$hashedpassword
    # Add more users as needed

# This is just an example snippet. Integrate it into your existing frontend/backend configuration.
frontend your_frontend
    maxconn 30000
    bind *:80
    bind *:443 ssl crt /etc/haproxy/cert/yourdomain.pem
    http-request redirect scheme https unless { ssl_fc }
    http-request set-header X-Forwarded-Proto https if { ssl_fc }
    http-request set-header X-Forwarded-Port %[dst_port]
    http-request set-header X-Real-IP %[src]
    http-request set-header Host %[req.hdr(host)]
    http-response set-header X-Cache-Status HIT if !{ srv_id -m found }
    http-response set-header X-Cache-Status MISS if { srv_id -m found }

    # Mimir backend
    acl mimir_acl hdr(host) -i mimir.yourdomain.com
    http-request auth realm Mimir if mimir_acl !{ http_auth(mimir_users) }
    use_backend mimir_backend if mimir_acl

    # The rest of your routing rules...

backend mimir_backend
   balance leastconn
   timeout queue 30s
   retries 3
   option forwardfor if-none

   server mimir_server 127.0.0.1:9009 check observe layer7
   http-check expect ! rstatus ^5

   http-request set-header host mimir.yourdomain.com


```
