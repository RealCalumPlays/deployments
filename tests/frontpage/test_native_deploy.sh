#!/usr/bin/env bash

# Test native (bare-metal) deployment of AiHordeFrontpage.
#
# Spins up a fresh Debian bookworm container with systemd, runs the
# Ansible role in native mode against it, then verifies the service
# starts and serves HTTP on the expected port.
#
# This validates that: non-Docker deployment works on a clean Debian
# system, Node.js gets installed from NodeSource, the Angular app
# builds and starts, and the systemd unit is functional.
#
# Usage:
#   ./tests/frontpage/test_native_deploy.sh          # run full test
#   ./tests/frontpage/test_native_deploy.sh cleanup   # remove container

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONTAINER_NAME="frontpage-native-test"
IMAGE="debian:bookworm"
FRONTPAGE_PORT="${FRONTPAGE_PORT:-8006}"

# Colours
if [ -t 1 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; CYAN=''; NC=''
fi

log()  { printf "${GREEN}[+]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
err()  { printf "${RED}[x]${NC} %s\n" "$*" >&2; }
info() { printf "${CYAN}[i]${NC} %s\n" "$*"; }

cleanup() {
  log "Cleaning up test container ..."
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
  log "Cleanup complete."
}

wait_for_url() {
  local url="$1" label="$2" timeout="${3:-180}"
  local retries=$(( timeout / 3 ))
  while [ $retries -gt 0 ]; do
    if docker exec "$CONTAINER_NAME" curl -sf "$url" >/dev/null 2>&1; then
      log "$label is ready."
      return 0
    fi
    retries=$((retries - 1))
    sleep 3
  done
  warn "$label did not become ready within ${timeout}s"
  return 1
}

start_container() {
  # Remove any leftover container
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

  log "Starting fresh Debian bookworm container with systemd ..."

  # Build a minimal image with systemd pre-installed
  local build_dir
  build_dir=$(mktemp -d)
  cat > "$build_dir/Dockerfile" <<'EOF'
FROM debian:bookworm
RUN apt-get update -qq && \
    apt-get install -y -qq systemd systemd-sysv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
CMD ["/lib/systemd/systemd"]
EOF
  docker build -q -t debian-systemd:bookworm "$build_dir" >/dev/null
  rm -rf "$build_dir"

  docker run -d \
    --name "$CONTAINER_NAME" \
    --hostname frontpage-test \
    --privileged \
    --cgroupns=host \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    -p "127.0.0.1:${FRONTPAGE_PORT}:${FRONTPAGE_PORT}" \
    debian-systemd:bookworm

  # Wait for systemd to be ready
  local retries=30
  while [ $retries -gt 0 ]; do
    if docker exec "$CONTAINER_NAME" systemctl is-system-running 2>/dev/null | grep -qE 'running|degraded'; then
      break
    fi
    retries=$((retries - 1))
    sleep 2
  done
  log "Container systemd is up."
}

install_prereqs() {
  log "Installing base packages in the container ..."
  docker exec "$CONTAINER_NAME" bash -c "
    apt-get update -qq &&
    apt-get install -y -qq python3 rsync git curl sudo >/dev/null 2>&1
  "
  log "Base packages installed."
}

copy_role() {
  log "Verifying Ansible is available on the host ..."
  local ansible_playbook
  if [ -x "$REPO_ROOT/.venv/bin/ansible-playbook" ]; then
    ansible_playbook="$REPO_ROOT/.venv/bin/ansible-playbook"
  else
    ansible_playbook="$(command -v ansible-playbook 2>/dev/null || true)"
  fi
  if [ -z "$ansible_playbook" ]; then
    err "ansible-playbook not found on host."
    exit 1
  fi
  ANSIBLE_PLAYBOOK="$ansible_playbook"
  log "Using: $ANSIBLE_PLAYBOOK"
}

run_playbook() {
  log "Running Ansible playbook (native deploy) via docker connection ..."
  log "This will install Node.js from NodeSource and build the Angular app ..."
  ANSIBLE_ROLES_PATH="$REPO_ROOT/roles" \
    "$ANSIBLE_PLAYBOOK" \
      -i "$CONTAINER_NAME," \
      -c docker \
      "$SCRIPT_DIR/test_native_deploy.yml" \
      -v
  log "Ansible playbook completed."
}

verify_service() {
  log "Verifying AiHordeFrontpage service is running ..."

  # Check systemd unit is active
  docker exec "$CONTAINER_NAME" systemctl is-active aihorde-frontpage || {
    err "systemd unit aihorde-frontpage is not active."
    docker exec "$CONTAINER_NAME" journalctl -u aihorde-frontpage --no-pager -n 30
    return 1
  }
  log "systemd unit is active."

  # Wait for HTTP response
  wait_for_url "http://127.0.0.1:${FRONTPAGE_PORT}/" "AiHordeFrontpage" 180 || {
    err "AiHordeFrontpage did not respond on port ${FRONTPAGE_PORT}."
    docker exec "$CONTAINER_NAME" journalctl -u aihorde-frontpage --no-pager -n 50
    return 1
  }

  # Verify health endpoint
  docker exec "$CONTAINER_NAME" curl -sf "http://127.0.0.1:${FRONTPAGE_PORT}/healthz" || {
    err "Health endpoint /healthz did not respond."
    return 1
  }
  log "Health endpoint responded OK."

  # Verify we get HTML from the root
  local body
  body=$(docker exec "$CONTAINER_NAME" curl -sf "http://127.0.0.1:${FRONTPAGE_PORT}/")
  if echo "$body" | grep -qi 'html'; then
    log "Root path returned HTML content."
  else
    warn "Root path response does not appear to be HTML."
  fi

  log "All verifications passed."
}

print_summary() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  info "Native deployment test PASSED"
  info "Container: $CONTAINER_NAME"
  info "Cleanup:   $0 cleanup"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}


main() {
  local cmd="${1:-test}"

  case "$cmd" in
    test)
      start_container
      install_prereqs
      copy_role
      run_playbook
      verify_service
      print_summary
      ;;
    cleanup)
      cleanup
      ;;
    *)
      echo "Usage: $0 {test|cleanup}"
      exit 1
      ;;
  esac
}

main "$@"
