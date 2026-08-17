# Self-Healing GitOps Platform

![CI](https://github.com/AnuragBaiju/self-healing-gitops-platform/actions/workflows/ci-app.yaml/badge.svg)

A production-pattern Kubernetes platform that automates deployments end-to-end: push code to Git, and the system builds, tests, gradually rolls it out, watches real metrics, and automatically rolls back if anything breaks - with zero manual intervention.

## What this proves

- Progressive delivery: new versions receive a small slice of traffic first (20% -> 50% -> 100%), gated by live health checks at each step
- Automated rollback: a broken deployment is detected and reverted automatically, based on real request success-rate data, not guesswork
- GitOps: the cluster continuously reconciles itself to match a Git repository, no manual kubectl apply in normal operation
- Infrastructure as code: the cluster itself is provisioned and torn down via Terraform, not manual commands
- Secrets management: sensitive values are fetched from an external store at runtime, never committed to Git
- Chaos engineering: automated fault injection (pod deletion) with verified, passing recovery

## Architecture

git push, then ArgoCD watches the repo, then Kubernetes and Argo Rollouts run a canary rollout, then Prometheus collects live metrics, then an AnalysisTemplate makes a pass or fail decision, which either continues the rollout or triggers an automatic rollback.

## Stack

App: Python (Flask)
Containerization: Docker, multi-stage, non-root
Orchestration: Kubernetes (kind)
Progressive delivery: Argo Rollouts
Observability: Prometheus and Grafana
GitOps: ArgoCD
Infrastructure as code: Terraform
Secrets: External Secrets Operator
Chaos engineering: LitmusChaos

## Repo layout

apps/demo-service: app code and Dockerfile
k8s: all Kubernetes manifests
terraform: cluster provisioning

## Key mechanism: automated rollback

k8s/analysis-template.yaml defines a Prometheus query measuring live request success rate. k8s/rollout.yaml runs that check at each traffic-weight step during a deployment. If success rate drops below 90 percent, Argo Rollouts automatically aborts and restores 100 percent traffic to the last known-good version. This was proven live by deploying a version with an injected failure rate and watching it get caught and reverted within seconds.

## Running it locally

kind create cluster --name self-healing-demo
kubectl apply -f k8s/

ArgoCD then takes over. Any further changes go through git push, not kubectl apply.
