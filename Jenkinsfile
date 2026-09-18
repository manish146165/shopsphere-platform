pipeline {

    agent {
        label 'shopsphere-agent'
    }

    options {
        skipDefaultCheckout(true)
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 90, unit: 'MINUTES')

        buildDiscarder(
            logRotator(
                numToKeepStr: '20'
            )
        )
    }

    parameters {

        choice(
            name: 'TRIVY_POLICY',
            choices: [
                'REPORT_ONLY',
                'HIGH_CRITICAL'
            ],
            description: 'REPORT_ONLY = continue deployment even if HIGH/CRITICAL are found. HIGH_CRITICAL = stop pipeline on HIGH/CRITICAL.'
        )
    }

    environment {

        AWS_REGION = 'us-west-2'

        AWS_ACCOUNT_ID = '112188881127'

        ECR_REPO = 'shopsphere'

        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        ECR_URI = "${ECR_REGISTRY}/${ECR_REPO}"

        K8S_NAMESPACE = 'shopsphere'

        SONARQUBE_SERVER = 'shopsphere-sonarqube'

        SONAR_SCANNER = 'sonar-scanner'

        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {

        // =====================================================
        // 1. CHECKOUT
        // =====================================================

        stage('Checkout') {

            steps {

                echo '=============================================='
                echo 'CHECKOUT'
                echo '=============================================='

                checkout scm

                sh '''
                    set -e

                    echo "Git commit:"
                    git rev-parse --short HEAD

                    echo "Git branch:"
                    git branch --show-current

                    echo ""
                    echo "Repository:"
                    ls -la

                    echo ""
                    echo "Application directories:"
                    ls application
                '''
            }
        }


        // =====================================================
        // 2. APPLICATION TESTS
        // =====================================================

        stage('Application Tests') {

            steps {

                sh '''
                    set -e

                    echo "=============================================="
                    echo "APPLICATION TESTS"
                    echo "=============================================="

                    echo ""
                    echo "===== FRONTEND ====="

                    cd application/frontend
                    go test ./...

                    echo ""
                    echo "===== CHECKOUTSERVICE ====="

                    cd ../checkoutservice
                    go test ./...

                    echo ""
                    echo "===== PRODUCTCATALOGSERVICE ====="

                    cd ../productcatalogservice
                    go test ./...

                    echo ""
                    echo "===== SHIPPING SERVICE ====="

                    cd ../shippingservice
                    go test ./...

                    echo ""
                    echo "===== PYTHON SERVICES ====="

                    cd ../emailservice
                    python3 -m compileall -q .

                    cd ../recommendationservice
                    python3 -m compileall -q .

                    echo ""
                    echo "Application tests completed successfully."
                '''
            }
        }


        // =====================================================
        // 3. SONARQUBE ANALYSIS
        // =====================================================

        stage('SonarQube Analysis') {

            steps {

                script {

                    def scannerHome = tool "${SONAR_SCANNER}"

                    withSonarQubeEnv("${SONARQUBE_SERVER}") {

                        sh """
                            set -e

                            echo "=============================================="
                            echo "SONARQUBE ANALYSIS"
                            echo "=============================================="

                            echo "Scanner:"
                            ${scannerHome}/bin/sonar-scanner --version

                            echo ""
                            echo "Starting SonarQube analysis..."

                            ${scannerHome}/bin/sonar-scanner
                        """
                    }
                }
            }
        }


        // =====================================================
        // 4. QUALITY GATE
        // =====================================================

        stage('SonarQube Quality Gate') {

            steps {

                timeout(time: 10, unit: 'MINUTES') {

                    waitForQualityGate(
                        abortPipeline: true
                    )
                }
            }
        }


        // =====================================================
        // 5. DOCKER BUILD
        // =====================================================

        stage('Docker Build') {

            steps {

                sh '''
                    set -e

                    echo "=============================================="
                    echo "DOCKER BUILD"
                    echo "=============================================="

                    echo "ECR URI:"
                    echo "${ECR_URI}"

                    echo "Build number:"
                    echo "${BUILD_NUMBER}"


                    echo ""
                    echo "===== adservice ====="

                    docker build \
                      -t "${ECR_URI}:adservice-${IMAGE_TAG}" \
                      application/adservice


                    echo ""
                    echo "===== cartservice ====="

                    docker build \
                      -t "${ECR_URI}:cartservice-${IMAGE_TAG}" \
                      application/cartservice/src


                    echo ""
                    echo "===== checkoutservice ====="

                    docker build \
                      -t "${ECR_URI}:checkoutservice-${IMAGE_TAG}" \
                      application/checkoutservice


                    echo ""
                    echo "===== currencyservice ====="

                    docker build \
                      -t "${ECR_URI}:currencyservice-${IMAGE_TAG}" \
                      application/currencyservice


                    echo ""
                    echo "===== emailservice ====="

                    docker build \
                      -t "${ECR_URI}:emailservice-${IMAGE_TAG}" \
                      application/emailservice


                    echo ""
                    echo "===== frontend ====="

                    docker build \
                      -t "${ECR_URI}:frontend-${IMAGE_TAG}" \
                      application/frontend


                    echo ""
                    echo "===== paymentservice ====="

                    docker build \
                      -t "${ECR_URI}:paymentservice-${IMAGE_TAG}" \
                      application/paymentservice


                    echo ""
                    echo "===== productcatalogservice ====="

                    docker build \
                      -t "${ECR_URI}:productcatalogservice-${IMAGE_TAG}" \
                      application/productcatalogservice


                    echo ""
                    echo "===== recommendationservice ====="

                    docker build \
                      -t "${ECR_URI}:recommendationservice-${IMAGE_TAG}" \
                      application/recommendationservice


                    echo ""
                    echo "===== shippingservice ====="

                    docker build \
                      -t "${ECR_URI}:shippingservice-${IMAGE_TAG}" \
                      application/shippingservice


                    echo ""
                    echo "=============================================="
                    echo "ALL IMAGES BUILT"
                    echo "=============================================="

                    docker images "${ECR_URI}" \
                      --format "table {{.Repository}}\\t{{.Tag}}\\t{{.Size}}"
                '''
            }
        }


        // =====================================================
        // 6. TRIVY
        // =====================================================

        stage('Trivy Security Scan') {

            steps {

                script {

                    def exitCode =
                        params.TRIVY_POLICY == 'HIGH_CRITICAL' ? 1 : 0

                    sh """
                        set -e

                        echo "=============================================="
                        echo "TRIVY SECURITY SCAN"
                        echo "=============================================="

                        trivy --version

                        echo ""
                        echo "Scanning images..."

                        echo ""
                        echo "===== adservice ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${exitCode} \
                          "${ECR_URI}:adservice-${IMAGE_TAG}"


                        echo ""
                        echo "===== cartservice ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${exitCode} \
                          "${ECR_URI}:cartservice-${IMAGE_TAG}"


                        echo ""
                        echo "===== checkoutservice ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${exitCode} \
                          "${ECR_URI}:checkoutservice-${IMAGE_TAG}"


                        echo ""
                        echo "===== currencyservice ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${exitCode} \
                          "${ECR_URI}:currencyservice-${IMAGE_TAG}"


                        echo ""
                        echo "===== emailservice ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${exitCode} \
                          "${ECR_URI}:emailservice-${IMAGE_TAG}"


                        echo ""
                        echo "===== frontend ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${exitCode} \
                          "${ECR_URI}:frontend-${IMAGE_TAG}"


                        echo ""
                        echo "===== paymentservice ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${exitCode} \
                          "${ECR_URI}:paymentservice-${IMAGE_TAG}"


                        echo ""
                        echo "===== productcatalogservice ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${exitCode} \
                          "${ECR_URI}:productcatalogservice-${IMAGE_TAG}"


                        echo ""
                        echo "===== recommendationservice ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${exitCode} \
                          "${ECR_URI}:recommendationservice-${IMAGE_TAG}"


                        echo ""
                        echo "===== shippingservice ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${exitCode} \
                          "${ECR_URI}:shippingservice-${IMAGE_TAG}"


                        echo ""
                        echo "=============================================="
                        echo "TRIVY SCAN COMPLETED"
                        echo "=============================================="
                    """
                }
            }
        }


        // =====================================================
        // 7. ECR LOGIN
        // =====================================================

        stage('ECR Login') {

            steps {

                sh '''
                    set -e

                    echo "=============================================="
                    echo "ECR LOGIN"
                    echo "=============================================="

                    aws sts get-caller-identity

                    aws ecr get-login-password \
                      --region "${AWS_REGION}" | \
                    docker login \
                      --username AWS \
                      --password-stdin \
                      "${ECR_REGISTRY}"

                    echo ""
                    echo "ECR login successful."
                '''
            }
        }


        // =====================================================
        // 8. PUSH TO ECR
        // =====================================================

        stage('Push Images to ECR') {

            steps {

                sh '''
                    set -e

                    echo "=============================================="
                    echo "PUSHING IMAGES TO ECR"
                    echo "=============================================="


                    docker push \
                      "${ECR_URI}:adservice-${IMAGE_TAG}"


                    docker push \
                      "${ECR_URI}:cartservice-${IMAGE_TAG}"


                    docker push \
                      "${ECR_URI}:checkoutservice-${IMAGE_TAG}"


                    docker push \
                      "${ECR_URI}:currencyservice-${IMAGE_TAG}"


                    docker push \
                      "${ECR_URI}:emailservice-${IMAGE_TAG}"


                    docker push \
                      "${ECR_URI}:frontend-${IMAGE_TAG}"


                    docker push \
                      "${ECR_URI}:paymentservice-${IMAGE_TAG}"


                    docker push \
                      "${ECR_URI}:productcatalogservice-${IMAGE_TAG}"


                    docker push \
                      "${ECR_URI}:recommendationservice-${IMAGE_TAG}"


                    docker push \
                      "${ECR_URI}:shippingservice-${IMAGE_TAG}"


                    echo ""
                    echo "All images pushed successfully."
                '''
            }
        }


        // =====================================================
        // 9. KUBERNETES BASE
        // =====================================================

        stage('Apply Kubernetes Base') {

            steps {

                sh '''
                    set -e

                    echo "=============================================="
                    echo "KUBERNETES BASE RESOURCES"
                    echo "=============================================="

                    echo ""
                    echo "Current context:"

                    kubectl config current-context

                    echo ""
                    echo "EKS nodes:"

                    kubectl get nodes

                    echo ""
                    echo "Applying namespace..."

                    kubectl apply \
                      -f kubernetes/dev/namespace/namespace.yaml

                    echo ""
                    echo "Applying ConfigMap..."

                    kubectl apply \
                      -f kubernetes/dev/configmap/configmap.yaml

                    echo ""
                    echo "Checking namespace..."

                    kubectl get ns "${K8S_NAMESPACE}"

                    echo ""
                    echo "Checking ConfigMap..."

                    kubectl get configmap \
                      shopsphere-config \
                      -n "${K8S_NAMESPACE}"
                '''
            }
        }


        // =====================================================
        // 10. REDIS
        // =====================================================

        stage('Deploy Redis') {

            steps {

                sh '''
                    set -e

                    echo "=============================================="
                    echo "DEPLOY REDIS"
                    echo "=============================================="

                    kubectl apply \
                      -f kubernetes/dev/redis/deployment.yaml \
                      -n "${K8S_NAMESPACE}"

                    kubectl apply \
                      -f kubernetes/dev/redis/service.yaml \
                      -n "${K8S_NAMESPACE}"

                    echo ""
                    echo "Waiting for Redis..."

                    kubectl rollout status \
                      deployment/redis \
                      -n "${K8S_NAMESPACE}" \
                      --timeout=5m

                    echo ""
                    echo "Redis deployed successfully."
                '''
            }
        }


        // =====================================================
        // 11. APPLICATION SERVICES
        // =====================================================

        stage('Deploy Application Services') {

            steps {

                sh '''
                    set -e

                    echo "=============================================="
                    echo "DEPLOY APPLICATION SERVICES"
                    echo "=============================================="


                    SERVICES="
                    cartservice
                    productcatalogservice
                    currencyservice
                    adservice
                    recommendationservice
                    shippingservice
                    paymentservice
                    emailservice
                    checkoutservice
                    frontend
                    "


                    for SERVICE in ${SERVICES}
                    do

                        echo ""
                        echo "=========================================="
                        echo "DEPLOYING ${SERVICE}"
                        echo "=========================================="


                        DEPLOYMENT_FILE="kubernetes/dev/${SERVICE}/deployment.yaml"

                        SERVICE_FILE="kubernetes/dev/${SERVICE}/service.yaml"

                        IMAGE="${ECR_URI}:${SERVICE}-${IMAGE_TAG}"


                        echo "Image:"
                        echo "${IMAGE}"


                        echo ""
                        echo "Applying deployment..."

                        sed -E \
                          "s#^([[:space:]]*)image:.*#\\1image: ${IMAGE}#" \
                          "${DEPLOYMENT_FILE}" | \
                        kubectl apply \
                          -f - \
                          -n "${K8S_NAMESPACE}"


                        echo ""
                        echo "Applying service..."

                        kubectl apply \
                          -f "${SERVICE_FILE}" \
                          -n "${K8S_NAMESPACE}"


                        echo ""
                        echo "Waiting for rollout..."

                        kubectl rollout status \
                          deployment/${SERVICE} \
                          -n "${K8S_NAMESPACE}" \
                          --timeout=5m


                        echo ""
                        echo "${SERVICE} deployed successfully."

                    done
                '''
            }
        }


        // =====================================================
        // 12. HPA + INGRESS
        // =====================================================

        stage('Apply HPA and Ingress') {

            steps {

                sh '''
                    set -e

                    echo "=============================================="
                    echo "HPA"
                    echo "=============================================="

                    kubectl apply \
                      -f kubernetes/dev/hpa/frontend-hpa.yaml \
                      -n "${K8S_NAMESPACE}"


                    echo ""
                    echo "=============================================="
                    echo "INGRESS"
                    echo "=============================================="

                    kubectl apply \
                      -f kubernetes/dev/ingress/frontend-ingress.yaml \
                      -n "${K8S_NAMESPACE}"


                    echo ""
                    echo "HPA:"

                    kubectl get hpa \
                      -n "${K8S_NAMESPACE}" || true


                    echo ""
                    echo "Ingress:"

                    kubectl get ingress \
                      -n "${K8S_NAMESPACE}" || true
                '''
            }
        }


        // =====================================================
        // 13. FINAL VERIFICATION
        // =====================================================

        stage('EKS Verification') {

            steps {

                sh '''
                    set -e

                    echo "=============================================="
                    echo "FINAL EKS VERIFICATION"
                    echo "=============================================="


                    echo ""
                    echo "===== DEPLOYMENTS ====="

                    kubectl get deployments \
                      -n "${K8S_NAMESPACE}" \
                      -o wide


                    echo ""
                    echo "===== PODS ====="

                    kubectl get pods \
                      -n "${K8S_NAMESPACE}" \
                      -o wide


                    echo ""
                    echo "===== SERVICES ====="

                    kubectl get services \
                      -n "${K8S_NAMESPACE}"


                    echo ""
                    echo "===== ROLLOUT VERIFICATION ====="


                    for SERVICE in \
                      cartservice \
                      productcatalogservice \
                      currencyservice \
                      adservice \
                      recommendationservice \
                      shippingservice \
                      paymentservice \
                      emailservice \
                      checkoutservice \
                      frontend
                    do

                        echo ""
                        echo "Checking ${SERVICE}..."

                        kubectl rollout status \
                          deployment/${SERVICE} \
                          -n "${K8S_NAMESPACE}" \
                          --timeout=5m

                    done


                    echo ""
                    echo "=============================================="
                    echo "SHOPSPHERE DEPLOYMENT SUCCESSFUL"
                    echo "=============================================="
                '''
            }
        }
    }


    // =========================================================
    // POST
    // =========================================================

    post {

        success {

            echo '''
            ==============================================
            SHOPSPHERE CI/CD SUCCESS
            ==============================================

            Checkout        : PASSED
            Tests           : PASSED
            SonarQube       : PASSED
            Quality Gate    : PASSED
            Docker Build    : PASSED
            Trivy           : PASSED
            ECR Push        : PASSED
            EKS Deployment  : PASSED
            Verification    : PASSED

            ==============================================
            '''
        }


        failure {

            echo '''
            ==============================================
            SHOPSPHERE CI/CD FAILED
            ==============================================

            Check the failed stage in Console Output.

            ==============================================
            '''
        }


        always {

            sh '''
                echo "=============================================="
                echo "DOCKER CLEANUP"
                echo "=============================================="


                docker image rm \
                  "${ECR_URI}:adservice-${IMAGE_TAG}" \
                  "${ECR_URI}:cartservice-${IMAGE_TAG}" \
                  "${ECR_URI}:checkoutservice-${IMAGE_TAG}" \
                  "${ECR_URI}:currencyservice-${IMAGE_TAG}" \
                  "${ECR_URI}:emailservice-${IMAGE_TAG}" \
                  "${ECR_URI}:frontend-${IMAGE_TAG}" \
                  "${ECR_URI}:paymentservice-${IMAGE_TAG}" \
                  "${ECR_URI}:productcatalogservice-${IMAGE_TAG}" \
                  "${ECR_URI}:recommendationservice-${IMAGE_TAG}" \
                  "${ECR_URI}:shippingservice-${IMAGE_TAG}" \
                  2>/dev/null || true


                echo "Docker cleanup completed."
            '''
        }
    }
}
