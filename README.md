# Cloud-Native Blue-Green Deployment Sandbox

> **A production-realistic, end-to-end DevOps sandbox** for learning zero-downtime blue-green deployment strategies using Docker, Kubernetes, Terraform (AWS EKS), and Jenkins/GitHub Actions CI/CD.

#### Zero-Downtime Sandbox Output:

<table>
  <tr>
    <td align="center"><b>Blue Version (Active)</b><br><img src="docs/assets/blue-version.png" alt="Blue Environment Output" width="380"></td>
    <td align="center"><b>Green Version (Idle)</b><br><img src="docs/assets/green-version.png" alt="Green Environment Output" width="380"></td>
  </tr>
</table>

---

## 📂 Project Documentation

All detailed user guides, infrastructure setup instructions, and pipeline guides have been organized under the [`docs/`](docs/) directory:

| Guide | Description | Target Audience |
| :--- | :--- | :--- |
| 📄 **[Main Sandbox Overview & Local Setup](docs/Local-Guide.md)** | Learn the blue-green concept, start local cluster (Kind/Minikube), run deployment, and test traffic routing. | Beginners & Operators |
| 📄 **[AWS EKS Setup Guide](docs/AWS-Guide.md)** | Provision AWS infrastructure (VPC, ECR, EKS) using Terraform and deploy the app to the cloud. | Intermediate & Advanced |
| 📄 **[CI/CD Pipelines Manual](docs/CICD-Guide.md)** | Comprehensive instructions for setting up GitHub Actions workflows and local/AWS Jenkins files. | All Levels |

---

## 🛠️ Sandbox Structure

```
├── docs/                        # Complete project documentation
│   ├── assets/                  # Deployment output screenshots
│   ├── Local-Guide.md           # Local setup guide
│   ├── AWS-Guide.md             # AWS/EKS setup guide
│   └── CICD-Guide.md            # GitHub Actions & Jenkins pipeline guide
│
├── app/                         # Node.js demo web application code
│   ├── Dockerfile               # Multi-stage secure container definition
│   └── server.js                # Express web server
│
├── k8s/                         # Kubernetes manifests
│   ├── blue-deployment.yaml     # Blue version deployment (v1.0)
│   ├── green-deployment.yaml    # Green version deployment (v2.0)
│   └── service.yaml             # NodePort routing service
│
├── scripts/                     # Operational Bash scripts
│   ├── deploy.sh                # Local image builder & deployment script
│   ├── deploy-aws.sh            # ECR login/push and EKS deployment
│   └── switch-traffic.sh        # Traffic routing selector patcher
│
├── terraform/                   # AWS Infrastructure-as-Code
│   ├── bootstrap-backend/       # S3 bucket and DynamoDB locking bootstrap
│   └── *.tf                     # VPC, ECR, and EKS Terraform configurations
│
├── .github/workflows/           # GitHub Actions CI/CD workflows
│   ├── ci.yml                   # Lint, security scan, docker build & CD gate
│   ├── blue-green-cd.yml        # Manual traffic selector switcher
│   └── terraform-provision.yml  # Manual AWS Infrastructure lifecycle control
│
├── Jenkinsfile                  # Local Jenkins Pipeline definition
└── aws.Jenkinsfile              # AWS EKS Jenkins Pipeline definition
```

---

## 🚀 Quick Launch (Local Demo)

1. Make scripts executable:
   ```bash
   chmod +x scripts/deploy.sh scripts/switch-traffic.sh
   ```
2. Spin up a local Kind/Minikube cluster.
3. Deploy both environments:
   ```bash
   ./scripts/deploy.sh
   ```
4. Access the app at `http://localhost:8080` (or `http://localhost:30080` for Kind).
5. Switch traffic dynamically:
   ```bash
   ./scripts/switch-traffic.sh green
   ```

For advanced AWS provisioning or CI/CD pipelines setup, navigate to the specific files in the [**Documentation Folder**](docs/).
