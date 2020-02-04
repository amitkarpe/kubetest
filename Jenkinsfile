pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                echo 'Running build automation'
                sh 'make build'
            }
        }
        stage('Push') {
	    steps {
       		echo 'Pushing into Docker Hub'
		echo "${env.BUILD_NUMBER}"
//		sh 'echo "${env.BUILD_NUMBER}"'
//		sh 'docker push amitkarpe/nginx:"${env.BUILD_NUMBER}"'
		sh 'make push'
		}
	}
        stage('Run') {
	    steps {
		echo 'Running nginx on port 8081 in docker'
		sh 'make run'
	        }
	    }   
        stage('Test') {
	    steps {
		echo 'Test on localhost using curl command'
		sh 'make test'
	        }
        }
    }
}
