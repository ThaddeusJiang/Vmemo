#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-}"
DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN:-}"
DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-thaddeusjiang}"
TAGS=("$@")

if [ -z "$IMAGE_NAME" ]; then
  echo "IMAGE_NAME is required"
  exit 1
fi

if [ "${#TAGS[@]}" -eq 0 ]; then
  echo "At least one tag must be provided"
  exit 1
fi

if [ -z "$DOCKERHUB_TOKEN" ]; then
  echo "DOCKERHUB_TOKEN is required"
  exit 1
fi

# Give Docker Hub a short propagation window before deleting temporary tags.
sleep 20

namespace="${IMAGE_NAME%/*}"
repository="${IMAGE_NAME#*/}"

jwt="$({
  curl -fsSL \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${DOCKERHUB_USERNAME}\",\"password\":\"${DOCKERHUB_TOKEN}\"}" \
    https://hub.docker.com/v2/users/login/
} | jq -r '.token')"

if [ -z "$jwt" ] || [ "$jwt" = "null" ]; then
  echo "Failed to obtain Docker Hub JWT token"
  exit 1
fi

delete_tag() {
  local tag="$1"
  local url="https://hub.docker.com/v2/namespaces/${namespace}/repositories/${repository}/tags/${tag}/"
  local body_file
  local code

  body_file="$(mktemp)"
  code="$({
    curl -sS -o "${body_file}" -w "%{http_code}" \
      -X DELETE \
      -H "Authorization: JWT ${jwt}" \
      "${url}"
  })"

  if [ "$code" = "204" ] || [ "$code" = "404" ]; then
    echo "Deleted tag ${tag} (HTTP ${code})"
    rm -f "${body_file}"
    return 0
  fi

  echo "Failed to delete tag ${tag} (HTTP ${code})"
  cat "${body_file}"
  rm -f "${body_file}"
  return 1
}

for tag in "${TAGS[@]}"; do
  delete_tag "${tag}"
done
