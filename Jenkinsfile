pipeline {
    agent any

    parameters {
        choice(name: 'ACTION', choices: ['Deploy', 'Switch Traffic'], description: 'Action to perform')
        choice(name: 'TARGET_ENV', choices: ['blue', 'green'], description: 'Environment to switch traffic to (only used when ACTION is Switch Traffic)')
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
                sh 'chmod +x scripts/deploy-local.sh'
                sh './scripts/deploy-local.sh'
            }
        }

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

    post {
        success {
            echo "Pipeline completed successfully: ACTION=${params.ACTION}"
        }
        failure {
            echo "Pipeline FAILED: ACTION=${params.ACTION}. Check the logs above for details."
        }
    }
}
