# Threat model

Trust boundaries: developer Kali host, GitHub repo/Actions, GHCR registry,
Kubernetes control plane/admission, workload namespace, and remote clients.

| Threat | Control | Evidence |
| --- | --- | --- |
| Secret in code | Gitleaks/pre-commit and GH push protection | CI failure screenshot |
| Vulnerable dependency | Trivy HIGH/CRITICAL gate | CI failure screenshot |
| Malicious or swapped container image | Digest pin + Cosign identity + Kyverno | Admission denial |
| Excessive privileges | PSA restricted + no automount + seccomp | Admission denial |
| Lateral network movement | Calico default-deny + explicit allow | Blocked and allowed curl |
| Shell/tool execution at runtime | Falco | UI event screenshot |
