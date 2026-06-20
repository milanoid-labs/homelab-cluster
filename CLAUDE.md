# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

K3s Kubernetes homelab cluster managed via **GitOps with Flux CD**. All changes are driven by Git commits — Flux watches this repo and reconciles automatically. There are no build, test, or lint commands; this is purely declarative YAML.

## Architecture

### Base + Overlay Pattern (Kustomize)

- **`apps/base/<app>/`** — Base manifests: deployment, service, storage (PVC), namespace, kustomization
- **`apps/staging/<app>/`** — Overlays: ingress, SOPS-encrypted secrets, Cloudflare tunnel configs
- **`apps/staging/kustomization.yaml`** — Registry of all deployed apps (add/remove apps here)

### Flux Reconciliation (in `clusters/staging/`)

| Flux Kustomization | Path | Purpose |
|---|---|---|
| `apps.yaml` | `./apps/staging` | All user applications |
| `infrastructure.yaml` | `./infrastructure/controllers/staging` | Controllers (Renovate) |
| `monitoring.yaml` | `./monitoring/` | kube-prometheus-stack (HelmRelease) |
| `persistent-volumes.yaml` | `./persistent-volumes/staging` | NFS PV definitions |
| `workflows.yaml` | `./workflows/staging` | Argo Workflows/CronWorkflows |

All have `interval: 1m0s` and `prune: true`. Most also have SOPS decryption enabled, except `monitoring.yaml`'s `monitoring-controllers` Kustomization (no secrets needed there).

### Secrets Management

SOPS with age encryption. Config in `.sops.yaml` — only `data` and `stringData` fields are encrypted. Edit with: `sops apps/staging/<app>/<app>-secrets.yaml`

### Two Access Patterns

- **Traefik Ingress** — LAN/VPN access via `*.milanoid.net` subdomains (`ingressClassName: traefik`)
- **Cloudflare Tunnels** — Public internet access via cloudflared sidecar deployments (2 replicas for HA), routing defined in ConfigMap

Some apps use both with different hostnames (e.g., Linkding: `linkding.milanoid.net` internal, `lkd.milanoid.net` public).

### Storage

- **Shared NFS** (Synology NAS): Single PV `synology-nfs-pv` → single PVC `synology-nfs-pvc` in `downloaders` namespace. `ReadWriteMany`. Used by media apps (sonarr, radarr, bazarr, prowlarr, torrent-client). Due to 1:1 PV-to-PVC binding, all apps sharing NFS must use the same PVC/namespace.
- **Local PVCs**: Per-app `ReadWriteOnce` config volumes via K3s local-path provisioner.

## Common Tasks

### Adding a new application

1. Create `apps/base/<app>/` with deployment.yaml, service.yaml, storage.yaml, namespace.yaml, kustomization.yaml
2. Create `apps/staging/<app>/` with kustomization.yaml (referencing `../../base/<app>`), ingress.yaml, optional secrets and cloudflare.yaml
3. Register in `apps/staging/kustomization.yaml`

### Updating an application image

Edit image tag in `apps/base/<app>/deployment.yaml`. Renovate also creates PRs for updates automatically.

### Checking Flux status

```bash
flux get kustomizations
flux logs
```

## Key Conventions

- All container images pinned to specific versions (Renovate manages updates)
- Containers run as non-root: `securityContext.allowPrivilegeEscalation: false`, specify `runAsUser`
- Helm charts deployed via Flux HelmRelease with explicit versions, CRD management, and drift detection enabled
- Cloudflare tunnel deployments include `/ready` liveness probe on port 2000 and a catch-all `http_status:404` rule

## Hardware

2-node K3s cluster on HP EliteDesk 705 G2 Minis (AMD A8-8600B, 8GB RAM, 128GB SSD each), Ubuntu 24 LTS. This is a learning homelab.
