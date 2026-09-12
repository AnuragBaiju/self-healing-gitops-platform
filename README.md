# Self-Healing GitOps Platform

![CI](https://github.com/AnuragBaiju/self-healing-gitops-platform/actions/workflows/ci-app.yaml/badge.svg)

A production-pattern Kubernetes platform that automates deployments end to end: push code to Git, and the system builds, scans, gradually rolls it out, watches real metrics, and automatically rolls back if anything breaks, with zero manual intervention.

## Repositories

This project is split into two repositories, matching how real platform teams separate application code from deployment configuration.

- [self-healing-gitops-platform](https://github.com/AnuragBaiju/self-healing-gitops-platform) (this repo): application code, Dockerfile, Terraform, CI workflows, docs, and the setup/teardown scripts
- [self-healing-gitops-config](https://github.com/AnuragBaiju/self-healing-gitops-config): all Kubernetes manifests, continuously watched and synced by ArgoCD

## What this proves

- Progressive delivery: new versions receive a small slice of traffic first (20 percent, then 50 percent, then 100 percent), gated by live health checks at each step
- Automated rollback: a broken deployment is detected and reverted automatically, based on real request success-rate data, not guesswork
- GitOps: the cluster continuously reconciles itself to match the config repository; no manual kubectl apply in normal operation
- Infrastructure as code: the cluster itself is provisioned and torn down via Terraform
- Secrets management: sensitive values are fetched from an external store at runtime, never committed to Git
- Chaos engineering: automated fault injection (pod deletion) with verified, passing recovery
- CI: automated image build, container vulnerability scanning, and infrastructure security scanning on every relevant change
- Reproducibility: the entire platform can be destroyed and rebuilt from a single script, and this has been tested repeatedly

## Architecture

A push to the app repo triggers CI: build the image, scan it with Trivy. A push to the config repo is picked up automatically by ArgoCD, which syncs the cluster. Argo Rollouts then runs a staged canary rollout, checking live Prometheus metrics at each step via an AnalysisTemplate, which decides whether to continue the rollout or trigger an automatic rollback.

See docs/architecture.md for the full breakdown of every component.

## Stack

| Layer | Tool |
|---|---|
| App | Python (Flask) |
| Containerization | Docker, multi-stage, non-root |
| Orchestration | Kubernetes (kind) |
| Progressive delivery | Argo Rollouts |
| Observability | Prometheus and Grafana |
| GitOps | ArgoCD |
| Infrastructure as code | Terraform |
| Secrets | External Secrets Operator |
| Chaos engineering | LitmusChaos |

---

## Setup: running it locally

### Prerequisites

- macOS with Docker Desktop installed and running
- Homebrew installed

### One-command setup

git clone https://github.com/AnuragBaiju/self-healing-gitops-platform.git
cd self-healing-gitops-platform
./scripts/setup.sh

This single script installs any missing prerequisites, clones the config repo alongside this one, provisions a local Kubernetes cluster via Terraform, builds and loads the app's Docker image, installs Argo Rollouts, Prometheus, Grafana, External Secrets Operator, and LitmusChaos, installs ArgoCD and points it at the config repo, and saves working Grafana and ArgoCD credentials to credentials.txt in the project root.

Takes a few minutes. If kubectl get pods shows nothing a minute after it finishes, ArgoCD's first sync sometimes needs a manual nudge:

kubectl port-forward svc/argocd-server -n argocd 8080:443 &
argocd login localhost:8080 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) --insecure
argocd app sync demo-service

### Getting the dashboard credentials

After setup finishes:

cat credentials.txt

If that file is missing or you need to fetch them again manually:

kubectl get secret -n observability monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

Both use username admin.

### Opening the dashboards

./scripts/open-dashboards.sh

This opens Grafana, Prometheus, and ArgoCD with no manual port-forwarding needed, and clears stale leftover tunnels from previous sessions automatically.

Grafana runs at http://localhost:3000, no special notes.
Prometheus runs at http://localhost:9090, no login required.
ArgoCD runs at https://localhost:8080, and the browser will warn about a self-signed certificate, which is expected, proceed anyway.

Press Ctrl+C in that terminal to stop all port-forwards.

### Tearing it down

./scripts/teardown.sh

Destroys the cluster via Terraform, cleans up local state, and verifies nothing is left behind. Run setup.sh again any time to rebuild from scratch.

---

## Verifying it's working

kubectl get pods
kubectl argo rollouts get rollout demo-service
argocd app get demo-service
kubectl get pods -A | grep -E "argocd|argo-rollouts|observability|external-secrets|litmus|demo-service"
kubectl get chaosresult demo-service-chaos-pod-delete -n default -o jsonpath="{.status.experimentStatus.verdict}"; echo
cd terraform && terraform plan

Expect the Rollout to show Healthy at 100 percent, the chaos verdict to show Pass, and terraform plan to show no changes.

---

## Key mechanism: automated rollback

k8s/analysis-template.yaml in the config repo defines a Prometheus query measuring live request success rate: the ratio of 2xx responses to all responses over a one minute window. k8s/rollout.yaml runs this check at each traffic-weight step during a deployment. If success rate drops below 90 percent for more than one measurement, Argo Rollouts automatically aborts and restores 100 percent traffic to the last known-good revision. This was proven live by deploying a version with an injected failure rate via the app's FAILURE_RATE environment variable, and watching it get caught and reverted automatically within seconds.

---

## Repository layout

apps/demo-service holds the app code and Dockerfile.
terraform holds cluster provisioning.
scripts holds setup.sh, open-dashboards.sh, and teardown.sh.
.github/workflows holds ci-app.yaml and ci-iac.yaml.
docs/architecture.md holds the full component breakdown.

Kubernetes manifests live in the separate config repo, under k8s.

---

## Notes on rebuilding from scratch

This platform's full destroy-and-rebuild cycle has been tested repeatedly, and several real bugs were found and fixed in the process, including a wrong repo URL, missing CRD installs, chart version mismatches, stale image tags, and oversized CRD annotations. Every fix lives in the actual scripts and manifests in these repos, not as a one-off workaround.

One known cosmetic quirk: the ExternalSecret resource sometimes shows OutOfSync in ArgoCD even though it reports Healthy. This is expected, harmless drift from a generated field and does not indicate a real problem.
