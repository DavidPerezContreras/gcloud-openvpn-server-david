#!/bin/bash
set -e

# 🔧 CONFIGURATION
PROJECT_ID="vpn-project-ciber"
CLUSTER_NAME="vpn-cluster"
ZONE="us-east1-b"
REGION="us-east1"
REPO_NAME="openvpn-repo"
NODE_TAG="openvpn-node"
STATIC_IP_NAME="vpn-static-ip"
BUCKET_NAME="vpn-startup-scripts"

# 🏁 Parse arguments
REMOVE_CLUSTER=false
if [[ "$1" == "--remove-cluster" ]]; then
  REMOVE_CLUSTER=true
fi

echo "🔐 Setting project..."
gcloud config set project "$PROJECT_ID"

if $REMOVE_CLUSTER; then
  echo "🧹 Deleting GKE cluster..."
  EXISTS=$(gcloud container clusters list --zone "$ZONE" --filter="name=$CLUSTER_NAME" --format="value(name)")
  if [[ -n "$EXISTS" ]]; then
    gcloud container clusters delete "$CLUSTER_NAME" --zone "$ZONE" --quiet
  else
    echo "✅ Cluster already deleted or not found"
  fi
else
  echo "🚫 Skipping cluster deletion (use --remove-cluster to delete it)"
fi

echo "📦 Deleting Artifact Registry repository..."
gcloud artifacts repositories delete "$REPO_NAME" \
  --location="$REGION" \
  --quiet || echo "✅ Repository already deleted"

echo "🔥 Deleting firewall rules..."
for RULE in allow-openvpn allow-vpn-egress; do
  gcloud compute firewall-rules delete "$RULE" --quiet || echo "✅ Rule $RULE already deleted"
done

echo "🏷️ Removing tags and metadata from GKE node..."
NODE_NAME=$(gcloud compute instances list \
  --filter="name~'gke-${CLUSTER_NAME}' AND status=RUNNING" \
  --format="value(name)" | head -n 1)
if [[ -n "$NODE_NAME" ]]; then
  gcloud compute instances remove-tags "$NODE_NAME" \
    --zone="$ZONE" \
    --tags="$NODE_TAG" --quiet || echo "✅ Tags already removed"

  gcloud compute instances remove-metadata "$NODE_NAME" \
    --zone="$ZONE" \
    --keys=startup-script-url,enable-ip-forwarding --quiet || echo "✅ Metadata already removed"
else
  echo "✅ No active node found"
fi

echo "🌐 Releasing all static IP addresses in project..."
ADDRESSES=$(gcloud compute addresses list --format="value(name,region)")
while read -r NAME REGION; do
  echo "🧹 Releasing IP: $NAME in $REGION"
  gcloud compute addresses delete "$NAME" --region="$REGION" --quiet || echo "✅ IP $NAME already released"
done <<< "$ADDRESSES"

echo "🪣 Deleting Cloud Storage bucket for startup script..."
gsutil rm -r "gs://${BUCKET_NAME}" || echo "✅ Bucket already deleted or not found"

echo "💾 Cleaning up orphaned disks..."
DISKS=$(gcloud compute disks list --filter="zone:$ZONE" --format="value(name)")
for DISK in $DISKS; do
  echo "🧹 Deleting disk: $DISK"
  gcloud compute disks delete "$DISK" --zone="$ZONE" --quiet || echo "✅ Disk $DISK already deleted"
done

echo ""
echo "✅ Cleanup complete. Your GCP project '$PROJECT_ID' is now clean."
