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

# Generate Nginx site file for this PR
SITENAME="/etc/nginx/sites-available/pr-${PR_NUMBER}.conf"
sudo tee "$SITENAME" > /dev/null <<EOF
server {
    listen 80;
    server_name pr-${PR_NUMBER}.${DOMAIN_NAME}.duckdns.org;

    location / {
        proxy_pass http://127.0.0.1:${HOST_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /preview-info {
        access_log off;
        return 200 "PR #${PR_NUMBER} Preview Environment\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Enable Nginx site
sudo ln -sf "$SITENAME" /etc/nginx/sites-enabled/pr-${PR_NUMBER}.conf

# Reload Nginx if running, otherwise start it
if pgrep nginx > /dev/null; then
    sudo nginx -s reload
else
    sudo nginx
fi

# Check if port is externally reachable
if nc -zv 127.0.0.1 $HOST_PORT &>/dev/null; then
    echo "✅ PR #${PR_NUMBER} preview running on port ${HOST_PORT}"
else
    echo "⚠️ Port ${HOST_PORT} is not reachable. Starting ngrok tunnel..."
    # ngrok must be installed and authenticated: `ngrok authtoken <token>`
    NGROK_URL=$(ngrok http $HOST_PORT --log=stdout --log-format=logfmt --region=eu --bind-tls=true | grep -o 'https://[0-9a-z]*\.ngrok-free\.app')
    echo "🌐 PR #${PR_NUMBER} preview available via ngrok: ${NGROK_URL}"
fi
echo "✅ PR #${PR_NUMBER} deployed to http://pr-${PR_NUMBER}.${DOMAIN_NAME}.duckdns.org"
if [ -z "$NGROK_URL" ]; then
    PREVIEW_URL="http://pr-${PR_NUMBER}.${DOMAIN_NAME}.duckdns.org"
else
    PREVIEW_URL="$NGROK_URL"
fi

# Export to GitHub Actions
echo "preview-url=$PREVIEW_URL" >> $GITHUB_OUTPUT
echo "✅ PR #${PR_NUMBER} preview URL: $PREVIEW_URL"
