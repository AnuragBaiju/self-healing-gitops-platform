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
if [ -f terraform.tfstate ]; then
  terraform destroy -auto-approve
else
  echo "  No Terraform state found, skipping."
fi
cd ..

echo "Checking for any leftover kind clusters..."
LEFTOVER=$(kind get clusters 2>/dev/null)
if [ -n "$LEFTOVER" ]; then
  echo "$LEFTOVER" | while read -r cluster; do
    echo "  Deleting leftover cluster: $cluster"
    kind delete cluster --name "$cluster"
  done
else
  echo "  None found."
fi

echo ""
rm -f terraform/terraform.tfstate terraform/terraform.tfstate.backup

echo "Teardown complete. Run ./scripts/setup.sh to rebuild from scratch."
