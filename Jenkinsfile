pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build and Deploy') {
            when {
                anyOf {
                    branch 'dev'
                    branch 'master'
                }
            }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x
                        echo "$DOCKERHUB_TOKEN" | docker login \
                            --username "$DOCKERHUB_USER" \
                            --password-stdin

                        chmod +x build.sh deploy.sh

                        ./build.sh

                        if [ "$BRANCH_NAME" = "master" ]; then
                            docker rm -f guvi-react-app 2>/dev/null || true
                        fi

                        BRANCH_NAME="$BRANCH_NAME" ./deploy.sh

                        docker logout
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "CI/CD completed successfully for ${BRANCH_NAME}"
        }
        failure {
            echo "CI/CD failed for ${BRANCH_NAME}. Check the console output."
        }
    }
}
