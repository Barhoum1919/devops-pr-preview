#!/usr/bin/env bash
set -e
set -x

PR_NUMBER=$1
DOMAIN_NAME=$2

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

# Create Nginx site file for PR if missing
SITENAME="/etc/nginx/sites-available/pr-$PR_NUMBER.conf"
if [ ! -f "$SITENAME" ]; then
  sudo tee "$SITENAME" > /dev/null <<EOF
server {
    listen 80;
    listen 443 ssl;
    server_name pr-${PR_NUMBER}.${DOMAIN_NAME};

    ssl_certificate /etc/ssl/barhoum1919/fullchain.pem;
    ssl_certificate_key /etc/ssl/barhoum1919/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:${HOST_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
  sudo ln -sf "$SITENAME" /etc/nginx/sites-enabled/pr-$PR_NUMBER.conf
fi

# Reload Nginx
sudo nginx -s reload

echo "✅ PR #${PR_NUMBER} preview deployed to https://pr-${PR_NUMBER}.${DOMAIN_NAME}"
