#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_URL="${IMAGE_URL:-https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2}"
IMAGE_PATH="${IMAGE_PATH:-${ROOT_DIR}/images/debian-cloud.qcow2}"

mkdir -p "$(dirname "$IMAGE_PATH")"

if [[ -f "$IMAGE_PATH" ]]; then
    echo "image already exists: $IMAGE_PATH"
    exit 0
fi

tmp="${IMAGE_PATH}.tmp"
curl -L "$IMAGE_URL" -o "$tmp"
mv "$tmp" "$IMAGE_PATH"

