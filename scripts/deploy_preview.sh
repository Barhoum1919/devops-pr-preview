#!/usr/bin/env bash
set -e

PR_NUMBER=$1
OWNER="barhoum1919"
REPO="devops-pr-preview"
IMAGE="ghcr.io/${OWNER}/${REPO}/web:pr-${PR_NUMBER}"
CONTAINER_NAME="pr-$PR_NUMBER"
HOST_PORT=$((3000 + PR_NUMBER))

# Check GHCR token
if [ -z "$GHCR_PAT" ]; then
    echo "Error: GHCR_PAT environment variable is not set"
    exit 1
fi

# Login
echo "Logging into GHCR..."
echo $GHCR_PAT | docker login ghcr.io -u $OWNER --password-stdin

# Pull PR image
echo "Pulling PR image $IMAGE..."
docker pull "$IMAGE"

# Stop & remove old container
echo "Stopping old container $CONTAINER_NAME..."
docker stop $CONTAINER_NAME || true
docker rm $CONTAINER_NAME || true

# Run container
echo "Running PR container on port $HOST_PORT..."
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
    echo "Starting ngrok tunnel for PR #$PR_NUMBER..."
    pkill -f "ngrok http $HOST_PORT" || true
    nohup ngrok http $HOST_PORT  &>/dev/null &
    sleep 7
    NGROK_URL=$(curl --silent http://127.0.0.1:4040/api/tunnels \
        | jq -r ".tunnels[] | select(.config.addr==\"http://localhost:$HOST_PORT\") | .public_url")
fi

if [ -n "$NGROK_URL" ]; then
    PREVIEW_URL="$NGROK_URL"
    echo "🌐 PR #$PR_NUMBER preview available via ngrok: $PREVIEW_URL"
else
    PREVIEW_URL="http://127.0.0.1:$HOST_PORT"
    echo "⚠️ Ngrok not found. Access locally: $PREVIEW_URL"
fi

# Output for GitHub Actions
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "preview-url=$PREVIEW_URL" >> $GITHUB_OUTPUT
fi

echo "✅ PR #$PR_NUMBER deployed!"
