pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Build') {
            steps {
                sh 'docker-compose build'
            }
        }
        stage('Terraform') {
            steps {
                sh 'terraform init && terraform apply -auto-approve'
            }
        }
    }
    post {
        failure {
            echo 'Deployment failed.'
        }
    }
}

