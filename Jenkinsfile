pipeline {
    agent any

    parameters {
        choice(name: 'ACTION', choices: ['Deploy', 'Switch Traffic'], description: 'Action to perform')
        choice(name: 'TARGET_ENV', choices: ['blue', 'green'], description: 'Environment to switch traffic to (only used if ACTION is Switch Traffic)')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Initial Deployment') {
            when {
                expression { params.ACTION == 'Deploy' }
            }
            steps {
                echo "Running initial deployment..."
                // Ensure scripts are executable
                sh "chmod +x scripts/deploy.sh"
                sh "./scripts/deploy.sh"
            }
        }

        stage('Switch Traffic') {
            when {
                expression { params.ACTION == 'Switch Traffic' }
            }
            steps {
                echo "Switching traffic to ${params.TARGET_ENV}..."
                sh "chmod +x scripts/switch-traffic.sh"
                sh "./scripts/switch-traffic.sh ${params.TARGET_ENV}"
            }
        }
    }
}
