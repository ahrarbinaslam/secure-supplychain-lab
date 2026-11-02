# Test results (fill in with evidence from your own lab)

| Test | Expected | Actual outcome | Evidence |
| --- | --- | --- | --- |
| Hardcoded demo token | Blocked by Gitleaks | Pending | |
| Known-vulnerable dependency | Blocked by Trivy | Pending | |
| Unsigned GHCR digest in approved package | Blocked by Kyverno | Pending | |
| Wrong signer certificate | Blocked by Kyverno | Pending | |
| Privileged root Pod | Blocked by Pod Security | Pending | |
| Non-pinned or other-registry image | Blocked by Kyverno allowlist | Pending | |
| Unauthorized traffic | Blocked by Calico NetworkPolicy | Pending | |
| Runtime shell | Detected by Falco | Pending | |
