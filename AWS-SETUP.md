# AWS Setup Guide — Blue-Green Deployment on EKS

This guide walks you through deploying the Blue-Green demo to AWS using a real EKS cluster and ECR Docker registry provisioned via Terraform.

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | ≥ 1.5 | Provision AWS infrastructure |
| AWS CLI | ≥ 2.x | AWS authentication; configure with `aws configure` |
| Docker | Latest | Build and push container images |
| kubectl | Latest | Apply Kubernetes manifests to EKS |

> Your AWS IAM user/role needs permissions for: `ec2`, `eks`, `ecr`, `iam`, `s3`, `dynamodb`.

---

## Step 0 (Optional): Bootstrap Remote Terraform State

By default, Terraform stores state locally. For team environments or production use, configure remote state in S3 with DynamoDB locking.

```bash
cd terraform/bootstrap-backend
terraform init
terraform apply
```

This creates:
- An **S3 bucket** (uniquely named, versioned, AES256-encrypted) to store state files.
- A **DynamoDB table** (`bg-devops-tf-locks`) to prevent concurrent runs.

When finished, note the output `s3_bucket_name`. Then:

1. Open `terraform/provider.tf`.
2. Uncomment the `backend "s3"` block.
3. Replace `bg-devops-tf-state-YOUR_UNIQUE_SUFFIX` with your actual bucket name.

Now all Terraform state will be safely stored on AWS.

---

## Step 1: Provision Infrastructure with Terraform

The Terraform configuration in `terraform/` will create:

| Resource | Details |
|----------|---------|
| **VPC** | 10.0.0.0/16 with 2 public + 2 private subnets across 2 AZs |
| **NAT Gateway** | Single NAT for private subnet internet access |
| **EKS Cluster** | Kubernetes 1.30, public endpoint enabled |
| **Node Group** | 2× `t3.medium` on-demand instances (AL2 x86_64) |
| **ECR Repository** | Private registry for blue/green Docker images |

```bash
cd terraform
terraform init
terraform plan     # review what will be created
terraform apply    # type 'yes' to confirm
```

> ⏱️ **EKS provisioning takes ~10–15 minutes.** The NAT gateway and VPC are quick; wait for the EKS control plane.

When complete, Terraform outputs:
```
cluster_endpoint      = "https://XXXX.gr7.us-east-1.eks.amazonaws.com"
cluster_name          = "bg-devops-cluster"
ecr_repository_url    = "123456789.dkr.ecr.us-east-1.amazonaws.com/bg-devops-demo-app"
configure_kubectl     = "aws eks update-kubeconfig --region us-east-1 --name bg-devops-cluster"
```

---

## Step 2: Deploy the Application to AWS

From the **project root** (not inside `terraform/`), run:

```bash
chmod +x scripts/deploy-aws.sh
./scripts/deploy-aws.sh
```

This script automatically:
1. Reads `ecr_repository_url` and `cluster_name` from Terraform outputs.
2. Authenticates Docker with AWS ECR.
3. Builds and pushes `<ECR_URL>:blue` and `<ECR_URL>:green` images.
4. Updates your local `kubectl` context to point at the EKS cluster.
5. Applies `k8s/service.yaml` to the cluster.
6. Applies `blue-deployment.yaml` and `green-deployment.yaml`, dynamically substituting the ECR URL for the local image name.
7. Waits for both rollouts to complete.

### Network Access Note

The default `service.yaml` uses `NodePort`. On EKS, **LoadBalancer type is recommended** to get an AWS ELB DNS name automatically:

```yaml
# k8s/service.yaml
spec:
  type: LoadBalancer   # changed from NodePort
```

After applying, get your external DNS name:
```bash
kubectl get svc bg-demo-service
# EXTERNAL-IP column will show an ELB DNS name (takes ~2 min to provision)
```

---

## Step 3: Switch Traffic

Traffic switching works identically to local testing — `switch-traffic.sh` simply patches the Kubernetes Service:

```bash
chmod +x scripts/switch-traffic.sh

# Route to Green
./scripts/switch-traffic.sh green

# Roll back to Blue
./scripts/switch-traffic.sh blue
```

---

## Step 4: Teardown — Avoid Ongoing AWS Costs

> ⚠️ **EKS clusters + NAT Gateways cost money even when idle.** Always destroy when done.

Before destroying with Terraform, delete Kubernetes resources that may have provisioned AWS load balancers (otherwise Terraform destroy will hang):

```bash
kubectl delete svc bg-demo-service
kubectl delete deployment app-blue app-green
```

Then destroy the infrastructure:

```bash
cd terraform
terraform destroy   # type 'yes' to confirm
```

---

## Automating with Jenkins CI/CD

Use `Jenkinsfile-aws.jenkinsfile` for a fully automated pipeline:

| Stage | Triggered when ACTION = |
|-------|------------------------|
| Terraform Apply | `Terraform Apply` |
| Deploy App to AWS | `Deploy AWS App` |
| Switch Traffic | `Switch Traffic` |
| Terraform Destroy | `Terraform Destroy` |

**Jenkins agent requirements:**
- AWS credentials configured (IAM instance role, or `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` environment variables in Jenkins credentials store).
- Docker, Terraform, kubectl, and AWS CLI installed on the agent.

**Recommended credential setup in Jenkins:**
1. Go to **Manage Jenkins → Credentials → System → Global credentials**.
2. Add `Secret text` credentials for `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
3. Reference them in the pipeline `environment` block:
   ```groovy
   environment {
       AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
       AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
       AWS_DEFAULT_REGION    = "us-east-1"
   }
   ```
