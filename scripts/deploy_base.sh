#!/usr/bin/env bash
set -e
set -x

DOMAIN_NAME=$1
IMAGE_TAG=$2

OWNER="barhoum1919"
REPO="devops-pr-preview"
IMAGE="ghcr.io/${OWNER}/${REPO}/web:${IMAGE_TAG}"
HOST_PORT=3000

# Check GHCR_PAT
if [ -z "$GHCR_PAT" ]; then
  echo "Error: GHCR_PAT environment variable is not set"
  exit 1
fi

# Login to GHCR
echo $GHCR_PAT | docker login ghcr.io -u $OWNER --password-stdin

# Pull image
docker pull "$IMAGE"

# Recreate base container
docker stop base || true
docker rm base || true
docker run -d --name base -p ${HOST_PORT}:80 "$IMAGE"

# Start ngrok tunnel
NGROK_URL=$(ngrok http $HOST_PORT --log=stdout --log-format=logfmt --region=eu --bind-tls=true | grep -o 'https://[0-9a-z]*\.ngrok-free\.app' | head -1)

echo "✅ Base deployed at: ${NGROK_URL}"
echo "preview-url=${NGROK_URL}" >> $GITHUB_OUTPUT
