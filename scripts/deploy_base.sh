#!/usr/bin/env bash
set -e
OWNER="<github-owner>"
REPO="Barhoum1919/devops-pr-preview"   
IMAGE="ghcr.io/${OWNER}/${REPO}/web:latest"
HOST_PORT=3000

echo "Pull $IMAGE"
docker pull "$IMAGE"

# recreate base container
docker stop base || true
docker rm base || true
docker run -d --name base -p ${HOST_PORT}:80 $IMAGE

# create nginx site file for base if missing
SITENAME="/etc/nginx/sites-available/base.conf"
if [ ! -f "$SITENAME" ]; then
  sudo tee "$SITENAME" > /dev/null <<EOF
server {
  listen 80;
  listen 443 ssl;
  server_name yourname.duckdns.org;

  # ssl cert paths (adjust)
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
  sudo nginx -s reload
else
  sudo nginx -s reload
fi

echo "Base deployed to https://barhoum1919.duckdns.org"
