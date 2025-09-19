#!/usr/bin/env bash
set -e

DOMAIN_NAME=${1:-barhoum1919}
IMAGE_TAG=${2:-latest}
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

echo "Running container on port $HOST_PORT..."
docker run -d --name base -p ${HOST_PORT}:80 "$IMAGE"

echo "Waiting for container to become healthy..."
for i in {1..10}; do
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' base || echo "unknown")
    if [[ "$HEALTH" == "healthy" ]]; then
        echo "Container is healthy!"
        break
    fi
    echo "Waiting..."
    sleep 3
done

# Start ngrok
NGROK_URL=""
if command -v ngrok &> /dev/null; then
    echo "Starting ngrok..."
    pkill -f "ngrok http $HOST_PORT" || true
    nohup ngrok http $HOST_PORT --region=eu &>/dev/null &
    sleep 5

    # Wait until ngrok URL responds
    for i in {1..12}; do
        NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')
        if curl -s --head --fail "$NGROK_URL" >/dev/null 2>&1; then
            echo "Ngrok URL is reachable: $NGROK_URL"
            break
        fi
        echo "Waiting for ngrok tunnel to become reachable..."
        sleep 5
    done
fi

PREVIEW_URL=${NGROK_URL:-"http://127.0.0.1:$HOST_PORT"}
echo "🌐 Base app available via: $PREVIEW_URL"

# Output for GitHub Actions
echo "preview-url=$PREVIEW_URL" >> $GITHUB_OUTPUT
echo "✅ Deployment complete!"
