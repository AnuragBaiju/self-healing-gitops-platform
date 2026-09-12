

Readme · MD
# Self-Healing GitOps Platform
 
![CI](https://github.com/AnuragBaiju/self-healing-gitops-platform/actions/workflows/ci-app.yaml/badge.svg)
 
**A Kubernetes platform that treats every deployment as a hypothesis to be tested, not an action to be trusted.** Code is shipped gradually, judged against live production metrics at each stage, and automatically reverted the moment it fails to meet a defined health threshold, with no human in the loop.
 
---
 
## Abstract
 
Manual deployment processes rely on human judgment to decide whether a release is safe, typically after the fact, once users are already affected. This project implements an alternative: a closed-loop deployment pipeline where a new release earns increasing traffic only by demonstrating acceptable behavior against real, live metrics, and is automatically withdrawn if it does not. The system was built, deliberately broken, and observed recovering without intervention, then destroyed and rebuilt from a single script to verify the entire pipeline is reproducible rather than a one-time artifact of manual setup.
 
---
 
## System architecture
 
```
                    +---------------------+         +----------------------+
                    |  App repo (Git)     |         |  Config repo (Git)   |
                    |  code, Dockerfile,  |         |  all k8s manifests   |
                    |  Terraform, CI      |         |                      |
                    +----------+----------+         +----------+-----------+
                               | push                            | push
                               v                                 v
                    +---------------------+         +----------------------+
                    |  GitHub Actions     |         |  ArgoCD              |
                    |  build + Trivy scan |         |  watches repo,       |
                    |  + Checkov (IaC)    |         |  auto-syncs cluster  |
                    +---------------------+         +----------+-----------+
                                                                 |
                                                                 v
                              +---------------------------------------------------+
                              |              Kubernetes cluster (kind)             |
                              |                                                     |
                              |   +-----------------+      +-------------------+   |
                              |   |  Argo Rollouts  |----->|  Canary steps:    |   |
                              |   |  controller     |      |  20% -> 50% -> 100%|   |
                              |   +--------+--------+      +-------------------+   |
                              |            | query at each step                    |
                              |            v                                       |
                              |   +-----------------+      +-------------------+   |
                              |   |  Prometheus     |<-----|  demo-service     |   |
                              |   |  scrapes /metrics|      |  (Flask app)     |   |
                              |   +--------+--------+      +-------------------+   |
                              |            |                                       |
                              |            v                                       |
                              |   +-------------------------------------+          |
                              |   |  AnalysisTemplate                   |          |
                              |   |  success_rate = 2xx / total >= 0.90 |          |
                              |   +-----------+-------------+-----------+          |
                              |           pass |             | fail (x2)           |
                              |               v             v                      |
                              |   +---------------+   +----------------------+     |
                              |   | advance rollout|   | automatic rollback  |     |
                              |   | to next step   |   | to last stable image|     |
                              |   +---------------+   +----------------------+     |
                              |                                                     |
                              |   Also running: External Secrets Operator          |
                              |   (runtime secret injection), LitmusChaos          |
                              |   (fault injection, pod-delete verified Pass)      |
                              +---------------------------------------------------+
```
 
---
 
## Method
 
1. **Instrumentation.** The application (`apps/demo-service`) exposes `/healthz` for liveness and `/metrics` in Prometheus exposition format, incrementing a labeled counter (`flask_http_request_total{status}`) on every request. A `FAILURE_RATE` environment variable allows deliberately injecting failures without changing code, used to test the rollback path under controlled conditions.
2. **Packaging.** A multi-stage Dockerfile builds a minimal image and runs the process as a non-root user (uid 10001), separating build-time dependencies from the runtime image.
3. **Orchestration.** Kubernetes manages the base reconciliation loop (desired replica count vs. actual). Argo Rollouts is layered on top, replacing the standard Deployment object with a canary strategy that shifts traffic in stages and pauses for measurement between each.
4. **Measurement.** At each canary stage, an `AnalysisRun` executes a PromQL query against Prometheus:
```
   sum(rate(flask_http_request_total{status=~"2.."}[1m])) / sum(rate(flask_http_request_total[1m]))
```
 
   A result below `0.90`, sustained across more than one measurement, is treated as a failed hypothesis.
 
5. **Decision.** On a passing measurement, Argo Rollouts increases traffic to the next stage. On a failing measurement, it aborts the rollout and restores 100 percent of traffic to the last revision known to be healthy, without any operator action.
6. **Reconciliation.** ArgoCD independently and continuously compares the live cluster state against the config repository, correcting drift in either direction: a manual change to the cluster is reverted to match Git, and a change pushed to Git is applied to the cluster.
7. **Reproducibility test.** The entire platform was destroyed via Terraform and `kind delete cluster`, then rebuilt from `./scripts/setup.sh` alone, repeated across multiple sessions. This surfaced and led to fixes for real defects: an incorrect repository reference, missing CRD installations, an incompatible Helm chart version, a stale image tag, and CRDs exceeding a client-side size limit during `kubectl apply`. Each fix is committed to the scripts and manifests themselves, not applied as a one-off workaround.
---
 
## Results
 
| Test | Outcome |
|---|---|
| Canary rollout of a healthy release | Progressed through all steps to 100 percent, correctly reclassified as stable |
| Canary rollout of a release with `FAILURE_RATE` injected | Detected below-threshold success rate, aborted automatically, reverted to prior stable revision |
| Manual `kubectl` change to a Git-managed resource | Reverted automatically by ArgoCD to match the repository |
| Change committed to config repo, no manual `kubectl apply` | Applied automatically by ArgoCD within one sync cycle |
| LitmusChaos pod-delete experiment against the running Rollout | Verdict: `Pass` -- replacement pods scheduled, service remained available |
| Full platform teardown and rebuild via `./scripts/setup.sh` | Succeeded on repeated attempts after fixing defects surfaced by the first attempts |
 
---
 
## Repositories
 
This project is split into two repositories, separating application concerns from deployment configuration, matching how platform teams typically divide responsibility and review process.
 
- [self-healing-gitops-platform](https://github.com/AnuragBaiju/self-healing-gitops-platform) (this repo): application code, Dockerfile, Terraform, CI workflows, docs, setup scripts
- [self-healing-gitops-config](https://github.com/AnuragBaiju/self-healing-gitops-config): all Kubernetes manifests, continuously reconciled by ArgoCD
## Stack
 
| Layer | Tool |
|---|---|
| Application | Python (Flask) |
| Containerization | Docker, multi-stage, non-root |
| Orchestration | Kubernetes (kind) |
| Progressive delivery | Argo Rollouts |
| Observability | Prometheus, Grafana |
| GitOps | ArgoCD |
| Infrastructure as code | Terraform |
| Secrets management | External Secrets Operator |
| Chaos engineering | LitmusChaos |
| CI | GitHub Actions, Trivy, Checkov |
 
---
 
## Running it
 
### Prerequisites
macOS, Docker Desktop running, Homebrew installed.
 
### Setup
 
```
git clone https://github.com/AnuragBaiju/self-healing-gitops-platform.git
cd self-healing-gitops-platform
./scripts/setup.sh
```
 
Provisions the cluster, builds the app image, installs the full stack, and points ArgoCD at the config repo. Saves working credentials to `credentials.txt`. If `kubectl get pods` is empty a minute after completion:
 
```
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
argocd login localhost:8080 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) --insecure
argocd app sync demo-service
```
 
### Dashboards
 
```
./scripts/open-dashboards.sh
```
 
| Dashboard | URL | Credentials |
|---|---|---|
| Grafana | http://localhost:3000 | `admin` / see `credentials.txt` |
| Prometheus | http://localhost:9090 | none |
| ArgoCD | https://localhost:8080 | `admin` / see `credentials.txt`, accept the self-signed cert warning |
 
### Verification
 
```
kubectl get pods
kubectl argo rollouts get rollout demo-service
argocd app get demo-service
kubectl get chaosresult demo-service-chaos-pod-delete -n default -o jsonpath="{.status.experimentStatus.verdict}"; echo
cd terraform && terraform plan
```
 
### Teardown
 
```
./scripts/teardown.sh
```
 
Destroys the cluster, cleans local state, verifies nothing remains.
 
---
 
## Repository layout
 
```
apps/demo-service/     application code, Dockerfile
terraform/               cluster provisioning
scripts/
  setup.sh               full platform bring-up
  open-dashboards.sh      self-healing dashboard access
  teardown.sh             verified teardown
.github/workflows/
  ci-app.yaml             image build, Trivy scan
  ci-iac.yaml             Terraform validate, Checkov scan
docs/architecture.md      extended component-level documentation
```
 
Kubernetes manifests live in the [config repository](https://github.com/AnuragBaiju/self-healing-gitops-config), under `k8s/`.
 
---
 
## Known limitations
 
The application under test is intentionally minimal, existing to exercise the platform's mechanics rather than to serve as a production service. Security configuration (self-signed certificates, a fake secrets provider, an unrotated ArgoCD admin account) is appropriate for local demonstration and not for a production deployment. The `ExternalSecret` resource occasionally reports `OutOfSync` in ArgoCD despite being `Healthy`, a cosmetic artifact of a generated field rather than a functional issue.
 
















































































