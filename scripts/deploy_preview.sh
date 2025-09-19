#!/usr/bin/env bash
set -e
set -x

PR_NUMBER=$1
OWNER="barhoum1919"
REPO="devops-pr-preview"
IMAGE="ghcr.io/${OWNER}/${REPO}/web:pr-${PR_NUMBER}"
HOST_PORT=$((3000 + PR_NUMBER))

# Check GHCR_PAT
if [ -z "$GHCR_PAT" ]; then
  echo "Error: GHCR_PAT environment variable is not set"
  exit 1
fi

# Login to GHCR
echo $GHCR_PAT | docker login ghcr.io -u $OWNER --password-stdin

# Pull image
docker pull "$IMAGE"

# Recreate PR container
docker stop pr-$PR_NUMBER || true
docker rm pr-$PR_NUMBER || true
docker run -d --name pr-$PR_NUMBER -p ${HOST_PORT}:80 "$IMAGE"

# Start ngrok tunnel for this PR
NGROK_URL=$(ngrok http $HOST_PORT --log=stdout --log-format=logfmt --region=eu --bind-tls=true | grep -o 'https://[0-9a-z]*\.ngrok-free\.app' | head -1)

echo "✅ PR #${PR_NUMBER} deployed at: ${NGROK_URL}"
echo "preview-url=${NGROK_URL}" >> $GITHUB_OUTPUT

