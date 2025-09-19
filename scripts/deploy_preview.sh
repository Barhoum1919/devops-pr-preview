#!/usr/bin/env bash
set -e

PR_NUMBER=$1
DOMAIN_NAME=${2:-barhoum1919}
OWNER="barhoum1919"
REPO="devops-pr-preview"
IMAGE="ghcr.io/${OWNER}/${REPO}/web:pr-${PR_NUMBER}"
HOST_PORT=$((3000 + PR_NUMBER))

if [ -z "$GHCR_PAT" ]; then
    echo "Error: GHCR_PAT environment variable is not set"
    exit 1
fi

echo "Logging into GHCR..."
echo $GHCR_PAT | docker login ghcr.io -u $OWNER --password-stdin

echo "Pulling PR image $IMAGE..."
docker pull "$IMAGE"

CONTAINER_NAME="pr-$PR_NUMBER"
echo "Stopping old container $CONTAINER_NAME..."
docker stop $CONTAINER_NAME || true
docker rm $CONTAINER_NAME || true

echo "Running PR container on port $HOST_PORT..."
docker run -d --name $CONTAINER_NAME -p ${HOST_PORT}:80 "$IMAGE"

echo "Waiting for container to start..."
sleep 5

HEALTH=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_NAME || echo "unknown")
echo "Container health: $HEALTH"

NGROK_URL=""
if command -v ngrok &> /dev/null; then
    echo "Starting ngrok tunnel for PR #$PR_NUMBER..."
    pkill -f "ngrok http $HOST_PORT" || true
    nohup ngrok http $HOST_PORT --region=eu &>/dev/null &
    sleep 5
    NGROK_URL=$(curl --silent http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')
fi
if [ -n "$NGROK_URL" ]; then
    echo "🌐 PR #$PR_NUMBER preview available via ngrok: $NGROK_URL"
    PREVIEW_URL="$NGROK_URL"
else
    PREVIEW_URL="http://127.0.0.1:$HOST_PORT"
    echo "⚠️ Ngrok not found. Access locally: $PREVIEW_URL"
fi

# Output preview URL for GitHub Actions
echo "preview-url=$PREVIEW_URL"
echo "✅ PR #$PR_NUMBER deployed!"
echo "preview-url=$PREVIEW_URL" >> $GITHUB_OUTPUT