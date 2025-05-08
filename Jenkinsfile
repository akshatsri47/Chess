pipeline {
    agent any

    tools {
        nodejs "NodeJS 18" // Add this version via Jenkins > Global Tool Configuration
    }

    environment {
        DOCKER_BUILDKIT = '1'
    }

    stages {
        stage('Clone Repository') {
            steps {
                git 'https://github.com/akshatsri47/Chess.git'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm install --prefix client'
                sh 'npm install --prefix server'
            }
        }

        stage('Lint & Build') {
            steps {
                sh 'npm run build --prefix client'
            }
        }

        stage('Run Tests') {
            steps {
                // Add your test commands if any
                echo 'No tests configured yet'
            }
        }

        stage('Docker Build') {
            steps {
                sh 'docker build -t chess-app .'
            }
        }

        stage('Deploy (Optional)') {
            steps {
                echo 'Add deployment steps here if needed (e.g., to AWS, EC2, etc.)'
            }
        }
    }
}

