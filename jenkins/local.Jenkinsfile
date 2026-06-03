pipeline {
    // Run on any available Jenkins agent/runner
    agent any

    // Define build inputs shown to the operator before triggering the run
    parameters {
        // ACTION selector: choose between deploying the sandbox or switching routing traffic
        choice(
            name: 'ACTION', 
            choices: ['Deploy', 'Switch Traffic'], 
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

        // --- STAGE 2: Initial Deployment ---
        // Runs local blue-green deployment setup (Kind or Minikube) when Deploy action is selected
        stage('Initial Deployment') {
            when {
                expression { params.ACTION == 'Deploy' }
            }
            steps {
                echo "🚀 Initialising local blue-green deployment environment..."
                sh 'chmod +x scripts/deploy-local.sh'
                sh './scripts/deploy-local.sh'
            }
        }

        // --- STAGE 3: Switch Traffic ---
        // Patches the local Kubernetes service selector to route user traffic when Switch Traffic action is selected
        stage('Switch Traffic') {
            when {
                expression { params.ACTION == 'Switch Traffic' }
            }
            steps {
                echo "🔄 Switching local routing traffic to: ${params.TARGET_ENV}..."
                sh 'chmod +x scripts/switch-traffic.sh'
                sh "./scripts/switch-traffic.sh ${params.TARGET_ENV}"
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
