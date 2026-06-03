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
| Terraform | ≥ 1.7 | Provision EKS, VPC, ECR |
| AWS CLI | ≥ 2.x | Interact with AWS; configure credentials |
| kubectl | Latest | Apply manifests to EKS |
| Docker | Latest | Build and push images to ECR |

---

## Quick Start — Local Demo

### Step 1: Make Scripts Executable

```bash
chmod +x scripts/deploy-local.sh
chmod +x scripts/switch-traffic.sh
```

### Step 2: Start Your Local Cluster

Choose one of the following:
```bash
# Docker Desktop: enable Kubernetes in Settings → Kubernetes

# OR Minikube:
minikube start

# OR Kind — use the provided config file (sets up 2 workers + NodePort mapping):
kind create cluster --name mycluster --config k8s/kind-config.yaml
```

### Step 3: Deploy Blue and Green Environments

```bash
./scripts/deploy-local.sh
```

This script:
1. Builds `devops-demo/bg-app:blue` and `devops-demo/bg-app:green` Docker images (same source — `APP_VERSION` env var differentiates them at runtime).
2. Applies `k8s/service.yaml` (traffic defaults to **Blue**).
3. Applies both `blue-deployment.yaml` and `green-deployment.yaml`.
4. Waits for both rollouts to complete.

> **Kind/Minikube users:** You need to load the local Docker image into your cluster. Uncomment the relevant line in `deploy-local.sh`:
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

#### Demonstration Output:

<table>
  <tr>
    <td align="center"><b>Blue Version (Active)</b><br><img src="assets/blue-version.png" alt="Blue Environment Output" width="380"></td>
    <td align="center"><b>Green Version (Idle)</b><br><img src="assets/green-version.png" alt="Green Environment Output" width="380"></td>
  </tr>
</table>


> **Tip — skip port-forward with kind:** If you created the cluster using `k8s/kind-config.yaml`, NodePort `30080` is already mapped to your machine. Open **http://localhost:30080** directly — no `port-forward` command needed.

> **Note for `switch-traffic.sh` users:** After switching traffic, the old `port-forward` stays pinned to its original pod. Run the command printed by `switch-traffic.sh` in a new terminal to reconnect to the correct pod.

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

📄 **[AWS Setup Guide](AWS-Guide.md)**

It covers:
- Optional: Bootstrap S3 remote state for Terraform
- Provisioning VPC + EKS + ECR with `terraform apply`
- Building and pushing images to ECR via `scripts/deploy-aws.sh`
- Switching traffic on EKS
- Tearing down to avoid AWS charges

---

## CI/CD Pipelines

📄 **[CI/CD Pipeline Guide](CICD-Guide.md)**

This sandbox includes automated build, test, and release configurations for both GitHub Actions and Jenkins. 

### Jenkins — Local (`jenkins/local.Jenkinsfile`)

A parameterized pipeline with two actions:

| Parameter `ACTION` | What it does |
|--------------------|-------------|
| `Deploy` | Runs `scripts/deploy-local.sh` to build images and deploy both environments |
| `Switch Traffic` | Runs `scripts/switch-traffic.sh <TARGET_ENV>` |

**Setup:** Point a Jenkins Pipeline job at this repo and set the `Script Path` to `jenkins/local.Jenkinsfile`.

### Jenkins — AWS (`jenkins/aws.Jenkinsfile`)

A full end-to-end AWS pipeline with four stages:

| Parameter `ACTION` | What it does |
|--------------------|-------------|
| `Terraform Apply` | Runs `terraform init && apply` to provision EKS/ECR/VPC |
| `Deploy AWS App` | Runs `scripts/deploy-aws.sh` — ECR push + EKS deploy |
| `Switch Traffic` | Patches the EKS service selector |
| `Terraform Destroy` | Tears down all AWS infrastructure |

**Setup:** The Jenkins agent must have AWS credentials configured (IAM role or `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` environment variables).

### GitHub Actions — CI/CD (`ci.yml`, `blue-green-cd.yml`, `terraform-provision.yml`)

Three dedicated workflows live in `.github/workflows/`:

| Workflow file | Trigger | What it does |
|---|---|---|
| `ci.yml` | Push / PR to `main` | Runs lint, kube-linter, Docker build, then auto-deploys to EKS if AWS secrets are set |
| `blue-green-cd.yml` | Manual (`workflow_dispatch`) | Patches the EKS service selector to switch traffic between blue and green |
| `terraform-provision.yml` | Manual (`workflow_dispatch`) | Runs `terraform apply` or `terraform destroy` against your AWS account |

**Activating `ci.yml` auto-deploy:** Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as repository secrets.

**Activating `blue-green-cd.yml`:** Configure `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, and `EKS_CLUSTER_NAME` as repository secrets. The workflow is pre-configured to dynamically authenticate and update connection details for EKS automatically.

---

## Key Concepts Demonstrated

| Concept | Where to look |
|---------|--------------|
| Blue-Green strategy | `k8s/` manifests + `scripts/switch-traffic.sh` |
| Containerization | `app/Dockerfile` |
| Kubernetes Deployments & Services | `k8s/` |
| Infrastructure as Code | `terraform/` |
| Remote Terraform state | `terraform/bootstrap-backend/` + `provider.tf` |
| Jenkins parameterized pipelines | `jenkins/local.Jenkinsfile`, `jenkins/aws.Jenkinsfile` |
| GitHub Actions CI/CD | `.github/workflows/ci.yml`, `blue-green-cd.yml`, `terraform-provision.yml` |

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

---

## 📚 Related Documentation

| Document | Type | Priority | Description |
| :--- | :--- | :--- | :--- |
| 📄 **[README.md](../README.md)** | Repository Landing | **Critical** | Root project overview, architecture blueprint, and navigation index. |
| 📄 **[Local-Guide.md](Local-Guide.md)** | Local Sandbox | **High** | Walkthrough for starting a local cluster (Kind/Minikube) and running local deployments. |
| 📄 **[AWS-Guide.md](AWS-Guide.md)** | Infrastructure | **High** | Step-by-step instructions for provisioning EKS/ECR/VPC via Terraform. |
| 📄 **[CICD-Guide.md](CICD-Guide.md)** | CI/CD Reference | **High** | Detailed setups, YAML/Jenkinsfile configuration, and troubleshooting for GitHub Actions & Jenkins. |

