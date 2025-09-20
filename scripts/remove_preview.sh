#!/usr/bin/env bash
set -euo pipefail

PR="$1"
if [ -z "$PR" ]; then
  echo "Usage: $0 <pr-number>"
  exit 2
fi

CONTAINER_NAME="pr-$PR"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Stopping container $CONTAINER_NAME..."
docker stop "$CONTAINER_NAME" || echo "⚠️ Container not running or already stopped"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Removing container $CONTAINER_NAME..."
docker rm "$CONTAINER_NAME" || echo "⚠️ Container already removed or does not exist"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ PR preview container cleanup done."
