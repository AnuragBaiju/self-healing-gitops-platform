#!/bin/bash

echo "Clearing any stale port-forwards..."
for port in 3000 8080 9090; do
  pid=$(lsof -ti:$port)
  if [ -n "$pid" ]; then
    proc_name=$(ps -p "$pid" -o comm= 2>/dev/null)
    if [[ "$proc_name" == *"kubectl"* ]]; then
      echo "  Killing stale kubectl port-forward on port $port (pid $pid)"
      kill "$pid" 2>/dev/null
    else
      echo "  Warning: port $port is in use by '$proc_name' (pid $pid), not kubectl - leaving it alone"
    fi
  fi
done
sleep 1

echo "Starting Grafana port-forward on http://localhost:3000 ..."
kubectl port-forward -n observability svc/monitoring-grafana 3000:80 >/dev/null 2>&1 &
echo "Starting Prometheus port-forward on http://localhost:9090 ..."
kubectl port-forward -n observability svc/monitoring-kube-prometheus-prometheus 9090:9090 >/dev/null 2>&1 &
echo "Starting ArgoCD port-forward on https://localhost:8080 ..."
kubectl port-forward -n argocd svc/argocd-server 8080:443 >/dev/null 2>&1 &
sleep 2

echo ""
echo "Dashboards ready:"
echo "  Grafana:    http://localhost:3000  (admin / see: kubectl get secret -n observability monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d)"
echo "  Prometheus: http://localhost:9090"
echo "  ArgoCD:     https://localhost:8080  (admin / see: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo ""
echo "Press Ctrl+C to stop all port-forwards"
wait
