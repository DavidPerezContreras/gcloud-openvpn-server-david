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
STARTUP_SCRIPT_LOCAL="./scripts/vpn-startup.sh"
STARTUP_SCRIPT_URL="gs://${BUCKET_NAME}/vpn-startup.sh"
GITHUB_DEPLOYER="github-deployer@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🔐 Setting project..."
gcloud config set project "$PROJECT_ID"

echo "🌐 Checking for existing static IP..."
EXISTING_IP=$(gcloud compute addresses list \
  --filter="name=${STATIC_IP_NAME} AND region:(${REGION})" \
  --format="value(address)")

if [[ -z "$EXISTING_IP" ]]; then
  echo "📡 Reserving new static IP..."
  gcloud compute addresses create "$STATIC_IP_NAME" \
    --region="$REGION" \
    --network-tier=PREMIUM
else
  echo "✅ Reusing existing static IP: $EXISTING_IP"
fi

STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" \
  --region="$REGION" \
  --format="value(address)")

echo ""
echo "📡 Reserved static IP: $STATIC_IP"
echo "📝 IMPORTANT: Update your k8s/service.yaml with this IP:"
echo ""
echo "    loadBalancerIP: $STATIC_IP"
echo ""

echo "📦 Creating Artifact Registry..."
gcloud artifacts repositories create "$REPO_NAME" \
  --repository-format=docker \
  --location="$REGION" || echo "✅ Repo already exists"

echo "🔍 Checking if GKE cluster exists..."
EXISTS=$(gcloud container clusters list --zone "$ZONE" --filter="name=$CLUSTER_NAME" --format="value(name)")
if [[ -z "$EXISTS" ]]; then
  echo "🚀 Creating GKE cluster with 15GB disk..."
  gcloud container clusters create "$CLUSTER_NAME" \
    --zone "$ZONE" \
    --num-nodes=1 \
    --machine-type=e2-micro \
    --disk-size=15 \
    --enable-ip-alias \
    --scopes=https://www.googleapis.com/auth/cloud-platform
else
  echo "✅ GKE cluster '$CLUSTER_NAME' already exists"
fi

echo "🔓 Granting Artifact Registry access to GKE node service account..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/artifactregistry.reader" || echo "✅ IAM binding already exists"

echo "🔐 Granting IAM permissions to GitHub deployer service account..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${GITHUB_DEPLOYER}" \
  --role="roles/resourcemanager.projectIamAdmin" || echo "✅ GitHub deployer already has IAM admin"

echo "🔥 Creating firewall rule for OpenVPN..."
gcloud compute firewall-rules create allow-openvpn \
  --allow=udp:1194 \
  --target-tags="$NODE_TAG" \
  --direction=INGRESS \
  --source-ranges=0.0.0.0/0 || echo "✅ Rule already exists"

echo "🌐 Creating firewall rule for VPN egress..."
gcloud compute firewall-rules create allow-vpn-egress \
  --allow=tcp:80,tcp:443,udp \
  --direction=EGRESS || echo "✅ Rule already exists"

echo "📤 Uploading startup script to Cloud Storage..."
gsutil mb -l "$REGION" "gs://${BUCKET_NAME}" || echo "✅ Bucket already exists"
gsutil cp "$STARTUP_SCRIPT_LOCAL" "$STARTUP_SCRIPT_URL"

echo "⛓️ Getting GKE credentials for kubectl..."
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$ZONE"

echo "⏳ Waiting for GKE node to become available..."
for i in {1..20}; do
  NODE_NAME=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name" | head -n 1)
  if [[ -n "$NODE_NAME" ]]; then
    echo "✅ Found node: $NODE_NAME"
    break
  fi
  echo "🔄 Node not ready yet... retrying in 15s"
  sleep 15
done

if [[ -z "$NODE_NAME" ]]; then
  echo "❌ Failed to find GKE node after waiting — aborting."
  exit 1
fi

echo "🏷️ Tagging GKE node for firewall targeting..."
gcloud compute instances add-tags "$NODE_NAME" \
  --tags="$NODE_TAG" \
  --zone="$ZONE" || echo "✅ Tags already applied"

echo "📜 Attaching startup script to enable IP forwarding and NAT..."
gcloud compute instances add-metadata "$NODE_NAME" \
  --zone="$ZONE" \
  --metadata startup-script-url="$STARTUP_SCRIPT_URL",enable-ip-forwarding=true || echo "✅ Metadata already set"

echo "🔁 Rebooting node to apply startup script..."
gcloud compute instances reset "$NODE_NAME" --zone="$ZONE"

echo ""
echo "✅ GKE VPN environment is ready."
echo "📡 Final static IP: $STATIC_IP"
echo "📝 Reminder: Update k8s/service.yaml with this IP before deploying."
