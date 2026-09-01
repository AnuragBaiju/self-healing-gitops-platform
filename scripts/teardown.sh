#!/bin/bash
echo "Tearing down Self-Healing GitOps Platform..."
echo ""

echo "Stopping any running port-forwards..."
for port in 3000 8080 9090; do
  pid=$(lsof -ti:$port)
  if [ -n "$pid" ]; then
    proc_name=$(ps -p "$pid" -o comm= 2>/dev/null)
    if [[ "$proc_name" == *"kubectl"* ]]; then
      kill "$pid" 2>/dev/null
    fi
  fi
done

echo "Destroying cluster via Terraform..."
cd terraform
terraform destroy -auto-approve || echo "  Terraform destroy failed or nothing to destroy, continuing..."
cd ..

echo "Deleting any kind clusters directly (belt and suspenders)..."
for cluster in $(kind get clusters 2>/dev/null); do
  echo "  Deleting cluster: $cluster"
  kind delete cluster --name "$cluster"
done

echo "Cleaning up Terraform state files..."
rm -f terraform/terraform.tfstate terraform/terraform.tfstate.backup

echo ""
echo "Verifying teardown..."
REMAINING=$(kind get clusters 2>/dev/null)
if [ -n "$REMAINING" ]; then
  echo "  WARNING: clusters still present: $REMAINING"
else
  echo "  Confirmed: no clusters remain."
fi

echo "Teardown complete. Run ./scripts/setup.sh to rebuild from scratch."
