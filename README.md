# Self-Healing GitOps Platform

![CI](https://github.com/AnuragBaiju/self-healing-gitops-platform/actions/workflows/ci-app.yaml/badge.svg)

A production-pattern Kubernetes platform that automates deployments end-to-end: push code to Git, and the system builds, tests, gradually rolls it out, watches real metrics, and automatically rolls back if anything breaks, with zero manual intervention.

## Repositories

This project is split into two repositories, matching how real platform teams separate application code from deployment configuration.

- self-healing-gitops-platform (this repo): application code, Dockerfile, Terraform, CI workflows, docs
- self-healing-gitops-config: all Kubernetes manifests, continuously watched and synced by ArgoCD

## What this proves

- Progressive delivery: new versions receive a small slice of traffic first (20 percent, then 50 percent, then 100 percent), gated by live health checks at each step
- Automated rollback: a broken deployment is detected and reverted automatically, based on real request success-rate data
- GitOps: the cluster continuously reconciles itself to match the config repository, no manual kubectl apply in normal operation
- Infrastructure as code: the cluster itself is provisioned and torn down via Terraform
- Secrets management: sensitive values are fetched from an external store at runtime, never committed to Git
- Chaos engineering: automated fault injection with verified, passing recovery
- CI: automated image build, container vulnerability scanning, and infrastructure security scanning on every relevant change

## Architecture

git push to the app repo triggers CI (build and scan). Separately, git push to the config repo is picked up by ArgoCD, which syncs the cluster. Argo Rollouts then runs a staged canary rollout, checking live Prometheus metrics at each step via an AnalysisTemplate, which decides whether to continue the rollout or trigger an automatic rollback.

See docs/architecture.md for the full breakdown.

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

## Running it locally

kind create cluster --name self-healing-demo
git clone https://github.com/AnuragBaiju/self-healing-gitops-config.git
kubectl apply -f self-healing-gitops-config/k8s/

ArgoCD then takes over. Further changes go through git push to the config repo, not kubectl apply.
