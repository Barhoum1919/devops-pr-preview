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

# Create Nginx site file for base if missing
SITENAME="/etc/nginx/sites-available/base.conf"
if [ ! -f "$SITENAME" ]; then
  sudo tee "$SITENAME" > /dev/null <<EOF
server {
    listen 80;
    listen 443 ssl;
    server_name ${DOMAIN_NAME};

    ssl_certificate /etc/ssl/barhoum1919/fullchain.pem;
    ssl_certificate_key /etc/ssl/barhoum1919/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:${HOST_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
  sudo ln -sf "$SITENAME" /etc/nginx/sites-enabled/base.conf
fi

if pgrep nginx > /dev/null; then
    sudo nginx -s reload
else
    sudo nginx
fi

echo "✅ Base deployed to https://${DOMAIN_NAME}"
