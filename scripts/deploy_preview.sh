#!/usr/bin/env bash
set -e
PR="$1"
if [ -z "$PR" ]; then
  echo "Usage: $0 <pr-number>"; exit 2
fi
OWNER="<github-owner>"
REPO="<repo>"
IMAGE="ghcr.io/${OWNER}/${REPO}/web:pr-${PR}"

# choose a host port: 30000 + PR (safe for typical PR numbers)
HOST_PORT=$((30000 + PR))

echo "Deploy preview $PR -> port $HOST_PORT (image $IMAGE)"
docker pull "$IMAGE" || { echo "Image not found: $IMAGE"; exit 1; }

docker stop pr-${PR} || true
docker rm pr-${PR} || true
docker run -d --name pr-${PR} -p ${HOST_PORT}:80 $IMAGE

# create nginx site
SITENAME="/etc/nginx/sites-available/pr-${PR}.conf"
sudo tee "$SITENAME" > /dev/null <<EOF
server {
  listen 80;
  listen 443 ssl;
  server_name pr-${PR}.yourname.duckdns.org;

  ssl_certificate /etc/ssl/yourname/fullchain.pem;
  ssl_certificate_key /etc/ssl/yourname/privkey.pem;

  location / {
    proxy_pass http://127.0.0.1:${HOST_PORT};
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
}
EOF

sudo ln -sf "$SITENAME" /etc/nginx/sites-enabled/pr-${PR}.conf
sudo nginx -s reload

echo "Preview deployed: https://pr-${PR}.yourname.duckdns.org"
