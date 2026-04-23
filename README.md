# Blue-Green Deployment DevOps Sandbox

> **A production-realistic, end-to-end learning sandbox** for a fresher DevOps engineer to learn zero-downtime deployment strategies using Docker, Kubernetes, Terraform (AWS EKS), and Jenkins CI/CD.

---

## What is Blue-Green Deployment?

Blue-Green deployment reduces downtime and release risk by running two identical production environments called **Blue** and **Green**.

- **Only one environment is live** at any time, serving all production traffic.
- The **idle environment** receives the new release and is tested in isolation.
- A **single atomic switch** (patching the Kubernetes Service selector) moves 100% of traffic from the old version to the new one — with zero downtime.
- If anything goes wrong, you can instantly **roll back** by switching traffic back.

```
 Users ──────────────────► Kubernetes Service ────► [ BLUE  Pods (live)  ]
                                (selector patch)
                                                ────► [ GREEN Pods (idle) ]
```

---

## Project Architecture

```
blue-green-devops/
├── app/                        # Node.js demo application
│   ├── Dockerfile              # Multi-stage-friendly Node 18 Alpine image
│   ├── package.json            # Express dependency
│   ├── server.js               # REST API + env-driven version reporting
│   └── public/
│       └── index.html          # Auto-refreshing UI (shows blue/green + pod name)
│
├── k8s/                        # Kubernetes manifests
│   ├── blue-deployment.yaml    # Deployment: 2 replicas, tag :blue, APP_VERSION=blue
│   ├── green-deployment.yaml   # Deployment: 2 replicas, tag :green, APP_VERSION=green
│   └── service.yaml            # NodePort service — selector.version drives traffic
│
├── scripts/                    # Automation shell scripts
│   ├── deploy.sh               # Local: build images + apply all manifests
│   ├── switch-traffic.sh       # Universal: patch service selector to blue or green
│   └── deploy-aws.sh           # AWS: login to ECR, push images, deploy to EKS
│
├── terraform/                  # AWS Infrastructure-as-Code
│   ├── provider.tf             # AWS provider + optional S3 remote backend config
│   ├── variables.tf            # Region, cluster name, ECR repo name
│   ├── vpc.tf                  # VPC with public/private subnets across 2 AZs
│   ├── eks.tf                  # EKS cluster + managed node group (t3.medium × 2)
│   ├── ecr.tf                  # ECR repository for Docker images
│   ├── outputs.tf              # Outputs: cluster_name, ecr_repository_url, kubectl cmd
│   └── bootstrap-backend/      # (Optional) S3 + DynamoDB for remote Terraform state
│       ├── main.tf
│       └── versions.tf
│
├── .github/
│   └── workflows/
│       └── blue-green-cd.yml   # GitHub Actions: manual traffic switch trigger
│
├── Jenkinsfile                 # Jenkins pipeline: local deploy + traffic switch
├── Jenkinsfile-aws.jenkinsfile # Jenkins pipeline: Terraform + AWS deploy + switch
├── AWS-SETUP.md                # Step-by-step guide for the full AWS/EKS path
└── README.md                   # This file
```

---

## Prerequisites

### For Local Testing (Minikube / Kind / Docker Desktop K8s)

| Tool | Version | Purpose |
|------|---------|---------|
| Docker Desktop | Latest | Build and run containers |
| kubectl | Latest | Apply Kubernetes manifests |
| Minikube / Kind | Latest | Local Kubernetes cluster |
| Git Bash / WSL / Linux terminal | — | Run `.sh` scripts on Windows |

> **Windows users:** All `.sh` scripts must be run from **Git Bash**, **WSL**, or a Linux terminal. PowerShell cannot natively execute them.

### For AWS Deployment

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | ≥ 1.5 | Provision EKS, VPC, ECR |
| AWS CLI | ≥ 2.x | Interact with AWS; configure credentials |
| kubectl | Latest | Apply manifests to EKS |
| Docker | Latest | Build and push images to ECR |

---

## Quick Start — Local Demo

### Step 1: Make Scripts Executable

```bash
chmod +x scripts/deploy.sh
chmod +x scripts/switch-traffic.sh
```

### Step 2: Start Your Local Cluster

Choose one of the following:
```bash
# Docker Desktop: enable Kubernetes in Settings → Kubernetes

# OR Minikube:
minikube start

# OR Kind:
kind create cluster
```

### Step 3: Deploy Blue and Green Environments

```bash
./scripts/deploy.sh
```

