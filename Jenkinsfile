pipeline {
    agent any

    environment {
        COMPOSE_CMD = 'docker-compose'
    }

    stages {
        stage('Clone Repository') {
            steps {
                git 'https://github.com/akshatsri47/Chess.git'
            }
        }

        stage('Build with Docker Compose') {
            steps {
                script {
                    sh "sudo ${COMPOSE_CMD} build"
                }
            }
        }

        stage('Run with Docker Compose') {
            steps {
                script {
                    sh "sudo ${COMPOSE_CMD} up -d"
                }
            }
        }
    }

    post {
        success {
            echo 'Chess app built and running successfully!'
        }
        failure {
            echo 'Something went wrong. Check logs.'
        }
    }
}

