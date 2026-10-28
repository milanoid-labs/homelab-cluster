#!/usr/bin/env bash
# Derive the upstream base image (name:tag + digest) from a Dockerfile's FROM line.
# The FROM line is the single source of truth (Renovate bumps it); this emits
# key=value lines for GITHUB_OUTPUT so build-runner-image.yml can label the image
# with org.opencontainers.image.base.* -- labels then can never drift from reality.
set -euo pipefail

dockerfile="${1:?usage: runner-base-image.sh <dockerfile>}"

# First FROM line only (ignore multi-stage build targets if added later).
from_ref=$(sed -nE 's/^FROM[[:space:]]+([^[:space:]]+)([[:space:]].*)?$/\1/p' "$dockerfile" | head -n1)

if [[ "$from_ref" != *"@sha256:"* ]]; then
  echo "ERROR: FROM line is not digest-pinned: '${from_ref}'" >&2
  exit 1
fi

echo "base_name=${from_ref%@sha256:*}"
echo "base_digest=sha256:${from_ref##*@sha256:}"
