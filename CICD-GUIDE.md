# CI/CD Pipeline Guide — GitHub Actions & Jenkins

> **A comprehensive, hands-on reference** for setting up, configuring, and managing CI/CD pipelines using **GitHub Actions** and **Jenkins** within this Cloud-Native Blue-Green Deployment project. Suitable for both beginners discovering CI/CD for the first time and experienced engineers looking for project-specific configuration details.

---

## Table of Contents

1. [Introduction — Why CI/CD Matters](#1-introduction--why-cicd-matters)
2. [Project Pipeline Overview](#2-project-pipeline-overview)
3. [GitHub Actions — Setup & Configuration](#3-github-actions--setup--configuration)
   - [3.1 How GitHub Actions Works](#31-how-github-actions-works)
   - [3.2 Workflow 1 — CI Build & Lint (`ci.yml`)](#32-workflow-1--ci-build--lint-ciyml)
   - [3.3 Workflow 2 — Blue-Green Traffic Switch (`blue-green-cd.yml`)](#33-workflow-2--blue-green-traffic-switch-blue-green-cdyml)
   - [3.4 Workflow 3 — Terraform Provisioning (`terraform-provision.yml`)](#34-workflow-3--terraform-provisioning-terraform-provisionyml)
   - [3.5 Configuring Repository Secrets](#35-configuring-repository-secrets)
   - [3.6 Tips for Common Use Cases](#36-tips-for-common-use-cases)
4. [Jenkins — Setup & Configuration](#4-jenkins--setup--configuration)
   - [4.1 How Jenkins Works](#41-how-jenkins-works)
   - [4.2 Installing Jenkins](#42-installing-jenkins)
   - [4.3 Pipeline 1 — Local Deploy (`Jenkinsfile`)](#43-pipeline-1--local-deploy-jenkinsfile)
   - [4.4 Pipeline 2 — AWS Full Stack (`aws.Jenkinsfile`)](#44-pipeline-2--aws-full-stack-awsjenkinsfile)
   - [4.5 Configuring Jenkins Credentials](#45-configuring-jenkins-credentials)
   - [4.6 Creating a Jenkins Pipeline Job](#46-creating-a-jenkins-pipeline-job)
5. [Best Practices](#5-best-practices)
6. [Troubleshooting](#6-troubleshooting)
7. [Conclusion & Next Steps](#7-conclusion--next-steps)

---

## 1. Introduction — Why CI/CD Matters

**Continuous Integration (CI)** and **Continuous Delivery/Deployment (CD)** are foundational practices in modern software engineering that automate the path from a developer's commit to a running production system.

### The Problem CI/CD Solves

Without CI/CD, teams face:
- **Integration hell** — merging code written by multiple developers in isolation causes conflicts and surprises.
- **Manual, error-prone deployments** — humans forget steps, make typos, and deploy at different times of day.
- **Slow feedback loops** — bugs discovered days after they were written are expensive to fix.
- **Inconsistent environments** — "it works on my machine" problems.

### What CI Does

Every time a developer pushes code:
1. The pipeline **checks out** the latest code automatically.
2. It runs **lint and syntax checks** to catch obvious errors.
3. It **builds** the application (compiling, packaging, creating a Docker image).
4. It runs **automated tests** to verify correctness.

If any step fails, the developer is notified immediately — before broken code can reach production.

### What CD Does

After CI passes, the pipeline can:
1. **Push artifacts** (e.g., Docker images) to a registry.
2. **Deploy** the application to a staging or production environment.
3. **Run smoke tests** to confirm the deployment is healthy.
4. **Roll back automatically** if something goes wrong.

### Tools Covered in This Guide

| Tool | Type | Hosting | Best For |
|------|------|---------|---------|
| **GitHub Actions** | Cloud-native CI/CD | GitHub-hosted (SaaS) | Projects hosted on GitHub; zero infrastructure to manage |
| **Jenkins** | Self-hosted automation server | Your own server/VM | Full control, on-premise requirements, complex enterprise workflows |

Both tools are configured in this project and serve complementary roles. GitHub Actions handles automated CI on every push; Jenkins provides a manual, operator-driven interface for infrastructure management and deployment.

---

## 2. Project Pipeline Overview

This project uses **three GitHub Actions workflows** and **two Jenkinsfiles**:

```
.github/workflows/
├── ci.yml                  ← Automatic: runs on every push/PR to main
├── blue-green-cd.yml       ← Manual: switches Kubernetes traffic (blue ↔ green)
└── terraform-provision.yml ← Manual: provisions or destroys AWS infrastructure

Jenkinsfile                 ← Jenkins: local Kubernetes deploy + traffic switch
aws.Jenkinsfile             ← Jenkins: full AWS pipeline (Terraform + ECR + EKS)
```

### Pipeline Trigger Summary

| Pipeline | Trigger | What It Does |
|----------|---------|-------------|
| `ci.yml` | Push or PR to `main` | Lint → Kube-lint → Docker build → (optional) EKS deploy |
| `blue-green-cd.yml` | Manual via GitHub UI | Patches EKS service selector to route traffic |
| `terraform-provision.yml` | Manual via GitHub UI | Runs `terraform apply` or `terraform destroy` |
| `Jenkinsfile` | Manual via Jenkins UI | Local: deploys blue/green or switches traffic |
| `aws.Jenkinsfile` | Manual via Jenkins UI | AWS: Terraform → ECR push → EKS deploy → traffic switch |

---

## 3. GitHub Actions — Setup & Configuration

### 3.1 How GitHub Actions Works

GitHub Actions uses **YAML workflow files** stored in `.github/workflows/`. Each workflow defines:

- **`on:`** — what event triggers the workflow (push, pull_request, manual dispatch, schedule, etc.)
- **`jobs:`** — one or more jobs that run in parallel or sequence.
- **`steps:`** — individual commands or reusable Actions within each job.

```
Repository push
      │
      ▼
GitHub detects .github/workflows/ci.yml
      │
      ▼
Spins up a fresh ubuntu-latest runner (VM)
      │
      ├── Job: lint         ─── steps: checkout → node setup → lint
      ├── Job: k8s-validate ─── steps: checkout → kube-linter
      └── Job: docker-build ─── steps: checkout → buildx → docker build
                │ (all three must pass)
                ▼
           Job: deploy-aws  ─── steps: configure AWS → terraform → deploy
```

Each job runs on its **own isolated runner** (a fresh virtual machine). Jobs can declare `needs:` dependencies to chain them sequentially.

---

### 3.2 Workflow 1 — CI Build & Lint (`ci.yml`)

**File:** [`.github/workflows/ci.yml`](.github/workflows/ci.yml)

**Triggers:** Push or Pull Request to the `main` branch touching `app/`, `k8s/`, or `scripts/`. Can also be run manually.

#### Full Annotated Workflow

```yaml
name: CI — Build & Lint Pipeline

on:
  push:
    branches: [ main ]
    paths:             # ← Only trigger when relevant files change
      - 'app/**'       #   Avoids re-running CI for README edits, etc.
      - 'k8s/**'
      - 'scripts/**'
      - '.github/workflows/ci.yml'
  pull_request:
    branches: [ main ]
    paths:
      - 'app/**'
      - 'k8s/**'
      - 'scripts/**'
      - '.github/workflows/ci.yml'
  workflow_dispatch:   # ← Allows manual trigger from the Actions tab

permissions:
  contents: read       # ← Principle of least privilege: read-only token

jobs:
  # ── Job 1: Lint Code & Shell Scripts ────────────────────────────────────────
  lint:
    name: Code Lint & Syntax Check
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'

      - name: Install Dependencies
        run: |
          cd app
          npm install

      - name: Validate JavaScript Syntax
        run: node --check app/server.js   # Fast syntax check without running the app

      - name: Lint Shell Scripts
        uses: ludeeus/action-shellcheck@2.0.0
        with:
          severity: error    # Only fail on errors, not warnings
          scandir: ./scripts

  # ── Job 2: Validate Kubernetes Manifests ────────────────────────────────────
  k8s-validate:
    name: Kubernetes Manifest Lint
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Run Kube-Linter
        uses: stackrox/kube-linter-action@v1.0.4
        with:
          directory: k8s   # Scans all YAML files under k8s/

  # ── Job 3: Verify Docker Build ───────────────────────────────────────────────
  docker-build:
    name: Docker Build Verification
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build Docker Image (Blue)
        uses: docker/build-push-action@v5
        with:
          context: ./app
          file: ./app/Dockerfile
          push: false          # ← Build only; do NOT push to any registry
          tags: devops-demo/bg-app:blue

      - name: Build Docker Image (Green)
        uses: docker/build-push-action@v5
        with:
          context: ./app
          file: ./app/Dockerfile
          push: false
          tags: devops-demo/bg-app:green

  # ── Job 4: Continuous Deployment to AWS EKS (gated by secrets) ───────────────
  deploy-aws:
    name: Continuous Deployment (AWS EKS)
    needs: [lint, k8s-validate, docker-build]  # ← Only runs if all CI jobs pass
    if: github.ref == 'refs/heads/main' && (github.event_name == 'push' || github.event_name == 'workflow_dispatch')
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
        continue-on-error: true  # ← Gracefully skip if secrets aren't configured

      - name: Check AWS Credentials & Trigger CD
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        run: |
          if [ -z "$AWS_ACCESS_KEY_ID" ]; then
            echo "⚠️  CD GATED — AWS secrets not configured. CI passed successfully."
            exit 0
          fi
          echo "🚀 Secrets detected. Deploying to AWS EKS..."
          chmod +x scripts/deploy-aws.sh
          ./scripts/deploy-aws.sh
```

#### How to Activate the CD Step

By default, the CD step runs in a **gated mode** — it prints instructions but makes no changes. To activate real deployment:

1. Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions**.
2. Click **New repository secret** and add:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
3. Push a commit to `main`. The `deploy-aws` job will now authenticate and run `scripts/deploy-aws.sh`.

---

### 3.3 Workflow 2 — Blue-Green Traffic Switch (`blue-green-cd.yml`)

**File:** [`.github/workflows/blue-green-cd.yml`](.github/workflows/blue-green-cd.yml)

**Trigger:** Manual only — `workflow_dispatch` with a dropdown input.

This workflow patches the Kubernetes service selector to atomically route all traffic to either the `blue` or `green` environment.

```yaml
name: CD — Blue-Green Traffic Switch

on:
  workflow_dispatch:
    inputs:
      target_env:
        description: 'Environment to route traffic to'
        required: true
        default: 'green'
        type: choice
        options:
          - blue
          - green

jobs:
  switch-traffic:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Install kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: 'v1.30.0'   # ← Pin exact version for reproducibility

      # Uncomment once KUBECONFIG secret is configured:
      # - name: Set up Kubeconfig
      #   env:
      #     KUBECONFIG_CONTENT: ${{ secrets.KUBECONFIG }}
      #   run: |
      #     mkdir -p $HOME/.kube
      #     echo "$KUBECONFIG_CONTENT" > $HOME/.kube/config
      #     chmod 600 $HOME/.kube/config

      - name: Switch Traffic (Patch Service Selector)
        env:
          TARGET_ENV: ${{ github.event.inputs.target_env }}
        run: |
          kubectl patch service bg-demo-service \
            -p "{\"spec\":{\"selector\":{\"app\":\"demo-app\",\"version\":\"$TARGET_ENV\"}}}"
```

#### How to Run This Workflow

1. Go to your repository → **Actions** tab.
2. Select **CD — Blue-Green Traffic Switch** in the left sidebar.
3. Click **Run workflow**.
4. Select `blue` or `green` from the dropdown.
5. Click **Run workflow** again to confirm.

#### Activating Against a Real Cluster

1. Obtain your kubeconfig: `cat ~/.kube/config` (or use `aws eks update-kubeconfig` output).
2. Add it as a repository secret named `KUBECONFIG`.
3. Uncomment the `Set up Kubeconfig` step in the workflow file.
4. Uncomment the `kubectl patch` command in the `Switch Traffic` step.

---

### 3.4 Workflow 3 — Terraform Provisioning (`terraform-provision.yml`)

**File:** [`.github/workflows/terraform-provision.yml`](.github/workflows/terraform-provision.yml)

**Trigger:** Manual only — `workflow_dispatch` with `apply` or `destroy` action input.

This workflow provisions or tears down all AWS infrastructure (EKS cluster, VPC, ECR registry) using Terraform.

```yaml
name: AWS Infrastructure — Terraform Provisioning

on:
  workflow_dispatch:
    inputs:
      action:
        description: 'Terraform Action to perform'
        required: true
        default: 'apply'
        type: choice
        options:
          - apply
          - destroy

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Set up Terraform CLI
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0

      - name: Run Terraform
        env:
          ACTION: ${{ github.event.inputs.action }}
        run: |
          cd terraform
          terraform init
          if [ "$ACTION" = "apply" ]; then
            terraform plan
            terraform apply -auto-approve
          elif [ "$ACTION" = "destroy" ]; then
            terraform destroy -auto-approve
          fi
```

> ⚠️ **Cost Warning:** Running `apply` will provision AWS resources that **incur charges** (EKS, NAT Gateway, EC2 nodes). Always run `destroy` when done testing to avoid unexpected bills.

---

### 3.5 Configuring Repository Secrets

GitHub Actions uses **encrypted repository secrets** to securely pass credentials to workflows. Secrets are never echoed in logs.

#### Steps to Add Secrets

1. Navigate to your GitHub repository.
2. Click **Settings** (gear icon in the top navigation).
3. In the left sidebar, expand **Secrets and variables** → click **Actions**.
4. Click **New repository secret**.
5. Enter the name and value, then click **Add secret**.

#### Secrets Required by This Project

| Secret Name | Where Used | How to Get It |
|-------------|-----------|---------------|
| `AWS_ACCESS_KEY_ID` | `ci.yml`, `terraform-provision.yml` | AWS Console → IAM → Users → Security credentials → Create access key |
| `AWS_SECRET_ACCESS_KEY` | `ci.yml`, `terraform-provision.yml` | Same as above (shown only once at creation time) |
| `KUBECONFIG` | `blue-green-cd.yml` | `cat ~/.kube/config` after `aws eks update-kubeconfig` |

> 🔒 **Security tip:** Use dedicated IAM users with minimal permissions for CI/CD. Never use your root AWS account keys.

---

### 3.6 Tips for Common Use Cases

#### Viewing Workflow Run Logs

1. Go to your repository → **Actions** tab.
2. Click on a workflow run name.
3. Click on any job to expand its steps and view real-time or historical logs.
4. Red ❌ = failed step. Click it to see the error output.

#### Re-running a Failed Workflow

- On a failed run page, click **Re-run all jobs** or **Re-run failed jobs**.
- Useful when a failure was caused by a transient network issue, not a code bug.

#### Adding Notifications (Slack / Email)

Add this step at the end of any job:

```yaml
- name: Notify Slack on Failure
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: failure
    webhook_url: ${{ secrets.SLACK_WEBHOOK_URL }}
```

#### Caching Dependencies for Faster Runs

```yaml
- name: Cache Node.js modules
  uses: actions/cache@v4
  with:
    path: app/node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('app/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-
```

#### Using Path Filters to Avoid Unnecessary Runs

```yaml
on:
  push:
    paths:
      - 'app/**'     # Only trigger CI when app code changes
      - '!**/*.md'   # Never trigger for markdown-only changes
```

#### Environment-Specific Deployments

```yaml
jobs:
  deploy-staging:
    environment: staging        # Links to a GitHub Environment with its own secrets
    runs-on: ubuntu-latest
    steps:
      - run: ./scripts/deploy-aws.sh
        env:
          AWS_REGION: ${{ vars.AWS_REGION }}
```

---

## 4. Jenkins — Setup & Configuration

### 4.1 How Jenkins Works

Jenkins is a self-hosted automation server. Unlike GitHub Actions (which runs on GitHub's cloud), Jenkins runs **on your own machine or server**. You define pipelines using a **`Jenkinsfile`** — a Groovy-based DSL checked into your repository.

```
Developer pushes code
        │
        ▼
Jenkins polls SCM (or receives webhook)
        │
        ▼
Reads Jenkinsfile from repo
        │
        ▼
Executes stages on the Jenkins agent
  ┌───────────────────────────────┐
  │ stage('Checkout')             │
  │ stage('Initial Deployment')   │
  │ stage('Switch Traffic')       │
  └───────────────────────────────┘
        │
        ▼
post { success { ... } failure { ... } }
```

A **Jenkinsfile** is a declarative or scripted pipeline definition. This project uses **Declarative Pipeline** syntax (the `pipeline { }` block), which is the modern, recommended approach.

---

### 4.2 Installing Jenkins

#### Option A — Docker (Recommended for Local Testing)

```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts-jdk17
```

Then open `http://localhost:8080` and follow the setup wizard.

#### Option B — Native Installation (Ubuntu/Debian)

```bash
# Add Jenkins apt repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update
sudo apt-get install jenkins

# Start the service
sudo systemctl enable jenkins
sudo systemctl start jenkins
```

Retrieve the initial admin password:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

#### Required Plugins

Install these during the setup wizard or via **Manage Jenkins → Plugins**:

| Plugin | Purpose |
|--------|---------|
| **Pipeline** | Jenkinsfile support |
| **Git** | Checkout from GitHub/GitLab |
| **Credentials Binding** | Inject secrets into pipeline steps |
| **Blue Ocean** (optional) | Modern pipeline visualization UI |

---

### 4.3 Pipeline 1 — Local Deploy (`Jenkinsfile`)

**File:** [`Jenkinsfile`](Jenkinsfile)

This pipeline targets a **local Kubernetes cluster** (Kind, Minikube, Docker Desktop). It provides two parameterized actions.

#### Annotated Jenkinsfile

```groovy
pipeline {
    agent any   // Run on any available Jenkins agent

    parameters {
        // Dropdown shown to the operator before each build
        choice(
            name: 'ACTION',
            choices: ['Deploy', 'Switch Traffic'],
            description: 'Action to perform'
        )
        choice(
            name: 'TARGET_ENV',
            choices: ['blue', 'green'],
            description: 'Environment to switch traffic to (only used with Switch Traffic)'
        )
    }

    stages {
        // ── Stage 1: Always runs first ──────────────────────────────────────
        stage('Checkout') {
            steps {
                checkout scm   // Checks out the branch that triggered this build
            }
        }

        // ── Stage 2: Conditional — only when ACTION = Deploy ────────────────
        stage('Initial Deployment') {
            when {
                expression { params.ACTION == 'Deploy' }
            }
            steps {
                echo "Running initial deployment..."
                sh 'chmod +x scripts/deploy.sh'
                sh './scripts/deploy.sh'
            }
        }

        // ── Stage 3: Conditional — only when ACTION = Switch Traffic ─────────
        stage('Switch Traffic') {
            when {
                expression { params.ACTION == 'Switch Traffic' }
            }
            steps {
                echo "Switching traffic to ${params.TARGET_ENV}..."
                sh 'chmod +x scripts/switch-traffic.sh'
                sh "./scripts/switch-traffic.sh ${params.TARGET_ENV}"
            }
        }
    }

    // ── Post-build actions — always run ──────────────────────────────────────
    post {
        success {
            echo "Pipeline completed successfully: ACTION=${params.ACTION}"
        }
        failure {
            echo "Pipeline FAILED: ACTION=${params.ACTION}. Check the logs above."
        }
    }
}
```

#### Key Concepts

- **`parameters { }`** — Defines build parameters. The operator selects values in the Jenkins UI before triggering a build. The first build runs without parameters (defaults applied); subsequent builds show the UI.
- **`when { expression { ... } }`** — Makes stages conditional. Avoids running irrelevant logic based on operator input.
- **`post { success/failure { } }`** — Always executes after all stages. Ideal for notifications or cleanup.
- **`sh`** — Runs a shell command on the agent. The agent must have `kubectl`, `docker`, and bash available.

---

### 4.4 Pipeline 2 — AWS Full Stack (`aws.Jenkinsfile`)

**File:** [`aws.Jenkinsfile`](aws.Jenkinsfile)

This pipeline orchestrates the **entire AWS lifecycle**: provisioning infrastructure, deploying the app to EKS, switching traffic, and tearing everything down — all from Jenkins.

#### Annotated aws.Jenkinsfile

```groovy
pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = "us-east-1"
        // credentials() retrieves secrets from Jenkins Credential Store.
        // Never hardcode AWS keys in a Jenkinsfile.
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['Terraform Apply', 'Deploy AWS App', 'Switch Traffic', 'Terraform Destroy'],
            description: 'Action to perform'
        )
        choice(
            name: 'TARGET_ENV',
            choices: ['blue', 'green'],
            description: 'Traffic target (only used with Switch Traffic)'
        )
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        // ── Provision AWS infrastructure ─────────────────────────────────────
        stage('Terraform Apply') {
            when { expression { params.ACTION == 'Terraform Apply' } }
            steps {
                dir('terraform') {   // Changes working directory to terraform/
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        // ── Build, push to ECR, deploy to EKS ────────────────────────────────
        stage('Deploy App to AWS') {
            when { expression { params.ACTION == 'Deploy AWS App' } }
            steps {
                echo "Running AWS deployment..."
                sh 'chmod +x scripts/deploy-aws.sh'
                sh './scripts/deploy-aws.sh'
            }
        }

        // ── Route Kubernetes traffic ──────────────────────────────────────────
        stage('Switch Traffic') {
            when { expression { params.ACTION == 'Switch Traffic' } }
            steps {
                echo "Switching AWS cluster traffic to ${params.TARGET_ENV}..."
                sh 'chmod +x scripts/switch-traffic.sh'
                sh "./scripts/switch-traffic.sh ${params.TARGET_ENV}"
            }
        }

        // ── Human approval gate before destroying ────────────────────────────
        stage('Confirm Destroy') {
            when { expression { params.ACTION == 'Terraform Destroy' } }
            steps {
                // Blocks the pipeline and waits for a human to click "Yes"
                input message: 'WARNING: This will destroy ALL AWS infrastructure (EKS, VPC, ECR). Are you sure?',
                      ok: 'Yes, destroy everything'
            }
        }

        stage('Terraform Destroy') {
            when { expression { params.ACTION == 'Terraform Destroy' } }
            steps {
                dir('terraform') {
                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }

    post {
        success { echo "Pipeline completed successfully: ACTION=${params.ACTION}" }
        failure  { echo "Pipeline FAILED: ACTION=${params.ACTION}. Check the logs." }
    }
}
```

#### Key Concepts Unique to `aws.Jenkinsfile`

- **`environment { credentials() }`** — Pulls secrets from Jenkins Credential Store and injects them as environment variables. The secret values are masked in console output.
- **`dir('terraform') { }`** — Changes the working directory for the steps inside the block. Equivalent to `cd terraform && ...`.
- **`input`** — Pauses the pipeline and shows a confirmation dialog in the Jenkins UI. This is a critical safety gate before destructive operations. The pipeline times out and fails if no one responds within the timeout period (default: indefinitely).

---

### 4.5 Configuring Jenkins Credentials

Never store AWS keys or passwords in the Jenkinsfile. Use Jenkins' built-in Credential Store instead.

#### Adding AWS Credentials

1. Go to **Manage Jenkins** → **Credentials** → **System** → **Global credentials (unrestricted)**.
2. Click **Add Credentials**.
3. Set **Kind** to `Secret text`.
4. Enter your AWS Access Key ID as the **Secret**.
5. Set **ID** to `aws-access-key-id` (must match exactly what's in `aws.Jenkinsfile`).
6. Click **Create**.
7. Repeat for `aws-secret-access-key`.

#### Credential Types Reference

| Kind | Use Case |
|------|---------|
| `Secret text` | API keys, tokens (AWS keys, Docker tokens) |
| `Username with password` | Basic auth, Docker Hub login |
| `SSH Username with private key` | Git over SSH, server access |
| `Secret file` | kubeconfig files, certificates |

---

### 4.6 Creating a Jenkins Pipeline Job

#### For `Jenkinsfile` (Local Pipeline)

1. Click **New Item** on the Jenkins dashboard.
2. Enter a name (e.g., `blue-green-local`).
3. Select **Pipeline** and click **OK**.
4. Scroll to the **Pipeline** section.
5. Set **Definition** to `Pipeline script from SCM`.
6. Set **SCM** to `Git`.
7. Enter your repository URL.
8. Set **Script Path** to `Jenkinsfile`.
9. Click **Save**.

#### For `aws.Jenkinsfile` (AWS Pipeline)

Follow the same steps but set **Script Path** to `aws.Jenkinsfile`.

#### Running a Parameterized Build

1. Go to your pipeline job.
2. Click **Build with Parameters**.
3. Select the desired `ACTION` and `TARGET_ENV` from the dropdowns.
4. Click **Build**.

> **Note:** The **Build with Parameters** option only appears after the first build (which uses default values). Run the job once to initialize it.

---

## 5. Best Practices

### 5.1 Secret Management

- ✅ **Always** use GitHub Secrets or Jenkins Credential Store — never hardcode credentials in YAML or Jenkinsfiles.
- ✅ Rotate credentials regularly. IAM access keys should be rotated every 90 days.
- ✅ Use **IAM roles** (not access keys) when running Jenkins on EC2. The agent inherits permissions automatically.
- ✅ Limit IAM permissions to exactly what each pipeline needs (principle of least privilege).
- ❌ Never `echo` or `print` secret values in pipeline steps — they will appear in logs.

### 5.2 Pipeline Design

- **Keep pipelines fast.** Use path filters in GitHub Actions (`paths:`) to skip CI when irrelevant files change (e.g., README updates).
- **Fail fast.** Put quick checks (lint, syntax) early in the pipeline, and slow checks (Docker build, tests) later.
- **Pin action and tool versions.** Use `actions/checkout@v4` not `@main`. Use `terraform_version: 1.7.0` not `latest`. This prevents unexpected breaking changes.
- **Use `needs:` in GitHub Actions** to enforce job ordering and prevent deploying broken code.
- **Use `when:` in Jenkins** to make stages conditional. Avoid separate Jenkinsfiles for minor variations.

### 5.3 Infrastructure Operations

- **Manual gates for destructive actions.** Always use `workflow_dispatch` (not push triggers) for `terraform destroy` and other irreversible operations.
- **Use the Jenkins `input` step** before any action that destroys data or infrastructure.
- **Enable remote Terraform state** (S3 + DynamoDB) so that `terraform apply` run from GitHub Actions and from Jenkins both read and write the same state file. See [`terraform/bootstrap-backend/`](terraform/bootstrap-backend/).
- **Tag resources.** Add `Environment`, `Project`, and `ManagedBy` tags to all Terraform resources for cost tracking and cleanup.

### 5.4 Observability

- **Add status notifications.** Configure Slack, Teams, or email notifications for pipeline failures.
- **Use GitHub Actions environments** for approvals and environment-specific secrets (Settings → Environments).
- **Review Blue Ocean** in Jenkins for a visual representation of pipeline stages and time spent per stage.
- **Archive artifacts.** In Jenkins, use `archiveArtifacts` to save Docker build logs or test reports.

  ```groovy
  post {
      always {
          archiveArtifacts artifacts: 'logs/*.log', allowEmptyArchive: true
      }
  }
  ```

### 5.5 Blue-Green Specific

- **Test the idle environment** before switching traffic. Use `kubectl port-forward` or a separate internal service to verify the green pods are healthy.
- **Keep both deployments running.** Don't scale down the idle environment immediately after switching — you need it for instant rollback.
- **Monitor post-switch.** Watch error rates and latency for 5–10 minutes after a traffic switch before considering the deployment done.

---

## 6. Troubleshooting

### GitHub Actions Issues

#### Workflow not triggering on push

- **Check the `on:` trigger.** Ensure your push is to the correct branch (`main` in this project).
- **Check `paths:` filters.** If you only changed a file not matched by any `paths:` pattern, the workflow won't run.
- **Verify the YAML is valid.** Use [yaml.lint.com](https://www.yamllint.com/) or run `yamllint .github/workflows/ci.yml`.

#### "Context access might be invalid" warning

This is a known GitHub Actions lint warning for dynamic `if:` expressions. It's typically safe to ignore unless the pipeline actually fails.

#### CD step shows "⚠️ CD GATED" message

This is expected behavior when `AWS_ACCESS_KEY_ID` is not configured as a repository secret. Follow the instructions printed in the log output.

#### `aws-actions/configure-aws-credentials` fails

```
Error: Credentials could not be loaded
```

- Verify the secret names in GitHub match exactly: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
- Check that the IAM user has not been disabled or the access key has not been deleted.
- Confirm the IAM user has the required permissions (`ec2`, `eks`, `ecr`, `iam`, `s3`, `dynamodb`).

#### Docker build fails with "No space left on device"

GitHub-hosted runners have ~14 GB of disk. Large builds can exhaust this. Free space between jobs:

```yaml
- name: Free disk space
  run: docker system prune -af
```

#### `kube-linter` fails on manifests

Kube-linter enforces Kubernetes security best practices. Common failures:
- Missing CPU/memory `resources.limits` → add `resources.limits` to deployment specs.
- Missing `readinessProbe` → add health check probes.
- Running as root → add `securityContext.runAsNonRoot: true`.

---

### Jenkins Issues

#### "Build with Parameters" option missing

The first build of a parameterized pipeline runs with default values without showing the parameter UI. After the first build completes, the **Build with Parameters** option appears. This is a known Jenkins behavior.

#### `sh` step fails with "Permission denied"

```
chmod +x scripts/deploy.sh
```

Ensure the script files have the executable bit set. Alternatively, set it explicitly in the Jenkinsfile (as this project does):

```groovy
sh 'chmod +x scripts/deploy.sh'
sh './scripts/deploy.sh'
```

#### `credentials()` returns empty value

- Verify the Credential **ID** in Jenkins matches exactly the string used in `credentials('aws-access-key-id')`.
- Credential IDs are case-sensitive.
- Go to **Manage Jenkins → Credentials** to verify the credential exists.

#### Terraform not found on Jenkins agent

The Jenkins agent needs Terraform installed. Options:
1. **Install on the agent machine:** Download from [terraform.io](https://developer.hashicorp.com/terraform/install) and add to `$PATH`.
2. **Use a Docker agent with Terraform pre-installed:**
   ```groovy
   agent {
       docker { image 'hashicorp/terraform:1.7' }
   }
   ```

#### `terraform init` fails with S3 backend errors

```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

The remote backend S3 bucket must be created before running `terraform init` with the S3 backend configured. Run the bootstrap:

```bash
cd terraform/bootstrap-backend
terraform init
terraform apply -auto-approve
```

Then update [`terraform/provider.tf`](terraform/provider.tf) with the output bucket name and re-run.

#### `input` step times out and pipeline fails

The `input` step in `aws.Jenkinsfile` waits indefinitely for a human response. If the pipeline is abandoned, Jenkins may mark it as failed after a configurable timeout. Set a timeout with:

```groovy
stage('Confirm Destroy') {
    steps {
        timeout(time: 15, unit: 'MINUTES') {
            input message: 'Destroy all infrastructure?', ok: 'Yes'
        }
    }
}
```

#### Docker commands fail on Jenkins agent

Ensure the Jenkins user is in the `docker` group on the agent machine:

```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

---

## 7. Conclusion & Next Steps

### Summary

You now have a complete picture of how CI/CD is implemented in this Blue-Green Deployment project:

| What | How |
|------|-----|
| Every code push is automatically validated | `ci.yml` — lint, kube-linter, Docker build |
| CD to EKS is gated behind AWS secrets | `ci.yml` deploy-aws job |
| Traffic can be switched with one click | `blue-green-cd.yml` workflow dispatch |
| Infrastructure is provisioned/destroyed safely | `terraform-provision.yml` + manual `input` gate |
| Local environments are managed by Jenkins | `Jenkinsfile` with parameterized actions |
| Full AWS lifecycle is orchestrated by Jenkins | `aws.Jenkinsfile` with 4 parameterized stages |

CI/CD is not just tooling — it's a **discipline**. The pipelines in this project encode operational knowledge: what to check before deploying, how to safely switch traffic, and how to protect against accidental destruction. Reading and understanding a Jenkinsfile or a GitHub Actions workflow is just as important as understanding the application code itself.

### Recommended Next Steps

1. **Activate the CI/CD pipeline end-to-end.** Add your AWS credentials as GitHub Secrets and trigger a real deployment from `ci.yml`.

2. **Add automated tests.** Currently the pipeline validates syntax and builds Docker images. Add unit tests (`npm test`) and integration tests to the CI pipeline.

3. **Explore GitHub Environments.** Configure `staging` and `production` environments with different secrets and required reviewers for deployment approvals.

4. **Set up Jenkins webhooks.** Instead of polling SCM, configure GitHub to send webhook events to Jenkins for instant pipeline triggers.

5. **Implement GitOps with ArgoCD.** Replace the `kubectl` commands in the CD pipeline with ArgoCD for declarative, git-driven deployment management.

6. **Add monitoring.** Integrate Prometheus and Grafana to observe deployment health metrics after each traffic switch.

7. **Explore other CI/CD tools.** GitLab CI/CD, CircleCI, and Tekton are all worth exploring. The concepts — stages, jobs, secrets, conditions — transfer directly.

---

## 📚 Related Documentation

| Document | Type | Priority | Description |
| :--- | :--- | :--- | :--- |
| 📄 **[README.md](README.md)** | Core Overview | **Critical** | Main project entry point, local quick start, and architectural overview. |
| 📄 **[AWS-SETUP.md](AWS-SETUP.md)** | Infrastructure | **High** | Step-by-step instructions for provisioning EKS/ECR/VPC via Terraform. |
| 📄 **[CICD-GUIDE.md](CICD-GUIDE.md)** | CI/CD Reference | **High** | Detailed setups, YAML/Jenkinsfile configuration, and troubleshooting for GitHub Actions & Jenkins. |

> 💡 **Tip:** To master CI/CD faster, break something intentionally. Introduce a syntax error in `app/server.js`, push it, and watch the CI pipeline catch it in seconds. That immediate feedback loop is exactly what CI/CD is built for.

