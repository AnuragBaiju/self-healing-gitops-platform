# Architecture

## Overview

This platform automates the path from code change to production, with automated health verification and rollback at every stage.

## Components

Application layer: a Flask service exposing /healthz, /metrics, and a root endpoint. Instrumented with prometheus-client so every request increments a labeled counter used for canary health analysis.

Container layer: multi-stage Dockerfile. Build stage installs dependencies; final stage runs as a non-root user (uid 10001) on a slim base image, minimizing attack surface.

Orchestration layer: Kubernetes, running locally via kind. Workloads are managed as an Argo Rollout rather than a plain Deployment, enabling canary traffic shifting.

Progressive delivery: Argo Rollouts controls a staged rollout (20 percent, then 50 percent, then 100 percent traffic), pausing at each stage to run an AnalysisTemplate against live Prometheus data.

Observability: kube-prometheus-stack (Prometheus, Grafana, Alertmanager). A ServiceMonitor scrapes the app's /metrics endpoint on a 10 second interval.

Automated analysis: an AnalysisTemplate issues a PromQL query calculating request success rate over a rolling window. If success rate falls below 90 percent, the rollout is automatically aborted and traffic reverted to the last stable revision.

GitOps: ArgoCD continuously reconciles cluster state against the Git repository. Automated sync with self-heal enabled means manual kubectl changes are reverted to match Git, and Git changes are applied without manual intervention.

Infrastructure as code: Terraform (kind provider) provisions the cluster itself, supporting full init, plan, apply, and destroy lifecycle.

Secrets management: External Secrets Operator fetches secret values from an external store at runtime and materializes them as native Kubernetes Secrets, so no secret value is ever committed to Git.

Chaos engineering: LitmusChaos runs a pod-delete experiment against the running Rollout on demand, verifying the system self-heals under deliberate failure injection.

CI: GitHub Actions builds the Docker image and runs a Trivy vulnerability scan on every change to the application code.

## Data flow for a deployment

1. A change is committed and pushed to the k8s manifests or app code.
2. GitHub Actions builds and scans the application image (app code changes).
3. ArgoCD detects the Git change and syncs the cluster to match.
4. Argo Rollouts begins a staged rollout of the new revision.
5. At each traffic-weight step, an AnalysisRun queries Prometheus for live success rate.
6. If the metric passes, the rollout proceeds to the next step. If it fails, the rollout is aborted and reverted automatically.
