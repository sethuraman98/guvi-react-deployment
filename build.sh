#!/bin/bash
set -euo pipefail

DOCKERHUB_USER="${DOCKERHUB_USER:-sethuaws}"
BRANCH="${BRANCH_NAME:-$(git branch --show-current)}"
COMMIT_ID="$(git rev-parse --short HEAD)"

case "$BRANCH" in
  dev)
    IMAGE_REPO="${DOCKERHUB_USER}/guvi-react-app-dev"
    ;;
  master)
    IMAGE_REPO="${DOCKERHUB_USER}/guvi-react-app-prod"
    ;;
  *)
    echo "ERROR: Unsupported branch: $BRANCH"
    exit 1
    ;;
esac

echo "Building image: ${IMAGE_REPO}"

docker build \
  -t "${IMAGE_REPO}:latest" \
  -t "${IMAGE_REPO}:${COMMIT_ID}" .

echo "Pushing images to Docker Hub..."

docker push "${IMAGE_REPO}:latest"
docker push "${IMAGE_REPO}:${COMMIT_ID}"

echo "Build and push completed successfully!"
