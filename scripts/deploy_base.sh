#!/usr/bin/env bash
set -e
set -x  

DOMAIN_NAME=$1
IMAGE_TAG=$2

OWNER="barhoum1919"       
REPO="devops-pr-preview"  
IMAGE="ghcr.io/${OWNER}/${REPO}/web:${IMAGE_TAG}"
HOST_PORT=3000

# Login to GHCR non-interactively
if [ -z "$GHCR_PAT" ]; then
  echo "Error: GHCR_PAT environment variable is not set"
  exit 1
fi
echo $GHCR_PAT | docker login ghcr.io -u $OWNER --password-stdin

echo "Pulling image $IMAGE"
docker pull "$IMAGE"

# Recreate base container
docker stop base || true
docker rm base || true
docker run -d --name base -p ${HOST_PORT}:80 "$IMAGE"

echo "Waiting for container to start..."
until curl -s http://127.0.0.1:$HOST_PORT > /dev/null; do
    sleep 2
done
until curl -s http://127.0.0.1:$HOST_PORT > /dev/null; do sleep 2; done

NGROK_LOG=$(mktemp)
pkill -f "ngrok http $HOST_PORT" || true
nohup ngrok http $HOST_PORT --region=eu --log=stdout > ngrok.log 2>&1 &
NGROK_PID=$!

# Give ngrok a few seconds to start
sleep 5

# Get the public URL via ngrok's local API
NGROK_URL=$(curl --silent http://127.0.0.1:4040/api/tunnels \
  | jq -r '.tunnels[0].public_url')

if [ -n "$NGROK_URL" ]; then
  echo "🌐 Base preview available via ngrok: $NGROK_URL"
  PREVIEW_URL="$NGROK_URL"
else
  echo "⚠️ ngrok did not return a URL. The app is only available locally at http://localhost:${HOST_PORT}"
  PREVIEW_URL="http://localhost:${HOST_PORT}"
fi

echo "✅ Base deployed at: $PREVIEW_URL"
echo "preview-url=$PREVIEW_URL" >> $GITHUB_OUTPUT
