#!/usr/bin/env bash
set -e
set -x

PR_NUMBER=$1
DOMAIN_NAME=$2  # optional, we won't use it for Ngrok

OWNER="barhoum1919"
REPO="devops-pr-preview"
IMAGE="ghcr.io/${OWNER}/${REPO}/web:pr-${PR_NUMBER}"
HOST_PORT=$((3000 + PR_NUMBER))  # unique port per PR

# Login to GHCR non-interactively
if [ -z "$GHCR_PAT" ]; then
  echo "Error: GHCR_PAT environment variable is not set"
  exit 1
fi
echo $GHCR_PAT | docker login ghcr.io -u $OWNER --password-stdin

echo "Pulling image $IMAGE"
docker pull "$IMAGE"

# Recreate PR preview container
docker stop pr-$PR_NUMBER || true
docker rm pr-$PR_NUMBER || true
docker run -d --name pr-$PR_NUMBER -p ${HOST_PORT}:80 "$IMAGE"

# Start Ngrok tunnel in background
NGROK_LOG="/tmp/ngrok_pr_${PR_NUMBER}.log"
nohup ngrok http $HOST_PORT --log=$NGROK_LOG > /dev/null 2>&1 &

# Wait for Ngrok to initialize
sleep 5

# Get public Ngrok URL
NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')

if [ -z "$NGROK_URL" ]; then
  echo "❌ Failed to get Ngrok URL. Check ngrok logs at $NGROK_LOG"
  exit 1
fi

echo "✅ PR #${PR_NUMBER} preview deployed to $NGROK_URL"
echo "preview-url=$NGROK_URL" >> $GITHUB_OUTPUT
