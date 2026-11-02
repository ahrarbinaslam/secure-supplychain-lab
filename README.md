# Secure software supply chain lab on Kali Linux

This repository is a lab starter for an 8-phase evidence-based DevSecOps project.
It deliberately does not contain any real secrets or built image digests.

## Steps and commands

Run these from the repository root. You need already-working Docker, kubectl, kind,
Helm, Trivy, Syft, Gitleaks, Hadolint, Semgrep, Checkov, Kyverno CLI, Cosign,
SOPS, age, GitHub CLI, and Terraform.

### 1. Configure project

```bash
export GH_USER="$(gh api user --jq .login)"
export REPO='secure-supplychain-lab'
bash scripts/configure.sh "$GH_USER" "$REPO"
git init -b main
git add -A
pre-commit install
pre-commit run --all-files
```

### 2. Local app and secure build

```bash
docker build -t app:local .
docker run -d --name secure-demo -p 127.0.0.1:8080:8080 app:local
curl -fsS http://127.0.0.1:8080/healthz
docker rm -f secure-demo
hadolint Dockerfile
semgrep scan --config p/python --error app/
trivy image --severity HIGH,CRITICAL --ignore-unfixed app:local
syft app:local -o cyclonedx-json > /tmp/local-sbom.cdx.json
```

### 3. GitHub public repo and CI

```bash
git add -A
git commit -m 'feat: secure app and supply-chain pipeline'
gh repo create "$GH_USER/$REPO" --public --source=. --remote=origin --push
gh run list --limit 5
```

Fix CI findings before proceeding; enable branch protection after first green run.
Make your GHCR package **Public** once created (GitHub package settings), so the
cluster and Kyverno can pull signatures without GHCR credentials.

### 4. Validate image digest after CI has signed it

```bash
export IMAGE="ghcr.io/${GH_USER,,}/${REPO}/app"
# Find actual digest in Actions job summary; use a real digest, not a tag:
export DIGEST='sha256:REPLACE_WITH_REAL_DIGEST'
cosign verify "$IMAGE@$DIGEST" \
  --certificate-identity "https://github.com/$GH_USER/$REPO/.github/workflows/pipeline.yml@refs/heads/main" \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com'
gh attestation verify "oci://$IMAGE@$DIGEST" --repo "$GH_USER/$REPO"
sed -i "s|sha256:REPLACE_WITH_DIGEST|$DIGEST|" k8s/10-app.yaml
git add k8s/10-app.yaml && git commit -m 'deploy: pin verified image digest' && git push
```

### 5. Terraform design, no infrastructure provisioning

```bash
# First validate the minimal provider configuration:
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
checkov -d terraform --framework terraform
# Later, opt in to the unprovisioned AKS sketch:
cp terraform/aks-design.tf.example terraform/aks-design.tf
terraform -chdir=terraform fmt
terraform -chdir=terraform validate
checkov -d terraform --framework terraform
# Correct Checkov findings before committing the AKS sketch.
```

**Do not run `terraform apply`.** The HCL is a design sketch, not a fully
reviewed production AKS configuration; validation is only syntactic.

### 6. kind and Calico

```bash
kind create cluster --name supplychain --config kind-config.yaml
kubectl get nodes
# Calico v3.33.0 is an example release. Consult its current compatibility docs.
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml
kubectl -n kube-system rollout status daemonset/calico-node --timeout=300s
kubectl get nodes
```

### 7. Argo CD and Kyverno

```bash
kubectl apply -f k8s/00-namespace.yaml
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm upgrade --install kyverno kyverno/kyverno --namespace kyverno --create-namespace --wait
kubectl get crd | grep policies.kyverno.io
kyverno test policies/tests/
kubectl apply -f policies/
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace --wait
kubectl apply -f argocd-app.yaml
kubectl -n argocd get applications
kubectl -n secure-app rollout status deploy/secure-app --timeout=300s
kubectl -n secure-app get pods
kubectl -n secure-app port-forward svc/secure-app 8080:80
# In another terminal: curl -fsS http://127.0.0.1:8080/healthz
```

**Policy order:** `01-signature.yaml` starts in Audit mode. Examine
`kubectl get policyreport -n secure-app`, and only after the signed app starts,
switch `validationActions: [Audit]` to `[Deny]` and re-apply the file.

### 8. NetworkPolicy test

```bash
kubectl create ns network-client
kubectl -n network-client run allowed --image=curlimages/curl:8.16.0 --restart=Never --command -- sleep 3600
kubectl -n network-client label pod allowed role=client
kubectl -n network-client wait --for=condition=Ready pod/allowed --timeout=120s
kubectl -n network-client exec allowed -- curl -m 5 http://secure-app.secure-app.svc.cluster.local/healthz
kubectl -n network-client run blocked --image=curlimages/curl:8.16.0 --restart=Never --command -- sleep 3600
kubectl -n network-client wait --for=condition=Ready pod/blocked --timeout=120s
kubectl -n network-client exec blocked -- curl -m 5 http://secure-app.secure-app.svc.cluster.local/healthz
# The blocked pod should time out; it has no role=client label.
```

Port-forward cannot prove NetworkPolicy enforcement; run tests from cluster Pods.

### 9. SOPS secrets (out of GitOps scope, encrypted at rest in Git)

```bash
mkdir -p ~/.config/sops/age secrets
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
# Copy the printed public age1... key into .sops.yaml, NOT the private key.
cat > .sops.yaml <<'EOF'
creation_rules:
  - path_regex: secrets/.*\.yaml$
    encrypted_regex: '^(data|stringData)$'
    age: age1REPLACE_WITH_YOUR_AGE_PUBLIC_KEY
EOF
cat > secrets/app-secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: secure-app
stringData:
  API_KEY: demo-only-value
EOF
sops --encrypt --in-place secrets/app-secret.yaml
sops -d secrets/app-secret.yaml | kubectl apply -f -
git add .sops.yaml secrets/app-secret.yaml
# Verify only ciphertext is staged before committing.
```

### 10. Falco runtime detection and audit evidence

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm upgrade --install falco falcosecurity/falco -n falco --create-namespace -f falco-values.yaml --wait
kubectl -n falco get pods
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=100
kubectl -n falco port-forward --address 127.0.0.1 svc/falco-falcosidekick-ui 2802:2802
```

Change the Falcosidekick UI default password and keep port-forward local only.
For Falco tests, create a throwaway Pod outside the restricted app namespace,
then `kubectl exec` into it to generate a shell event. Some VMs lack the
kernel eBPF capabilities needed by Falco; record any driver failure honestly.

### 11. Cluster scanning and evidence

```bash
kubescape scan framework nsa
kubescape scan framework mitre
kubectl -n secure-app get pods -o wide
kubectl -n secure-app get networkpolicy
kubectl get policyreport -A
kubectl get imagevalidatingpolicies,namespacedimagevalidatingpolicies -A
```

Log attack outcomes as prevented/detected/missed. Do not test attacks against
third-party systems. Never commit an age private key or actual token.

### 12. Safe cleanup

```bash
kind delete cluster --name supplychain
# Inspect before pruning Docker artifacts; avoid deleting unrelated work.
docker system df
```

## Limitations

- AKS is not provisioned; Terraform is a design-only example.
- GitHub Actions tags should be pinned by commit SHA for higher assurance.
- The image scan checks one local image; publication occurs without rebuilding.
- The simple SOPS secret deploy requires an out-of-band decrypt/apply step.
- There is no SIEM, centralized log retention, or production-grade multi-tenancy.
- Falco and network policies require tests on the target Kali VM.
