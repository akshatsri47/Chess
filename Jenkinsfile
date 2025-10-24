pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TF_VAR_region = 'us-east-1'
        TF_VAR_aws_access_key = credentials('aws-access-key')
        TF_VAR_aws_secret_key = credentials('aws-secret-key')
        WEBSOCKET_URL = 'ws://${INSTANCE_IP}:8181'
    }

    parameters {
        choice(
            name: 'DEPLOYMENT_TYPE',
            choices: ['infrastructure-only', 'application-only', 'full-deployment'],
            description: 'Choose deployment type'
        )
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Choose environment'
        )
        booleanParam(
            name: 'DESTROY_INFRASTRUCTURE',
            defaultValue: false,
            description: 'Destroy infrastructure (use with caution)'
        )
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Setup Tools') {
            steps {
                script {
                    // Install Terraform if not present
                    sh '''
                        if ! command -v terraform &> /dev/null; then
                            echo "Installing Terraform..."
                            wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
                            unzip terraform_1.6.0_linux_amd64.zip
                            sudo mv terraform /usr/local/bin/
                            rm terraform_1.6.0_linux_amd64.zip
                        fi
                        
                        # Install AWS CLI if not present
                        if ! command -v aws &> /dev/null; then
                            echo "Installing AWS CLI..."
                            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                            unzip awscliv2.zip
                            sudo ./aws/install
                            rm -rf aws awscliv2.zip
                        fi
                    '''
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    if (params.DEPLOYMENT_TYPE == 'infrastructure-only' || params.DEPLOYMENT_TYPE == 'full-deployment') {
                        dir('terraform') {
                            if (params.DESTROY_INFRASTRUCTURE) {
                                sh '''
                                    terraform init
                                    terraform plan -destroy -var="environment=${ENVIRONMENT}" -out=destroy.tfplan
                                '''
                            } else {
                                sh '''
                                    terraform init
                                    terraform plan -var="environment=${ENVIRONMENT}" -out=tfplan
                                '''
                            }
                        }
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                script {
                    if (params.DEPLOYMENT_TYPE == 'infrastructure-only' || params.DEPLOYMENT_TYPE == 'full-deployment') {
                        dir('terraform') {
                            if (params.DESTROY_INFRASTRUCTURE) {
                                sh '''
                                    terraform apply -auto-approve destroy.tfplan
                                '''
                            } else {
                                sh '''
                                    terraform apply -auto-approve tfplan
                                    
                                    # Get instance IP and set environment variable
                                    INSTANCE_IP=$(terraform output -raw instance_ip)
                                    echo "INSTANCE_IP=${INSTANCE_IP}" > ../.env
                                    echo "Instance IP: ${INSTANCE_IP}"
                                '''
                            }
                        }
                    }
                }
            }
        }

        stage('Wait for Instance') {
            steps {
                script {
                    if ((params.DEPLOYMENT_TYPE == 'infrastructure-only' || params.DEPLOYMENT_TYPE == 'full-deployment') && !params.DESTROY_INFRASTRUCTURE) {
                        // Load instance IP from terraform output
                        def instanceIp = sh(
                            script: 'cd terraform && terraform output -raw instance_ip',
                            returnStdout: true
                        ).trim()
                        
                        env.INSTANCE_IP = instanceIp
                        echo "Waiting for instance ${instanceIp} to be ready..."
                        
                        // Wait for instance to be ready
                        sh '''
                            timeout 300 bash -c 'until curl -f http://'${INSTANCE_IP}':5173 > /dev/null 2>&1; do
                                echo "Waiting for application to start..."
                                sleep 10
                            done'
                        '''
                    }
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                script {
                    if ((params.DEPLOYMENT_TYPE == 'application-only' || params.DEPLOYMENT_TYPE == 'full-deployment') && !params.DESTROY_INFRASTRUCTURE) {
                        // Build and tag images with commit hash
                        sh '''
                            docker-compose build --no-cache
                            docker tag chess_frontend:latest chess_frontend:${GIT_COMMIT_SHORT}
                            docker tag chess_backend:latest chess_backend:${GIT_COMMIT_SHORT}
                        '''
                    }
                }
            }
        }

        stage('Deploy Application') {
            steps {
                script {
                    if ((params.DEPLOYMENT_TYPE == 'application-only' || params.DEPLOYMENT_TYPE == 'full-deployment') && !params.DESTROY_INFRASTRUCTURE) {
                        // Load instance IP
                        def instanceIp = sh(
                            script: 'cd terraform && terraform output -raw instance_ip',
                            returnStdout: true
                        ).trim()
                        
                        // Deploy to remote instance
                        sh '''
                            # Copy docker-compose and .env to instance
                            scp -o StrictHostKeyChecking=no docker-compose.yml ubuntu@${INSTANCE_IP}:/home/ubuntu/
                            scp -o StrictHostKeyChecking=no .env ubuntu@${INSTANCE_IP}:/home/ubuntu/ 2>/dev/null || true
                            
                            # Deploy application on remote instance
                            ssh -o StrictHostKeyChecking=no ubuntu@${INSTANCE_IP} '
                                cd /home/ubuntu
                                export WEBSOCKET_URL=ws://'${INSTANCE_IP}':8181
                                sudo docker-compose down || true
                                sudo docker-compose pull || true
                                sudo docker-compose up -d
                            '
                        '''
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    if ((params.DEPLOYMENT_TYPE == 'application-only' || params.DEPLOYMENT_TYPE == 'full-deployment') && !params.DESTROY_INFRASTRUCTURE) {
                        def instanceIp = sh(
                            script: 'cd terraform && terraform output -raw instance_ip',
                            returnStdout: true
                        ).trim()
                        
                        sh '''
                            echo "Performing health checks..."
                            
                            # Check frontend
                            curl -f http://${INSTANCE_IP}:5173 || exit 1
                            echo "Frontend is healthy"
                            
                            # Check backend WebSocket
                            timeout 10 bash -c 'until nc -z ${INSTANCE_IP} 8181; do
                                echo "Waiting for backend..."
                                sleep 2
                            done'
                            echo "Backend is healthy"
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                if (!params.DESTROY_INFRASTRUCTURE && (params.DEPLOYMENT_TYPE == 'full-deployment' || params.DEPLOYMENT_TYPE == 'infrastructure-only')) {
                    def instanceIp = sh(
                        script: 'cd terraform && terraform output -raw instance_ip 2>/dev/null || echo "N/A"',
                        returnStdout: true
                    ).trim()
                    
                    echo """
                    ========================================
                    DEPLOYMENT SUMMARY
                    ========================================
                    Environment: ${params.ENVIRONMENT}
                    Deployment Type: ${params.DEPLOYMENT_TYPE}
                    Instance IP: ${instanceIp}
                    Frontend URL: http://${instanceIp}:5173
                    Backend WebSocket: ws://${instanceIp}:8181
                    Git Commit: ${env.GIT_COMMIT_SHORT}
                    ========================================
                    """
                }
            }
        }
        success {
            echo 'Deployment completed successfully!'
        }
        failure {
            echo 'Deployment failed!'
            script {
                if (params.DEPLOYMENT_TYPE == 'full-deployment' || params.DEPLOYMENT_TYPE == 'infrastructure-only') {
                    echo 'Consider running cleanup or checking Terraform state'
                }
            }
        }
        cleanup {
            // Clean up any temporary files
            sh 'rm -f tfplan destroy.tfplan .env || true'
        }
    }
}