#!/usr/bin/env bash
set -e
PR="$1"
if [ -z "$PR" ]; then
  echo "Usage: $0 <pr-number>"; exit 2
fi

echo "Stopping and removing container pr-$PR"
docker stop pr-$PR || true
docker rm pr-$PR || true