This script:
1. Builds `devops-demo/bg-app:blue` and `devops-demo/bg-app:green` Docker images (same source — `APP_VERSION` env var differentiates them at runtime).
2. Applies `k8s/service.yaml` (traffic defaults to **Blue**).
3. Applies both `blue-deployment.yaml` and `green-deployment.yaml`.
4. Waits for both rollouts to complete.

> **Kind/Minikube users:** You need to load the local Docker image into your cluster. Uncomment the relevant line in `deploy.sh`:
> ```bash
> # kind load docker-image devops-demo/bg-app:blue devops-demo/bg-app:green
> # minikube image load devops-demo/bg-app:blue devops-demo/bg-app:green
> ```

### Step 4: Access the Application

```bash
kubectl port-forward service/bg-demo-service 8080:80
```

Open your browser: **http://localhost:8080**

You will see a **blue** background with `v1.0 (BLUE)`. The page auto-refreshes every **2 seconds** and shows which pod is serving the request.

> Alternatively, on a local cluster configured with NodePort access, use port **30080** on the node IP.

### Step 5: Switch Traffic — Zero Downtime!

Open a **second terminal** and run:

```bash
# Switch to Green
./scripts/switch-traffic.sh green

# Switch back to Blue
./scripts/switch-traffic.sh blue
```

Watch your browser — within 2 seconds the background color and version label will flip. **No restart, no downtime.**

---

## How Traffic Switching Works

The `service.yaml` uses a **label selector** to route traffic:

```yaml
spec:
  selector:
    app: demo-app
    version: blue   # ← This single field controls everything
```

`switch-traffic.sh` uses `kubectl patch` to atomically update this field:

```bash
kubectl patch service bg-demo-service \
  -p '{"spec":{"selector":{"app":"demo-app","version":"green"}}}'
```

Kubernetes immediately reroutes all new connections to the Green pods. Existing connections drain gracefully.

---

## Deploying to AWS (EKS + ECR)

For a full cloud deployment using Terraform-provisioned infrastructure, see the dedicated guide:

📄 **[AWS Setup Guide](AWS-SETUP.md)**

It covers:
- Optional: Bootstrap S3 remote state for Terraform
- Provisioning VPC + EKS + ECR with `terraform apply`
- Building and pushing images to ECR via `scripts/deploy-aws.sh`
- Switching traffic on EKS
- Tearing down to avoid AWS charges

---

## CI/CD Pipelines

### Jenkins — Local (`Jenkinsfile`)

A parameterized pipeline with two actions:

| Parameter `ACTION` | What it does |
|--------------------|-------------|
| `Deploy` | Runs `scripts/deploy.sh` to build images and deploy both environments |
| `Switch Traffic` | Runs `scripts/switch-traffic.sh <TARGET_ENV>` |

**Setup:** Point a Jenkins Pipeline job at this repo and set the `Script Path` to `Jenkinsfile`.

### Jenkins — AWS (`Jenkinsfile-aws.jenkinsfile`)

A full end-to-end AWS pipeline with four stages:

| Parameter `ACTION` | What it does |
|--------------------|-------------|
| `Terraform Apply` | Runs `terraform init && apply` to provision EKS/ECR/VPC |
| `Deploy AWS App` | Runs `scripts/deploy-aws.sh` — ECR push + EKS deploy |
| `Switch Traffic` | Patches the EKS service selector |
| `Terraform Destroy` | Tears down all AWS infrastructure |

**Setup:** The Jenkins agent must have AWS credentials configured (IAM role or `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` environment variables).

### GitHub Actions (`.github/workflows/blue-green-cd.yml`)

A manually-triggered (`workflow_dispatch`) workflow that performs traffic switching. To make it functional against a real cluster:

1. Store your kubeconfig as a GitHub repository secret named `KUBECONFIG`.
2. Uncomment the `Set up Kubeconfig` and `kubectl patch` steps in the workflow file.

---

## Key Concepts Demonstrated

| Concept | Where to look |
|---------|--------------|
| Blue-Green strategy | `k8s/` manifests + `scripts/switch-traffic.sh` |
| Containerization | `app/Dockerfile` |
| Kubernetes Deployments & Services | `k8s/` |
| Infrastructure as Code | `terraform/` |
| Remote Terraform state | `terraform/bootstrap-backend/` + `provider.tf` |
| Jenkins parameterized pipelines | `Jenkinsfile`, `Jenkinsfile-aws.jenkinsfile` |
| GitHub Actions CD | `.github/workflows/blue-green-cd.yml` |

---

## Cleanup

### Local
```bash
kubectl delete -f k8s/
```

### AWS
```bash
cd terraform
terraform destroy
```

> ⚠️ **Always run `terraform destroy` when done with AWS testing.** EKS clusters and NAT Gateways accrue costs even when idle.
