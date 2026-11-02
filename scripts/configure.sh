#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 2 ]; then echo "Usage: $0 GITHUB_OWNER REPO" >&2; exit 2; fi
owner="${1,,}"
repo="${2,,}"
[[ "$owner" =~ ^[a-z0-9-]+$ ]] || { echo "Invalid owner" >&2; exit 1; }
[[ "$repo" =~ ^[a-z0-9_.-]+$ ]] || { echo "Invalid repository name" >&2; exit 1; }
for file in k8s/10-app.yaml policies/01-signature.yaml policies/02-allowed-images.yaml argocd-app.yaml; do
  sed -i "s|__OWNER__|$owner|g; s|__REPO__|$repo|g" "$file"
done
printf 'Configured ghcr.io/%s/%s/app
' "$owner" "$repo"
