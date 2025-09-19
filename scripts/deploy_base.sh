#!/usr/bin/env bash
set -e

DOMAIN_NAME=$1
IMAGE_TAG=$2
HOST_PORT=3000
OWNER="barhoum1919"
REPO="devops-pr-preview"
IMAGE="ghcr.io/${OWNER}/${REPO}/web:${IMAGE_TAG}"

echo "Logging into GHCR..."
echo $GHCR_PAT | docker login ghcr.io -u $OWNER --password-stdin

echo "Pulling image $IMAGE..."
docker pull "$IMAGE"

echo "Stopping old container..."
docker stop base || true
docker rm base || true

echo "Running new container..."
docker run -d --name base -p ${HOST_PORT}:80 "$IMAGE"

echo "Waiting for container to start..."
sleep 5

# Check if container is healthy
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' base || echo "unknown")
echo "Container health: $HEALTH"

# Start ngrok if available
if command -v ngrok &> /dev/null; then
    echo "Starting ngrok..."
    pkill -f "ngrok http $HOST_PORT" || true
    nohup ngrok http $HOST_PORT --region=eu &>/dev/null &
    sleep 5
    NGROK_URL=$(curl --silent http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')
    echo "🌐 App preview available via ngrok: $NGROK_URL"
fi

echo "✅ Deployment complete!"
