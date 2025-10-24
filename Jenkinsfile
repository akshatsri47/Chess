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
                    bat '''
                        where terraform >nul 2>&1
                        if %errorlevel% neq 0 (
                            echo Installing Terraform...
                            powershell -Command "Invoke-WebRequest -Uri 'https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_windows_amd64.zip' -OutFile 'terraform.zip'"
                            powershell -Command "Expand-Archive -Path 'terraform.zip' -DestinationPath '.' -Force"
                            move terraform.exe C:\\Windows\\System32\\
                            del terraform.zip
                        )
                        
                        where aws >nul 2>&1
                        if %errorlevel% neq 0 (
                            echo Installing AWS CLI...
                            powershell -Command "Invoke-WebRequest -Uri 'https://awscli.amazonaws.com/AWSCLIV2.msi' -OutFile 'AWSCLIV2.msi'"
                            msiexec /i AWSCLIV2.msi /quiet
                            del AWSCLIV2.msi
                        )
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
                                bat '''
                                    terraform init
                                    terraform plan -destroy -var="environment=%ENVIRONMENT%" -out=destroy.tfplan
                                '''
                            } else {
                                bat '''
                                    terraform init
                                    terraform plan -var="environment=%ENVIRONMENT%" -out=tfplan
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
                                bat '''
                                    terraform apply -auto-approve destroy.tfplan
                                '''
                            } else {
                                bat '''
                                    terraform apply -auto-approve tfplan
                                    
                                    REM Get instance IP and set environment variable
                                    for /f "tokens=*" %%i in ('terraform output -raw instance_ip') do set INSTANCE_IP=%%i
                                    echo INSTANCE_IP=%INSTANCE_IP% > ..\\.env
                                    echo Instance IP: %INSTANCE_IP%
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
                        def instanceIp = bat(
                            script: 'cd terraform && terraform output -raw instance_ip',
                            returnStdout: true
                        ).trim()
                        
                        env.INSTANCE_IP = instanceIp
                        echo "Waiting for instance ${instanceIp} to be ready..."
                        
                        // Wait for instance to be ready
                        bat '''
                            powershell -Command "for ($i=0; $i -lt 30; $i++) { try { Invoke-WebRequest -Uri 'http://%INSTANCE_IP%:5173' -TimeoutSec 5 | Out-Null; break } catch { Write-Host 'Waiting for application to start...'; Start-Sleep 10 } }"
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
                        bat '''
                            docker-compose build --no-cache
                            docker tag chess_frontend:latest chess_frontend:%GIT_COMMIT_SHORT%
                            docker tag chess_backend:latest chess_backend:%GIT_COMMIT_SHORT%
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
                        def instanceIp = bat(
                            script: 'cd terraform && terraform output -raw instance_ip',
                            returnStdout: true
                        ).trim()
                        
                        // Deploy to remote instance
                        bat '''
                            REM Copy docker-compose and .env to instance
                            scp -o StrictHostKeyChecking=no docker-compose.yml ubuntu@%INSTANCE_IP%:/home/ubuntu/
                            scp -o StrictHostKeyChecking=no .env ubuntu@%INSTANCE_IP%:/home/ubuntu/ 2>nul || echo File not found
                            
                            REM Deploy application on remote instance
                            ssh -o StrictHostKeyChecking=no ubuntu@%INSTANCE_IP% "cd /home/ubuntu && export WEBSOCKET_URL=ws://%INSTANCE_IP%:8181 && sudo docker-compose down || true && sudo docker-compose pull || true && sudo docker-compose up -d"
                        '''
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    if ((params.DEPLOYMENT_TYPE == 'application-only' || params.DEPLOYMENT_TYPE == 'full-deployment') && !params.DESTROY_INFRASTRUCTURE) {
                        def instanceIp = bat(
                            script: 'cd terraform && terraform output -raw instance_ip',
                            returnStdout: true
                        ).trim()
                        
                        bat '''
                            echo Performing health checks...
                            
                            REM Check frontend
                            powershell -Command "try { Invoke-WebRequest -Uri 'http://%INSTANCE_IP%:5173' -TimeoutSec 10 | Out-Null; Write-Host 'Frontend is healthy' } catch { Write-Host 'Frontend check failed'; exit 1 }"
                            
                            REM Check backend WebSocket
                            powershell -Command "for ($i=0; $i -lt 5; $i++) { try { $tcp = New-Object System.Net.Sockets.TcpClient; $tcp.Connect('%INSTANCE_IP%', 8181); $tcp.Close(); Write-Host 'Backend is healthy'; break } catch { Write-Host 'Waiting for backend...'; Start-Sleep 2 } }"
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
                    def instanceIp = bat(
                        script: 'cd terraform && terraform output -raw instance_ip 2>nul || echo N/A',
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
            bat 'del tfplan destroy.tfplan .env 2>nul || echo Files not found'
        }
    }
}