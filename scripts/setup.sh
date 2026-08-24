#!/bin/bash
set -e

echo "Self-Healing GitOps Platform - full setup"
echo "This will take several minutes. Sit back."
echo ""

echo "[1/8] Checking prerequisites..."
command -v docker >/dev/null || { echo "Install Docker Desktop first: https://docker.com"; exit 1; }
command -v kind >/dev/null || brew install kind
command -v kubectl >/dev/null || brew install kubectl
command -v helm >/dev/null || brew install helm
command -v terraform >/dev/null || brew install terraform

echo "[2/8] Cloning config repo..."
if [ ! -d "../self-healing-gitops-config" ]; then
  git clone https://github.com/AnuragBaiju/self-healing-gitops-config.git ../self-healing-gitops-config
fi

echo "[3/8] Provisioning cluster with Terraform..."
cd terraform
terraform init
terraform apply -auto-approve
CLUSTER_NAME="self-healing-demo-tf"
cd ..

echo "[4/8] Building and loading app image..."
cd apps/demo-service
docker build -t demo-service:v2 .
kind load docker-image demo-service:v2 --name "$CLUSTER_NAME"
cd ../..

echo "[5/8] Installing Argo Rollouts..."
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

echo "[6/8] Installing Prometheus + Grafana..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
helm install monitoring prometheus-community/kube-prometheus-stack -n observability

echo "[6b/8] Installing External Secrets Operator..."
helm repo add external-secrets https://charts.external-secrets.io >/dev/null
helm repo update >/dev/null
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -
helm install external-secrets external-secrets/external-secrets -n external-secrets --version 0.9.20

echo "[6c/8] Installing LitmusChaos operator..."
kubectl create namespace litmus --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n litmus -f https://litmuschaos.github.io/litmus/litmus-operator-v3.9.0.yaml

echo "[7/8] Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts

echo "[8/8] Pointing ArgoCD at the config repo..."
sleep 20
kubectl apply -f ../self-healing-gitops-config/k8s/argocd-application.yaml

echo ""
echo "Setup complete."
echo "Run ./scripts/open-dashboards.sh to view Grafana, Prometheus, and ArgoCD."
