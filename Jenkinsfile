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
                sh 'docker-compose build'
            }
        }
        stage('Restart App') {
            steps {
                sh 'docker-compose down --volumes --remove-orphans'
                sh 'docker-compose build --no-cache'
                sh 'docker-compose up -d'
    }
}
    post {
        failure {
            echo 'Build failed.'
        }
    }
}

