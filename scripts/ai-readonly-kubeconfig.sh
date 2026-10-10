#!/usr/bin/env bash
set -euo pipefail

# Mint a short-lived kubeconfig for the ai-readonly ServiceAccount (TokenRequest API).
# Run with admin credentials; hand only the output to the agent. The token expires
# on its own; to revoke all outstanding tokens early, delete and recreate the SA.
# Usage:
#   ./scripts/ai-readonly-kubeconfig.sh [duration] > ai-readonly.kubeconfig
#   duration defaults to 8h (e.g. 1h, 24h). Override the API server with
#   AI_READONLY_SERVER=https://<host>:6443 if the agent reaches it via another address.

DURATION="${1:-8h}"
NAMESPACE="ai-readonly"
SERVICE_ACCOUNT="ai-readonly"

if ! command -v kubectl &>/dev/null; then
  echo "ERROR: 'kubectl' CLI is not installed." >&2
  exit 1
fi

if ! kubectl get serviceaccount "${SERVICE_ACCOUNT}" -n "${NAMESPACE}" &>/dev/null; then
  echo "ERROR: ServiceAccount ${NAMESPACE}/${SERVICE_ACCOUNT} not found (or no access)." >&2
  exit 1
fi

SERVER="${AI_READONLY_SERVER:-$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')}"
CA_DATA="$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"
TOKEN="$(kubectl create token "${SERVICE_ACCOUNT}" -n "${NAMESPACE}" --duration="${DURATION}")"

cat <<KUBECONFIG
apiVersion: v1
kind: Config
clusters:
  - name: homelab
    cluster:
      server: ${SERVER}
      certificate-authority-data: ${CA_DATA}
users:
  - name: ${SERVICE_ACCOUNT}
    user:
      token: ${TOKEN}
contexts:
  - name: ${SERVICE_ACCOUNT}
    context:
      cluster: homelab
      user: ${SERVICE_ACCOUNT}
current-context: ${SERVICE_ACCOUNT}
KUBECONFIG

echo "Token for ${NAMESPACE}/${SERVICE_ACCOUNT} valid for ${DURATION}." >&2
