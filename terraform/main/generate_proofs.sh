#!/usr/bin/env bash

set -euo pipefail

echo "=================================================="
echo " Starting Capstone Deliverables Proof Generation"
echo "=================================================="

# ------------------------------------------------------------------------------
# STEP 1: CAPTURE CLUSTER & NODE STATE
# ------------------------------------------------------------------------------
echo "[1/3] Capturing Cluster & Node State..."

{
  echo "=== CURRENT KUBECTL CONTEXT ==="
  kubectl config current-context
  echo ""
  echo "=== EKS NODES ==="
  kubectl get nodes -o wide
  echo ""
  echo "=== SYSTEM PODS (kube-system) ==="
  kubectl get pods -n kube-system -o wide
} > capstone_proof_cluster.txt

echo " Saved to: capstone_proof_cluster.txt"

# ------------------------------------------------------------------------------
# STEP 2: CAPTURE WORKLOAD & INGRESS STATE
# ------------------------------------------------------------------------------
echo "[2/3] Capturing Workload & Ingress State..."

{
  echo "=== RETAIL-APP WORKLOADS & INGRESS ==="
  kubectl get all,ingress -n retail-app -o wide
  echo ""
  echo "=== INGRESS DETAILED DESCRIBE ==="
  kubectl describe ingress retail-store-ui -n retail-app
} > capstone_proof_ingress.txt

echo " Saved to: capstone_proof_ingress.txt"

# ------------------------------------------------------------------------------
# STEP 3: CAPTURE LIVE TRAFFIC & TARGET HEALTH
# ------------------------------------------------------------------------------
echo "[3/3] Testing Traffic Flow & Target Group Health..."

# Retrieve ALB DNS Name
ALB_DNS=$(kubectl get ingress retail-store-ui -n retail-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Resolve ALB Public IP (Git Bash/MinGW & Linux compatible)
ALB_IP=$(nslookup "$ALB_DNS" | tr -d '\r' | awk '/Addresses:/ {getline; print $1}')
 
{
  echo "=== LIVE METADATA ==="
  echo "ALB DNS: $ALB_DNS"
  echo "ALB IP:  $ALB_IP"
  echo ""
  echo "=== TESTING HTTPS (443) DIRECT ==="
  curl -kI "https://store.${ALB_IP}.nip.io" || true
  echo ""
  echo "=== TESTING HTTP (80) DIRECT ==="
  curl -I "http://store.${ALB_IP}.nip.io" || true
  echo ""
  echo "=== TESTING AWS TARGET GROUP HEALTH ==="
  TG_ARN=$(aws elbv2 describe-target-groups --region us-east-1 --query "TargetGroups[0].TargetGroupArn" --output text)
  aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --region us-east-1 \
    --query "TargetHealthDescriptions[*].[Target.Id, Target.Port, TargetHealth.State]" \
    --output table || true
} > capstone_proof_traffic.txt

echo " Saved to: capstone_proof_traffic.txt"

echo "=================================================="
echo " All proof files successfully generated!"
echo "=================================================="