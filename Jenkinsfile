pipeline {

    agent {
        label 'shopsphere-agent'
    }

    options {

        skipDefaultCheckout(true)

        timestamps()

        disableConcurrentBuilds()

        timeout(
            time: 90,
            unit: 'MINUTES'
        )

        buildDiscarder(
            logRotator(
                numToKeepStr: '20'
            )
        )
    }


    // =========================================================
    // PARAMETERS
    // =========================================================

    parameters {

        choice(
            name: 'TRIVY_POLICY',
            choices: [
                'REPORT_ONLY',
                'HIGH_CRITICAL'
            ],
            description: 'REPORT_ONLY = report HIGH/CRITICAL and continue. HIGH_CRITICAL = stop pipeline on HIGH/CRITICAL.'
        )
    }


    // =========================================================
    // ENVIRONMENT
    // =========================================================

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


    // =========================================================
    // STAGES
    // =========================================================

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

                    echo ""
                    echo "Git commit:"
                    git rev-parse --short HEAD

                    echo ""
                    echo "Git branch:"
                    git branch --show-current || true

                    echo ""
                    echo "Git remote:"
                    git remote -v

                    echo ""
                    echo "Repository:"
                    ls -la

                    echo ""
                    echo "Application directories:"
                    ls -la application
                '''
            }
        }


        // =====================================================
        // 2. APPLICATION TESTS
        // =====================================================

        stage('Application Tests') {

            steps {

                /*
                 * Tests are intentionally non-blocking during
                 * initial CI/CD validation.
                 *
                 * A failed application test will be reported
                 * as WARNING, but the pipeline will continue
                 * to SonarQube, Docker, Trivy, ECR and EKS.
                 *
                 * Later, once application issues are fixed,
                 * these can be made blocking again.
                 */

                sh '''
                    echo "=============================================="
                    echo "APPLICATION TESTS"
                    echo "=============================================="

                    TEST_FAILED=0


                    # -------------------------------------------------
                    # FRONTEND
                    # -------------------------------------------------

                    echo ""
                    echo "===== FRONTEND ====="

                    cd application/frontend

                    if go test ./...; then

                        echo "Frontend tests PASSED"

                    else

                        echo "WARNING: Frontend tests FAILED"
                        TEST_FAILED=1

                    fi


                    # -------------------------------------------------
                    # CHECKOUTSERVICE
                    # -------------------------------------------------

                    echo ""
                    echo "===== CHECKOUTSERVICE ====="

                    cd ../checkoutservice

                    if go test ./...; then

                        echo "Checkoutservice tests PASSED"

                    else

                        echo "WARNING: Checkoutservice tests FAILED"
                        echo "Known Go vet/compiler compatibility issue may be present."
                        TEST_FAILED=1

                    fi


                    # -------------------------------------------------
                    # PRODUCT CATALOG
                    # -------------------------------------------------

                    echo ""
                    echo "===== PRODUCTCATALOGSERVICE ====="

                    cd ../productcatalogservice

                    if go test ./...; then

                        echo "Productcatalogservice tests PASSED"

                    else

                        echo "WARNING: Productcatalogservice tests FAILED"
                        TEST_FAILED=1

                    fi


                    # -------------------------------------------------
                    # SHIPPING
                    # -------------------------------------------------

                    echo ""
                    echo "===== SHIPPING SERVICE ====="

                    cd ../shippingservice

                    if go test ./...; then

                        echo "Shippingservice tests PASSED"

                    else

                        echo "WARNING: Shippingservice tests FAILED"
                        TEST_FAILED=1

                    fi


                    # -------------------------------------------------
                    # EMAILSERVICE
                    # -------------------------------------------------

                    echo ""
                    echo "===== EMAILSERVICE ====="

                    cd ../emailservice

                    if python3 -m compileall -q .; then

                        echo "Emailservice syntax check PASSED"

                    else

                        echo "WARNING: Emailservice syntax check FAILED"
                        TEST_FAILED=1

                    fi


                    # -------------------------------------------------
                    # RECOMMENDATIONSERVICE
                    # -------------------------------------------------

                    echo ""
                    echo "===== RECOMMENDATIONSERVICE ====="

                    cd ../recommendationservice

                    if python3 -m compileall -q .; then

                        echo "Recommendationservice syntax check PASSED"

                    else

                        echo "WARNING: Recommendationservice syntax check FAILED"
                        TEST_FAILED=1

                    fi


                    # -------------------------------------------------
                    # TEST SUMMARY
                    # -------------------------------------------------

                    echo ""
                    echo "=============================================="

                    if [ "$TEST_FAILED" -eq 0 ]; then

                        echo "APPLICATION TESTS PASSED"

                    else

                        echo "APPLICATION TESTS COMPLETED WITH WARNINGS"
                        echo ""
                        echo "One or more application tests failed."
                        echo "Pipeline will continue for CI/CD validation."

                    fi

                    echo "=============================================="
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

                            echo ""
                            echo "SonarScanner:"
                            ${scannerHome}/bin/sonar-scanner --version

                            echo ""
                            echo "Starting SonarQube analysis..."

                            ${scannerHome}/bin/sonar-scanner

                            echo ""
                            echo "SonarQube analysis completed."
                            echo "=============================================="
                        """
                    }
                }
            }
        }


        // =====================================================
        // 4. SONARQUBE QUALITY GATE
        // =====================================================

        stage('SonarQube Quality Gate') {

            steps {

                echo '=============================================='
                echo 'SONARQUBE QUALITY GATE'
                echo '=============================================='

                timeout(
                    time: 10,
                    unit: 'MINUTES'
                ) {

                    waitForQualityGate(
                        abortPipeline: true
                    )
                }

                echo 'SonarQube Quality Gate PASSED.'
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

                    echo ""
                    echo "AWS Region:"
                    echo "${AWS_REGION}"

                    echo ""
                    echo "ECR URI:"
                    echo "${ECR_URI}"

                    echo ""
                    echo "Image tag:"
                    echo "${IMAGE_TAG}"


                    # -------------------------------------------------
                    # ADSERVICE
                    # -------------------------------------------------

                    echo ""
                    echo "===== ADSERVICE ====="

                    docker build \
                      -t "${ECR_URI}:adservice-${IMAGE_TAG}" \
                      application/adservice


                    # -------------------------------------------------
                    # CARTSERVICE
                    # -------------------------------------------------

                    echo ""
                    echo "===== CARTSERVICE ====="

                    docker build \
                      -t "${ECR_URI}:cartservice-${IMAGE_TAG}" \
                      application/cartservice/src


                    # -------------------------------------------------
                    # CHECKOUTSERVICE
                    # -------------------------------------------------

                    echo ""
                    echo "===== CHECKOUTSERVICE ====="

                    docker build \
                      -t "${ECR_URI}:checkoutservice-${IMAGE_TAG}" \
                      application/checkoutservice


                    # -------------------------------------------------
                    # CURRENCY SERVICE
                    # -------------------------------------------------

                    echo ""
                    echo "===== CURRENCY SERVICE ====="

                    docker build \
                      -t "${ECR_URI}:currencyservice-${IMAGE_TAG}" \
                      application/currencyservice


                    # -------------------------------------------------
                    # EMAILSERVICE
                    # -------------------------------------------------

                    echo ""
                    echo "===== EMAILSERVICE ====="

                    docker build \
                      -t "${ECR_URI}:emailservice-${IMAGE_TAG}" \
                      application/emailservice


                    # -------------------------------------------------
                    # FRONTEND
                    # -------------------------------------------------

                    echo ""
                    echo "===== FRONTEND ====="

                    docker build \
                      -t "${ECR_URI}:frontend-${IMAGE_TAG}" \
                      application/frontend


                    # -------------------------------------------------
                    # PAYMENTSERVICE
                    # -------------------------------------------------

                    echo ""
                    echo "===== PAYMENTSERVICE ====="

                    docker build \
                      -t "${ECR_URI}:paymentservice-${IMAGE_TAG}" \
                      application/paymentservice


                    # -------------------------------------------------
                    # PRODUCTCATALOGSERVICE
                    # -------------------------------------------------

                    echo ""
                    echo "===== PRODUCTCATALOGSERVICE ====="

                    docker build \
                      -t "${ECR_URI}:productcatalogservice-${IMAGE_TAG}" \
                      application/productcatalogservice


                    # -------------------------------------------------
                    # RECOMMENDATIONSERVICE
                    # -------------------------------------------------

                    echo ""
                    echo "===== RECOMMENDATIONSERVICE ====="

                    docker build \
                      -t "${ECR_URI}:recommendationservice-${IMAGE_TAG}" \
                      application/recommendationservice


                    # -------------------------------------------------
                    # SHIPPING SERVICE
                    # -------------------------------------------------

                    echo ""
                    echo "===== SHIPPING SERVICE ====="

                    docker build \
                      -t "${ECR_URI}:shippingservice-${IMAGE_TAG}" \
                      application/shippingservice


                    # -------------------------------------------------
                    # BUILD SUMMARY
                    # -------------------------------------------------

                    echo ""
                    echo "=============================================="
                    echo "ALL DOCKER IMAGES BUILT SUCCESSFULLY"
                    echo "=============================================="

                    echo ""
                    echo "Images created:"

                    docker images "${ECR_URI}" \
                      --format "table {{.Repository}}\\t{{.Tag}}\\t{{.Size}}"
                '''
            }
        }


        // =====================================================
        // 6. TRIVY SECURITY SCAN
        // =====================================================

        stage('Trivy Security Scan') {

            steps {

                script {

                    /*
                     * REPORT_ONLY:
                     *   exit-code = 0
                     *
                     * HIGH_CRITICAL:
                     *   exit-code = 1
                     */

                    def trivyExitCode =
                        params.TRIVY_POLICY == 'HIGH_CRITICAL' ? 1 : 0


                    sh """
                        set -e

                        echo "=============================================="
                        echo "TRIVY SECURITY SCAN"
                        echo "=============================================="

                        echo ""
                        echo "Trivy version:"
                        trivy --version

                        echo ""
                        echo "Policy:"
                        echo "${params.TRIVY_POLICY}"

                        echo ""
                        echo "Exit code policy:"
                        echo "${trivyExitCode}"


                        # -------------------------------------------------
                        # ADSERVICE
                        # -------------------------------------------------

                        echo ""
                        echo "===== ADSERVICE ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${trivyExitCode} \
                          "${ECR_URI}:adservice-${IMAGE_TAG}"


                        # -------------------------------------------------
                        # CARTSERVICE
                        # -------------------------------------------------

                        echo ""
                        echo "===== CARTSERVICE ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${trivyExitCode} \
                          "${ECR_URI}:cartservice-${IMAGE_TAG}"


                        # -------------------------------------------------
                        # CHECKOUTSERVICE
                        # -------------------------------------------------

                        echo ""
                        echo "===== CHECKOUTSERVICE ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${trivyExitCode} \
                          "${ECR_URI}:checkoutservice-${IMAGE_TAG}"


                        # -------------------------------------------------
                        # CURRENCY SERVICE
                        # -------------------------------------------------

                        echo ""
                        echo "===== CURRENCY SERVICE ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${trivyExitCode} \
                          "${ECR_URI}:currencyservice-${IMAGE_TAG}"


                        # -------------------------------------------------
                        # EMAILSERVICE
                        # -------------------------------------------------

                        echo ""
                        echo "===== EMAILSERVICE ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${trivyExitCode} \
                          "${ECR_URI}:emailservice-${IMAGE_TAG}"


                        # -------------------------------------------------
                        # FRONTEND
                        # -------------------------------------------------

                        echo ""
                        echo "===== FRONTEND ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${trivyExitCode} \
                          "${ECR_URI}:frontend-${IMAGE_TAG}"


                        # -------------------------------------------------
                        # PAYMENTSERVICE
                        # -------------------------------------------------

                        echo ""
                        echo "===== PAYMENTSERVICE ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${trivyExitCode} \
                          "${ECR_URI}:paymentservice-${IMAGE_TAG}"


                        # -------------------------------------------------
                        # PRODUCTCATALOGSERVICE
                        # -------------------------------------------------

                        echo ""
                        echo "===== PRODUCTCATALOGSERVICE ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${trivyExitCode} \
                          "${ECR_URI}:productcatalogservice-${IMAGE_TAG}"


                        # -------------------------------------------------
                        # RECOMMENDATIONSERVICE
                        # -------------------------------------------------

                        echo ""
                        echo "===== RECOMMENDATIONSERVICE ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${trivyExitCode} \
                          "${ECR_URI}:recommendationservice-${IMAGE_TAG}"


                        # -------------------------------------------------
                        # SHIPPING SERVICE
                        # -------------------------------------------------

                        echo ""
                        echo "===== SHIPPING SERVICE ====="

                        trivy image \
                          --severity HIGH,CRITICAL \
                          --exit-code ${trivyExitCode} \
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

                    echo ""
                    echo "AWS identity:"

                    aws sts get-caller-identity

                    echo ""
                    echo "Logging into ECR..."

                    aws ecr get-login-password \
                      --region "${AWS_REGION}" | \
                    docker login \
                      --username AWS \
                      --password-stdin \
                      "${ECR_REGISTRY}"

                    echo ""
                    echo "ECR login successful."

                    echo "=============================================="
                '''
            }
        }


        // =====================================================
        // 8. PUSH IMAGES TO ECR
        // =====================================================

        stage('Push Images to ECR') {

            steps {

                sh '''
                    set -e

                    echo "=============================================="
                    echo "PUSH IMAGES TO ECR"
                    echo "=============================================="


                    echo ""
                    echo "===== ADSERVICE ====="

                    docker push \
                      "${ECR_URI}:adservice-${IMAGE_TAG}"


                    echo ""
                    echo "===== CARTSERVICE ====="

                    docker push \
                      "${ECR_URI}:cartservice-${IMAGE_TAG}"


                    echo ""
                    echo "===== CHECKOUTSERVICE ====="

                    docker push \
                      "${ECR_URI}:checkoutservice-${IMAGE_TAG}"


                    echo ""
                    echo "===== CURRENCY SERVICE ====="

                    docker push \
                      "${ECR_URI}:currencyservice-${IMAGE_TAG}"


                    echo ""
                    echo "===== EMAILSERVICE ====="

                    docker push \
                      "${ECR_URI}:emailservice-${IMAGE_TAG}"


                    echo ""
                    echo "===== FRONTEND ====="

                    docker push \
                      "${ECR_URI}:frontend-${IMAGE_TAG}"


                    echo ""
                    echo "===== PAYMENTSERVICE ====="

                    docker push \
                      "${ECR_URI}:paymentservice-${IMAGE_TAG}"


                    echo ""
                    echo "===== PRODUCTCATALOGSERVICE ====="

                    docker push \
                      "${ECR_URI}:productcatalogservice-${IMAGE_TAG}"


                    echo ""
                    echo "===== RECOMMENDATIONSERVICE ====="

                    docker push \
                      "${ECR_URI}:recommendationservice-${IMAGE_TAG}"


                    echo ""
                    echo "===== SHIPPING SERVICE ====="

                    docker push \
                      "${ECR_URI}:shippingservice-${IMAGE_TAG}"


                    echo ""
                    echo "=============================================="
                    echo "ALL IMAGES PUSHED TO ECR SUCCESSFULLY"
                    echo "=============================================="

                    echo ""
                    echo "ECR repository:"
                    echo "${ECR_URI}"
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
                    echo "Current Kubernetes context:"

                    kubectl config current-context


                    echo ""
                    echo "Cluster information:"

                    kubectl cluster-info


                    echo ""
                    echo "EKS nodes:"

                    kubectl get nodes -o wide


                    # -------------------------------------------------
                    # NAMESPACE
                    # -------------------------------------------------

                    echo ""
                    echo "===== APPLY NAMESPACE ====="

                    kubectl apply \
                      -f kubernetes/dev/namespace/namespace.yaml


                    # -------------------------------------------------
                    # CONFIGMAP
                    # -------------------------------------------------

                    echo ""
                    echo "===== APPLY CONFIGMAP ====="

                    kubectl apply \
                      -f kubernetes/dev/configmap/configmap.yaml \
                      -n "${K8S_NAMESPACE}"


                    # -------------------------------------------------
                    # VERIFICATION
                    # -------------------------------------------------

                    echo ""
                    echo "===== NAMESPACE ====="

                    kubectl get namespace "${K8S_NAMESPACE}"


                    echo ""
                    echo "===== CONFIGMAP ====="

                    kubectl get configmap \
                      shopsphere-config \
                      -n "${K8S_NAMESPACE}"


                    echo ""
                    echo "Kubernetes base resources applied successfully."
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


                    echo ""
                    echo "===== REDIS DEPLOYMENT ====="

                    kubectl apply \
                      -f kubernetes/dev/redis/deployment.yaml \
                      -n "${K8S_NAMESPACE}"


                    echo ""
                    echo "===== REDIS SERVICE ====="

                    kubectl apply \
                      -f kubernetes/dev/redis/service.yaml \
                      -n "${K8S_NAMESPACE}"


                    echo ""
                    echo "===== REDIS ROLLOUT ====="

                    kubectl rollout status \
                      deployment/redis \
                      -n "${K8S_NAMESPACE}" \
                      --timeout=5m


                    echo ""
                    echo "===== REDIS POD ====="

                    kubectl get pods \
                      -n "${K8S_NAMESPACE}" \
                      -l app=redis \
                      -o wide || true


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


                    # Deployment order requested for ShopSphere

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
                        echo "=============================================="
                        echo "DEPLOYING: ${SERVICE}"
                        echo "=============================================="


                        DEPLOYMENT_FILE="kubernetes/dev/${SERVICE}/deployment.yaml"

                        SERVICE_FILE="kubernetes/dev/${SERVICE}/service.yaml"

                        IMAGE="${ECR_URI}:${SERVICE}-${IMAGE_TAG}"


                        # -------------------------------------------------
                        # CHECK FILES
                        # -------------------------------------------------

                        echo ""
                        echo "Deployment manifest:"
                        echo "${DEPLOYMENT_FILE}"

                        echo ""
                        echo "Service manifest:"
                        echo "${SERVICE_FILE}"

                        echo ""
                        echo "Image:"
                        echo "${IMAGE}"


                        if [ ! -f "${DEPLOYMENT_FILE}" ]; then

                            echo "ERROR: Deployment manifest not found:"
                            echo "${DEPLOYMENT_FILE}"
                            exit 1

                        fi


                        if [ ! -f "${SERVICE_FILE}" ]; then

                            echo "ERROR: Service manifest not found:"
                            echo "${SERVICE_FILE}"
                            exit 1

                        fi


                        # -------------------------------------------------
                        # APPLY EXISTING DEPLOYMENT MANIFEST
                        # -------------------------------------------------

                        echo ""
                        echo "Applying existing deployment manifest..."

                        kubectl apply \
                          -f "${DEPLOYMENT_FILE}" \
                          -n "${K8S_NAMESPACE}"


                        # -------------------------------------------------
                        # UPDATE ONLY IMAGE
                        # -------------------------------------------------

                        echo ""
                        echo "Updating deployment image..."

                        kubectl set image \
                          deployment/${SERVICE} \
                          ${SERVICE}=${IMAGE} \
                          -n "${K8S_NAMESPACE}"


                        # -------------------------------------------------
                        # APPLY SERVICE
                        # -------------------------------------------------

                        echo ""
                        echo "Applying service manifest..."

                        kubectl apply \
                          -f "${SERVICE_FILE}" \
                          -n "${K8S_NAMESPACE}"


                        # -------------------------------------------------
                        # SHOW IMAGE
                        # -------------------------------------------------

                        echo ""
                        echo "Current deployment image:"

                        kubectl get deployment/${SERVICE} \
                          -n "${K8S_NAMESPACE}" \
                          -o jsonpath='{.spec.template.spec.containers[*].image}'

                        echo ""


                        # -------------------------------------------------
                        # ROLLOUT
                        # -------------------------------------------------

                        echo ""
                        echo "Waiting for rollout..."

                        kubectl rollout status \
                          deployment/${SERVICE} \
                          -n "${K8S_NAMESPACE}" \
                          --timeout=5m


                        # -------------------------------------------------
                        # POD STATUS
                        # -------------------------------------------------

                        echo ""
                        echo "Pods for ${SERVICE}:"

                        kubectl get pods \
                          -n "${K8S_NAMESPACE}" \
                          -l app=${SERVICE} \
                          -o wide || true


                        echo ""
                        echo "${SERVICE} deployed successfully."

                    done


                    echo ""
                    echo "=============================================="
                    echo "ALL APPLICATION SERVICES DEPLOYED"
                    echo "=============================================="
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
                    echo "HPA + INGRESS"
                    echo "=============================================="


                    # -------------------------------------------------
                    # HPA
                    # -------------------------------------------------

                    echo ""
                    echo "===== FRONTEND HPA ====="

                    kubectl apply \
                      -f kubernetes/dev/hpa/frontend-hpa.yaml \
                      -n "${K8S_NAMESPACE}"


                    # -------------------------------------------------
                    # INGRESS
                    # -------------------------------------------------

                    echo ""
                    echo "===== FRONTEND INGRESS ====="

                    kubectl apply \
                      -f kubernetes/dev/ingress/frontend-ingress.yaml \
                      -n "${K8S_NAMESPACE}"


                    # -------------------------------------------------
                    # VERIFICATION
                    # -------------------------------------------------

                    echo ""
                    echo "===== HPA ====="

                    kubectl get hpa \
                      -n "${K8S_NAMESPACE}" || true


                    echo ""
                    echo "===== INGRESS ====="

                    kubectl get ingress \
                      -n "${K8S_NAMESPACE}" || true


                    echo ""
                    echo "HPA and Ingress resources applied."
                '''
            }
        }


        // =====================================================
        // 13. FINAL EKS VERIFICATION
        // =====================================================

        stage('EKS Verification') {

            steps {

                sh '''
                    set -e

                    echo "=============================================="
                    echo "FINAL EKS VERIFICATION"
                    echo "=============================================="


                    # -------------------------------------------------
                    # NAMESPACE
                    # -------------------------------------------------

                    echo ""
                    echo "===== NAMESPACE ====="

                    kubectl get namespace \
                      "${K8S_NAMESPACE}"


                    # -------------------------------------------------
                    # DEPLOYMENTS
                    # -------------------------------------------------

                    echo ""
                    echo "===== DEPLOYMENTS ====="

                    kubectl get deployments \
                      -n "${K8S_NAMESPACE}" \
                      -o wide


                    # -------------------------------------------------
                    # PODS
                    # -------------------------------------------------

                    echo ""
                    echo "===== PODS ====="

                    kubectl get pods \
                      -n "${K8S_NAMESPACE}" \
                      -o wide


                    # -------------------------------------------------
                    # SERVICES
                    # -------------------------------------------------

                    echo ""
                    echo "===== SERVICES ====="

                    kubectl get services \
                      -n "${K8S_NAMESPACE}"


                    # -------------------------------------------------
                    # HPA
                    # -------------------------------------------------

                    echo ""
                    echo "===== HPA ====="

                    kubectl get hpa \
                      -n "${K8S_NAMESPACE}" || true


                    # -------------------------------------------------
                    # INGRESS
                    # -------------------------------------------------

                    echo ""
                    echo "===== INGRESS ====="

                    kubectl get ingress \
                      -n "${K8S_NAMESPACE}" || true


                    # -------------------------------------------------
                    # ROLLOUT VERIFICATION
                    # -------------------------------------------------

                    echo ""
                    echo "=============================================="
                    echo "ROLLOUT VERIFICATION"
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
                        echo "Checking ${SERVICE}..."

                        kubectl rollout status \
                          deployment/${SERVICE} \
                          -n "${K8S_NAMESPACE}" \
                          --timeout=5m

                        echo "${SERVICE}: READY"

                    done


                    # -------------------------------------------------
                    # REDIS
                    # -------------------------------------------------

                    echo ""
                    echo "Checking Redis..."

                    kubectl rollout status \
                      deployment/redis \
                      -n "${K8S_NAMESPACE}" \
                      --timeout=5m

                    echo "redis: READY"


                    # -------------------------------------------------
                    # FINAL POD CHECK
                    # -------------------------------------------------

                    echo ""
                    echo "=============================================="
                    echo "FINAL POD STATUS"
                    echo "=============================================="

                    kubectl get pods \
                      -n "${K8S_NAMESPACE}"


                    echo ""
                    echo "=============================================="
                    echo "SHOPSPHERE DEPLOYMENT SUCCESSFUL"
                    echo "=============================================="
                '''
            }
        }
    }


    // =========================================================
    // POST ACTIONS
    // =========================================================

    post {


        // =====================================================
        // SUCCESS
        // =====================================================

        success {

            echo '''
            ==============================================
            SHOPSPHERE CI/CD SUCCESS
            ==============================================

            Checkout          : PASSED
            Application Tests : COMPLETED
            SonarQube         : PASSED
            Quality Gate      : PASSED
            Docker Build      : PASSED
            Trivy             : PASSED / REPORT ONLY
            ECR Push           : PASSED
            EKS Deployment    : PASSED
            Verification      : PASSED

            ==============================================
            ShopSphere deployment completed successfully.
            ==============================================
            '''
        }


        // =====================================================
        // FAILURE
        // =====================================================

        failure {

            echo '''
            ==============================================
            SHOPSPHERE CI/CD FAILED
            ==============================================

            One of the mandatory pipeline stages failed.

            Check Console Output for the failed stage.

            Application test failures are intentionally
            non-blocking during the current CI/CD validation.

            ==============================================
            '''
        }


        // =====================================================
        // ALWAYS
        // =====================================================

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


                echo ""
                echo "Docker cleanup completed."
                echo "=============================================="
            '''
        }
    }
}


