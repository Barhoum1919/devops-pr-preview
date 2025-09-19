#!/usr/bin/env bash
set -e

OWNER="barhoum1919"
REPO="devops-pr-preview"
IMAGE="ghcr.io/${OWNER}/${REPO}/web:latest"
CONTAINER_NAME="base"
HOST_PORT=3000

# Check GHCR token
if [ -z "$GHCR_PAT" ]; then
    echo "Error: GHCR_PAT environment variable is not set"
    exit 1
fi

# Login
echo "Logging into GHCR..."
echo $GHCR_PAT | docker login ghcr.io -u $OWNER --password-stdin

# Pull latest image
echo "Pulling image $IMAGE..."
docker pull "$IMAGE"

# Stop & remove old container
echo "Stopping old container $CONTAINER_NAME..."
docker stop $CONTAINER_NAME || true
docker rm $CONTAINER_NAME || true

# Run container
echo "Running container on port $HOST_PORT..."
docker run -d --name $CONTAINER_NAME -p ${HOST_PORT}:80 "$IMAGE"

# Wait for health
echo "Waiting for container to become healthy..."
for i in {1..12}; do
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_NAME || echo "unknown")
    if [ "$HEALTH" == "healthy" ]; then
        echo "Container is healthy!"
        break
    fi
    echo "Container health: $HEALTH. Retrying in 5s..."
    sleep 5
done

# Start ngrok if available
NGROK_URL=""
if command -v ngrok &> /dev/null; then
    echo "Starting ngrok tunnel..."
    pkill -f "ngrok http $HOST_PORT" || true
    nohup ngrok http $HOST_PORT  &>/dev/null &
    sleep 7
    NGROK_URL=$(curl --silent http://127.0.0.1:4040/api/tunnels \
        | jq -r ".tunnels[] | select(.config.addr==\"http://localhost:$HOST_PORT\") | .public_url")
fi

if [ -n "$NGROK_URL" ]; then
    echo "🌐 Base app available via ngrok: $NGROK_URL"
else
    echo "⚠️ Ngrok not found. Access locally: http://127.0.0.1:$HOST_PORT"
fi

echo "✅ Base deployment complete!"
