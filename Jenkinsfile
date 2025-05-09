pipeline {
    agent any

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Build') {
            steps {
                sh 'sudo docker-compose build'
            }
        }
        stage('Restart App') {
            steps {
                sh 'sudo docker-compose up -d'
            }
        }
    }

    post {
        failure {
            echo 'Build failed.'
        }
    }
}

