#!/usr/bin/env bash
set -e

PR_NUMBER=$1
OWNER="barhoum1919"
REPO="devops-pr-preview"
IMAGE="ghcr.io/${OWNER}/${REPO}/web:pr-${PR_NUMBER}"
HOST_PORT=$((3000 + PR_NUMBER))
CONTAINER_NAME="pr-${PR_NUMBER}"

if [ -z "$GHCR_PAT" ]; then
    echo "Error: GHCR_PAT environment variable is not set"
    exit 1
fi

echo "Logging into GHCR..."
echo $GHCR_PAT | docker login ghcr.io -u $OWNER --password-stdin

# Pull the SHA-tagged image built in CI
SHA_IMAGE="$IMAGE_NAME:sha-${GITHUB_SHA}"
docker pull $SHA_IMAGE

# Tag the image as pr-<number>
docker tag $SHA_IMAGE $IMAGE_NAME:$IMAGE_TAG

# Push the pr-<number> tag to GHCR
docker push $IMAGE_NAME:$IMAGE_TAG
echo "✅ Image pushed: $IMAGE_NAME:$IMAGE_TAG"


echo "Stopping old container $CONTAINER_NAME..."
docker stop $CONTAINER_NAME || true
docker rm $CONTAINER_NAME || true

echo "Running PR container on port $HOST_PORT..."
docker run -d --name $CONTAINER_NAME -p ${HOST_PORT}:80 $IMAGE_NAME:$IMAGE_TAG

echo "Waiting for container to become healthy..."
for i in {1..10}; do
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_NAME || echo "unknown")
    if [[ "$HEALTH" == "healthy" ]]; then
        echo "Container is healthy!"
        break
    fi
    echo "Waiting..."
    sleep 3
done

pkill -f "ngrok http $HOST_PORT" || true

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
curl -v $NGROK_URL/health
PREVIEW_URL=${NGROK_URL:-"http://127.0.0.1:$HOST_PORT"}
echo " PR #$PR_NUMBER preview available via: $PREVIEW_URL"

# Output for GitHub Actions
echo "preview-url=$PREVIEW_URL" >> $GITHUB_OUTPUT
echo " PR #$PR_NUMBER deployment complete!"
