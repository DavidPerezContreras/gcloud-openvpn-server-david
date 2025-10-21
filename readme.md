# 🌐 OpenVPN Server on Google Kubernetes Engine (GKE)

This project automates the deployment of a secure, containerized OpenVPN server on GKE using GitHub Actions, Docker, and Google Cloud services.

> ⚠️ This setup does **not** use Infrastructure as Code (IaC). Configuration is spread across scripts and manifests, so manual updates are required. Improvements like centralized config, interactive setup, and script separation are recommended.

Client `.ovpn` configuration files are placed under the `./clients` folder.  
**Always run scripts from the workspace root**, and **replace the reserved static IP manually** after setup.

---

## 📦 Features

- 🔐 OpenVPN server with EasyRSA-based PKI
- 🐳 Dockerized deployment with Kubernetes manifests
- ☁️ CI/CD pipeline via GitHub Actions
- 🔑 Client certificate generation
- 📦 Image publishing to Google Artifact Registry
- 🔒 Secure secret handling via GitHub Secrets

---

## 🚀 Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/gcloud-openvpn-server-david.git
cd gcloud-openvpn-server-david
```

---

### 2. Configure GCP Project and Region

Update the following values in:

- `setup-gke-vpn.sh`
- `cleanup-gke-vpn.sh`
- `.github/workflows/deploy.yml`

Set:

- `PROJECT_ID`
- `REGION` (e.g. `us-east1`)
- `ZONE` (e.g. `us-east1-b`)
- `REPO_NAME` (e.g. `openvpn-repo`)
- `CLUSTER_NAME` (e.g. `vpn-cluster`)

---

### 3. Run the Setup Script

```bash
./setup-gke-vpn.sh
```

This provisions the GKE cluster, reserves a static IP, and sets up firewall rules.

> 🔁 Replace the reserved static IP manually in:
> - `clients/create-client.sh`
> - `k8s/deployment.yaml`
> - `server.conf`

---

### 4. Generate Server Keys

```bash
./scripts/gen-keys.sh
```

This creates:

- CA and server certificates
- TLS key (`ta.key`)
- DH parameters

All stored in `volume/`.

---

### 5. Generate Client Profiles

```bash
./clients/create-client.sh <username>
```

Creates a `.ovpn` profile in `clients/<username>/` with embedded certs and keys.

---

### 6. Push Docker Image to Artifact Registry

Handled automatically by GitHub Actions on push to `master`. It:

- Builds the Docker image
- Pushes it to Artifact Registry
- Deploys to GKE using `kubectl apply`

---

### 7. Configure GitHub Secrets

In your GitHub repository, add:

| Secret Name         | Description                                |
|---------------------|--------------------------------------------|
| `GCP_SA_KEY`        | JSON key of your GCP service account       |
| `GCP_PROJECT_ID`    | Your GCP project ID                        |

---

### 8. Trigger Deployment

Push to the `master` branch or run the workflow manually from GitHub Actions.

---

## 🧹 Cleanup

To tear down the infrastructure:

```bash
./cleanup-gke-vpn.sh --remove-cluster
```

Deletes:

- GKE cluster
- Artifact Registry repo
- Static IPs
- Firewall rules
- Orphaned disks

---

## ✅ Status Check

After deployment:

```bash
kubectl get pods
kubectl get svc
```

To verify VPN modules:

```bash
lsmod | grep vbox
```

---

## 📁 Project Structure

```
.
├── cleanup-gke-vpn.sh
├── clients
│   └── create-client.sh
├── Dockerfile
├── k8s
│   ├── deployment.yaml
│   ├── persistent-volume.yaml
│   └── service.yaml
├── readme.md
├── scripts
│   ├── entrypoint.sh
│   ├── gen-keys.sh
│   └── vpn-startup.sh
├── server.conf
├── setup-gke-vpn.sh
└── volume
```

---

## 🛠️ Requirements

To run and deploy this project, you’ll need:

- ✅ [Google Cloud SDK (gcloud CLI)](https://cloud.google.com/sdk/docs/install)
- ✅ Docker
- ✅ EasyRSA (installed via package manager)
- ✅ GitHub Actions runner:
  - Either **self-hosted** (recommended for full control)
  - Or **GitHub-hosted** (with proper permissions and secrets)

---

## 📬 Support

For issues or contributions, please open a GitHub issue or pull request.
