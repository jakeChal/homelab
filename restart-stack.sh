#!/usr/bin/env bash
# Gracefully restart homelab docker compose services.
#
# Usage:
#   ./restart-stack.sh              # restart all services
#   ./restart-stack.sh memos vikunja  # restart only the named services

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

restart_service() {
    local service="$1"
    local compose_file="$script_dir/$service/docker-compose.yml"

    if [ ! -f "$compose_file" ]; then
        echo "Skipping '$service': no docker-compose.yml found at $compose_file" >&2
        return 1
    fi

    echo "Restarting $service..."
    docker compose -f "$compose_file" restart
}

if [ "$#" -eq 0 ]; then
    services=()
    for dir in "$script_dir"/*/; do
        service="$(basename "$dir")"
        [ -f "$dir/docker-compose.yml" ] && services+=("$service")
    done
else
    services=("$@")
fi

status=0
for service in "${services[@]}"; do
    restart_service "$service" || status=1
done

exit "$status"
