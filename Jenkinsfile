pipeline {
    agent any

    environment {
        COMPOSE_CMD = 'docker-compose'
        TF_DIR = 'terraform'
        AWS_REGION = 'us-east-1' // change to your region
    }

    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/akshatsri47/Chess.git'
            }
        }

        stage('Docker Build') {
            steps {
                sh "${COMPOSE_CMD} build"
            }
        }

        stage('Terraform Init & Apply') {
            environment {
                AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
                AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
            }
            steps {
                dir("${TF_DIR}") {
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }

    post {
        success {
            echo 'Deployment complete.'
        }
        failure {
            echo 'Deployment failed.'
        }
    }
}

