pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TF_VAR_region = 'us-east-1'
        TF_VAR_aws_access_key = credentials('aws-access-key')
        TF_VAR_aws_secret_key = credentials('aws-secret-key')
        // WEBSOCKET_URL will be dynamically set after instance is ready
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
    pollSCM('H/2 * * * *') // poll every 2 minutes
}

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = bat(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Setup Tools') {
            steps {
                script {
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
                                    
                                    REM Get instance IP and save to environment
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
                dir('terraform') {
                    def instanceIp = bat(
                        script: 'terraform output -raw instance_ip',
                        returnStdout: true
                    ).trim()
                    
                    // Clean up the IP
                    instanceIp = instanceIp.replaceAll(/[^0-9.]/, '')
                    env.INSTANCE_IP = instanceIp
                    env.WEBSOCKET_URL = "ws://${instanceIp}:8181"

                    echo "Waiting for instance ${instanceIp} to be ready..."
                    
                    // Use a proper batch script with the IP variable set
                    bat """
@echo off
set INSTANCE_IP=${instanceIp}
powershell -NoProfile -ExecutionPolicy Bypass -Command "\$i=0; while (\$i -lt 10) { try { Invoke-WebRequest -Uri 'http://%INSTANCE_IP%:5173' -TimeoutSec 5 | Out-Null; Write-Host 'Instance is ready!'; break } catch { Write-Host 'Waiting for instance... (attempt ' + (\$i+1) + '/10)'; Start-Sleep -Seconds 10; \$i++ } }"
"""
                }
            }
        }
    }
}

        stage('Build Docker Images') {
            steps {
                script {
                    if ((params.DEPLOYMENT_TYPE == 'application-only' || params.DEPLOYMENT_TYPE == 'full-deployment') && !params.DESTROY_INFRASTRUCTURE) {
                        bat """
                            docker-compose build --no-cache
                            docker tag chess_frontend:latest chess_frontend:%GIT_COMMIT_SHORT%
                            docker tag chess_backend:latest chess_backend:%GIT_COMMIT_SHORT%
                        """
                    }
                }
            }
        }

        stage('Deploy Application') {
            steps {
                script {
                    if ((params.DEPLOYMENT_TYPE == 'application-only' || params.DEPLOYMENT_TYPE == 'full-deployment') && !params.DESTROY_INFRASTRUCTURE) {
                        def instanceIp = env.INSTANCE_IP ?: bat(
                            script: 'cd terraform && terraform output -raw instance_ip',
                            returnStdout: true
                        ).trim()
                        def instanceId = bat(
                            script: 'cd terraform && terraform output -raw instance_id',
                            returnStdout: true
                        ).trim()

                        // Clean up values
                        instanceIp = instanceIp.replaceAll(/.*?(\d+\.\d+\.\d+\.\d+).*/, '$1')
                        instanceId = instanceId.replaceAll(/.*?(i-[a-z0-9]+).*/, '$1')

                        env.INSTANCE_IP = instanceIp
                        env.INSTANCE_ID = instanceId

                        echo "Deploying to instance ${instanceId} at IP ${instanceIp}"

                        bat """
aws ssm send-command --instance-ids %INSTANCE_ID% --document-name "AWS-RunShellScript" --parameters "commands=['cd /home/ubuntu', 'sudo docker-compose down || true', 'sudo docker-compose pull || true', 'export WEBSOCKET_URL=ws://%INSTANCE_IP%:8181', 'sudo docker-compose up -d']" --region %AWS_DEFAULT_REGION%
timeout 60
"""
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    if ((params.DEPLOYMENT_TYPE == 'application-only' || params.DEPLOYMENT_TYPE == 'full-deployment') && !params.DESTROY_INFRASTRUCTURE) {
                        def instanceIp = env.INSTANCE_IP ?: bat(
                            script: 'cd terraform && terraform output -raw instance_ip',
                            returnStdout: true
                        ).trim()
                        instanceIp = instanceIp.replaceAll(/.*?(\d+\.\d+\.\d+\.\d+).*/, '$1')
                        env.INSTANCE_IP = instanceIp

                        echo "Performing health checks on instance ${instanceIp}"

                        bat """
echo Performing health checks...

powershell -Command "try { Invoke-WebRequest -Uri 'http://${instanceIp}:5173' -TimeoutSec 10 | Out-Null; Write-Host 'Frontend is healthy' } catch { Write-Host 'Frontend check failed'; exit 1 }"

powershell -Command "for (\$i=0; \$i -lt 5; \$i++) { try { \$tcp = New-Object System.Net.Sockets.TcpClient; \$tcp.Connect('${instanceIp}', 8181); \$tcp.Close(); Write-Host 'Backend is healthy'; break } catch { Write-Host 'Waiting for backend...'; Start-Sleep 2 } }"
"""
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                if (!params.DESTROY_INFRASTRUCTURE && (params.DEPLOYMENT_TYPE == 'full-deployment' || params.DEPLOYMENT_TYPE == 'infrastructure-only')) {
                    def instanceIp = env.INSTANCE_IP ?: bat(
                        script: 'cd terraform && terraform output -raw instance_ip 2>nul || echo N/A',
                        returnStdout: true
                    ).trim()
                    instanceIp = instanceIp.replaceAll(/.*?(\d+\.\d+\.\d+\.\d+).*/, '$1')

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
            bat 'del tfplan destroy.tfplan .env 2>nul || echo Files not found'
        }
    }
}
