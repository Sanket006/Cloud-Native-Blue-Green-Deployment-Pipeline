pipeline {
    // Run on any available Jenkins agent/runner
    agent any

    // Define environmental configuration used globally in this pipeline
    environment {
        // Specify default AWS Region where EKS, VPC, and ECR will be managed
        AWS_DEFAULT_REGION = "us-east-1"
        
        // AWS Authentication keys pulled securely from the Jenkins Credential Store
        // Set these up in Jenkins UI under: Manage Jenkins → Credentials
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
    }

    // Define build inputs shown to the operator before triggering the run
    parameters {
        // ACTION selector: choose which infrastructure or deployment stage to execute
        choice(
            name: 'ACTION', 
            choices: ['Terraform Apply', 'Deploy AWS App', 'Switch Traffic', 'Terraform Destroy'], 
            description: 'Action to perform'
        )
        // TARGET_ENV selector: specifies which deployment environment to route traffic to (used with Switch Traffic action)
        choice(
            name: 'TARGET_ENV', 
            choices: ['blue', 'green'], 
            description: 'Environment to switch traffic to (only used when ACTION is Switch Traffic)'
        )
    }

    stages {
        // --- STAGE 1: Checkout ---
        // Downloads the source code from the configured repository branch
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // --- STAGE 2: Terraform Apply ---
        // Provisions full AWS infrastructure (VPC, ECR, EKS) using Terraform when selected
        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'Terraform Apply' }
            }
            steps {
                echo "🚀 Initialising and applying Terraform configurations in AWS..."
                dir('terraform') {
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        // --- STAGE 3: Deploy AWS App ---
        // Builds application image, pushes to ECR, and deploys pods to EKS when selected
        stage('Deploy App to AWS') {
            when {
                expression { params.ACTION == 'Deploy AWS App' }
            }
            steps {
                echo "🚀 Building Docker image, pushing to ECR, and deploying to EKS..."
                sh 'chmod +x scripts/deploy-aws.sh'
                sh './scripts/deploy-aws.sh'
            }
        }

        // --- STAGE 4: Switch Traffic ---
        // Configures local EKS connection context and runs the traffic switcher script when selected
        stage('Switch Traffic') {
            when {
                expression { params.ACTION == 'Switch Traffic' }
            }
            steps {
                echo "🔄 Switching AWS cluster traffic routing to: ${params.TARGET_ENV}..."
                
                // Fetch the EKS Cluster Name dynamically from Terraform outputs and update kubeconfig context
                dir('terraform') {
                    sh 'terraform init'
                }
                script {
                    def clusterName = sh(script: "cd terraform && terraform output -raw cluster_name", returnStdout: true).trim()
                    sh "aws eks update-kubeconfig --region ${env.AWS_DEFAULT_REGION} --name ${clusterName}"
                }
                
                sh 'chmod +x scripts/switch-traffic.sh'
                sh "./scripts/switch-traffic.sh ${params.TARGET_ENV}"
            }
        }

        // --- STAGE 5: Teardown Confirmation Gate ---
        // Pauses pipeline and prompts for manual approval before executing destructive actions
        stage('Confirm Destroy') {
            when {
                expression { params.ACTION == 'Terraform Destroy' }
            }
            steps {
                input message: '⚠️ WARNING: This will destroy ALL AWS infrastructure (EKS, VPC, ECR). Are you sure?',
                      ok: 'Yes, destroy everything'
            }
        }

        // --- STAGE 6: Terraform Teardown ---
        // Destroys all provisioned AWS resources to prevent unexpected billing charges when selected
        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'Terraform Destroy' }
            }
            steps {
                echo "🔥 Initiating AWS infrastructure teardown..."
                dir('terraform') {
                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }

    // Post-build actions execution
    post {
        success {
            echo "✅ Pipeline completed successfully: ACTION=${params.ACTION}"
        }
        failure {
            echo "❌ Pipeline FAILED: ACTION=${params.ACTION}. Check the logs above for details."
        }
    }
}
