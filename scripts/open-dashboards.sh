#!/bin/bash
echo "Starting Grafana port-forward on http://localhost:3000 ..."
kubectl port-forward -n observability svc/monitoring-grafana 3000:80 &
echo "Starting Prometheus port-forward on http://localhost:9090 ..."
kubectl port-forward -n observability svc/monitoring-kube-prometheus-prometheus 9090:9090 &
echo "Starting ArgoCD port-forward on https://localhost:8080 ..."
kubectl port-forward -n argocd svc/argocd-server 8080:443 &
sleep 2
echo ""
echo "Dashboards ready:"
echo "  Grafana:    http://localhost:3000  (admin / see: kubectl get secret -n observability monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d)"
echo "  Prometheus: http://localhost:9090"
echo "  ArgoCD:     https://localhost:8080"
echo ""
echo "Press Ctrl+C to stop all port-forwards"
wait
