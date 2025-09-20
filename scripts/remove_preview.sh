#!/usr/bin/env bash
set -e

PR="$1"
if [ -z "$PR" ]; then
  echo "Usage: $0 <pr-number>"
  exit 2
fi

CONTAINER_NAME="pr-$PR"
HOST_PORT=$((3000 + PR))

echo "Stopping and removing container $CONTAINER_NAME..."
docker stop "$CONTAINER_NAME" || true
docker rm "$CONTAINER_NAME" || true

echo "Stopping any ngrok tunnel for port $HOST_PORT..."
pkill -f "ngrok http $HOST_PORT" || true


IMAGE="ghcr.io/barhoum1919/devops-pr-preview/web:pr-$PR"
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Removing image $IMAGE..."
    docker rmi "$IMAGE" || true
fi

echo "Cleanup for PR #$PR complete!"
