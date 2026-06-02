pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = "us-east-1"
        // Credentials are pulled from the Jenkins credential store (not hardcoded).
        // Set these up at: Manage Jenkins → Credentials → Global → Add Credentials (Secret text).
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
    }

    parameters {
        choice(name: 'ACTION', choices: ['Terraform Apply', 'Deploy AWS App', 'Switch Traffic', 'Terraform Destroy'], description: 'Action to perform')
        choice(name: 'TARGET_ENV', choices: ['blue', 'green'], description: 'Environment to switch traffic to (only used when ACTION is Switch Traffic)')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'Terraform Apply' }
            }
            steps {
                dir('terraform') {
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        stage('Deploy App to AWS') {
            when {
                expression { params.ACTION == 'Deploy AWS App' }
            }
            steps {
                echo "Running AWS deployment..."
                sh 'chmod +x scripts/deploy-aws.sh'
                sh './scripts/deploy-aws.sh'
            }
        }

        stage('Switch Traffic') {
            when {
                expression { params.ACTION == 'Switch Traffic' }
            }
            steps {
                echo "Switching AWS cluster traffic to ${params.TARGET_ENV}..."
                // Assumes kubeconfig is already configured from the Deploy App stage.
                // If running independently, re-run 'aws eks update-kubeconfig' first.
                sh 'chmod +x scripts/switch-traffic.sh'
                sh "./scripts/switch-traffic.sh ${params.TARGET_ENV}"
            }
        }

        // Requires manual human approval before destroying infrastructure.
        // This prevents accidental teardown from a misclick.
        stage('Confirm Destroy') {
            when {
                expression { params.ACTION == 'Terraform Destroy' }
            }
            steps {
                input message: 'WARNING: This will destroy ALL AWS infrastructure (EKS, VPC, ECR). Are you sure?',
                      ok: 'Yes, destroy everything'
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'Terraform Destroy' }
            }
            steps {
                dir('terraform') {
                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully: ACTION=${params.ACTION}"
        }
        failure {
            echo "Pipeline FAILED: ACTION=${params.ACTION}. Check the logs above for details."
        }
    }
}
