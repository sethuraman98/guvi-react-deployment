#!/bin/bash
set -euo pipefail

DOCKERHUB_USER="${DOCKERHUB_USER:-sethuaws}"
BRANCH="${BRANCH_NAME:-$(git branch --show-current)}"

case "$BRANCH" in
  dev)
    IMAGE_REPO="${DOCKERHUB_USER}/guvi-react-app-dev"
    CONTAINER_NAME="guvi-react-dev"
    HOST_PORT=8081
    ;;
  master)
    IMAGE_REPO="${DOCKERHUB_USER}/guvi-react-app-prod"
    CONTAINER_NAME="guvi-react-prod"
    HOST_PORT=80
    ;;
  *)
    echo "ERROR: Unsupported branch: $BRANCH"
    exit 1
    ;;
esac

IMAGE="${IMAGE_REPO}:latest"

echo "Deploying ${IMAGE} on port ${HOST_PORT}"

docker pull "$IMAGE"

docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "${HOST_PORT}:80" \
  "$IMAGE"

sleep 5

if ! curl -fsS "http://localhost:${HOST_PORT}/" >/dev/null; then
  echo "ERROR: Application health check failed"
  docker logs "$CONTAINER_NAME"
  exit 1
fi

echo "Deployment successful: http://localhost:${HOST_PORT}"
