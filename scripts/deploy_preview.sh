#!/usr/bin/env bash
set -e
set -x

# Arguments
PR_NUMBER=$1
DOMAIN_NAME=$2   
OWNER="barhoum1919"
REPO="devops-pr-preview"
IMAGE="ghcr.io/${OWNER}/${REPO}/web:pr-${PR_NUMBER}"
HOST_PORT=$((3000 + PR_NUMBER))  

# Check GHCR token
if [ -z "$GHCR_PAT" ]; then
  echo "Error: GHCR_PAT environment variable is not set"
  exit 1
fi

# Login to GHCR
echo $GHCR_PAT | docker login ghcr.io -u $OWNER --password-stdin

# Pull the Docker image
docker pull "$IMAGE"

# Recreate PR container
docker stop pr-$PR_NUMBER || true
docker rm pr-$PR_NUMBER || true
docker run -d --name pr-$PR_NUMBER -p ${HOST_PORT}:80 "$IMAGE"

# Try to expose via ngrok
NGROK_URL=$(ngrok http $HOST_PORT --log=stdout --region=eu | grep -o 'https://[0-9a-z-]*\.ngrok-free\.app' | head -1 || true)

if [ -n "$NGROK_URL" ]; then
  echo "🌐 PR #${PR_NUMBER} preview available via ngrok: $NGROK_URL"
  PREVIEW_URL="$NGROK_URL"
else
  echo "⚠️ ngrok did not return a URL. The preview is only available locally at http://localhost:${HOST_PORT}"
  PREVIEW_URL="http://localhost:${HOST_PORT}"
fi

echo "✅ PR #${PR_NUMBER} deployed"
echo "preview-url=$PREVIEW_URL" >> $GITHUB_OUTPUT
