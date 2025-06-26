pipeline {
    agent any
    parameters {
        booleanParam(name: 'DESTROY_INFRA_ONLY', defaultValue: false, description: 'Destroy infrastructure only (skip all other stages)')
    }
    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        TF_VAR_aws_access_key = credentials('AWS_ACCESS_KEY_ID')
        TF_VAR_aws_secret_key = credentials('AWS_SECRET_ACCESS_KEY')
        TF_VAR_ssh_key_name   = 'ubuntu-slave-jen'
    }
    stages {
        stage('Destroy Infra') {
            when {
                expression { params.DESTROY_INFRA_ONLY }
            }
            steps {
                script {
                    if (fileExists('terraform/terraform.tfstate')) {
                        echo "Destroying infrastructure as requested..."
                        dir('terraform') {
                            sh 'terraform destroy -auto-approve || true'
                        }
                    } else {
                        echo "No terraform.tfstate found. Nothing to destroy."
                    }
                }
            }
        }
        stage('Install Dependencies') {
            when {
                expression { !params.DESTROY_INFRA_ONLY }
            }
            steps {
                sh '''
                    if ! command -v jq >/dev/null 2>&1; then
                        if command -v apt-get >/dev/null 2>&1; then
                            sudo apt-get update && sudo apt-get install -y jq
                        elif command -v yum >/dev/null 2>&1; then
                            sudo yum install -y jq
                        else
                            echo "Neither apt-get nor yum found. Please install jq manually."
                            exit 1
                        fi
                    fi
                '''
            }
        }
        stage('Terraform Init & Apply') {
            when {
                expression { !params.DESTROY_INFRA_ONLY }
            }
            steps {
                script {
                    dir('terraform') {
                        try {
                            sh 'terraform init'
                            sh 'terraform apply -auto-approve'
                        } catch (e) {
                            if (fileExists('terraform.tfstate')) {
                                currentBuild.description = "INFRA_ERROR"
                            }
                            throw e
                        }
                    }
                }
            }
        }
        stage('Get Terraform Outputs') {
            when {
                expression { !params.DESTROY_INFRA_ONLY && fileExists('terraform/terraform.tfstate') }
            }
            steps {
                script {
                    dir('terraform') {
                        def bastion_ip = sh(script: 'terraform output -raw bastion_ip', returnStdout: true).trim()
                        def mongo_private_ips = sh(script: 'terraform output -json mongo_private_ips | jq -r .[]', returnStdout: true).trim().split('\n')
                        env.BASTION_IP = bastion_ip
                        env.MONGO_PRIVATE_IPS = mongo_private_ips.join(',')
                    }
                    echo "BASTION_IP is: '${env.BASTION_IP}'"
                    echo "MONGO_PRIVATE_IPS is: '${env.MONGO_PRIVATE_IPS}'"
                    if (!env.BASTION_IP) { error("BASTION_IP is not set!") }
                    if (!env.MONGO_PRIVATE_IPS) { error("MONGO_PRIVATE_IPS is not set!") }
                }
            }
        }
        stage('Wait for Bastion SSH') {
            when {
                expression { !params.DESTROY_INFRA_ONLY && env.BASTION_IP }
            }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ANSIBLE_SSH_KEY', keyFileVariable: 'KEY')]) {
                    script {
                        echo "About to SSH to bastion at: '${env.BASTION_IP}'"
                        sh "ls -l ${KEY}"
                        def max_retries = 15
                        def delay_sec = 10
                        def bastion_ready = false
                        for (int i = 0; i < max_retries; i++) {
                            def rc = sh(
                                script: """
                                    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ${KEY} ubuntu@${env.BASTION_IP} "echo bastion_ready"
                                """,
                                returnStatus: true
                            )
                            if (rc == 0) {
                                echo "Bastion is reachable via SSH."
                                bastion_ready = true
                                break
                            } else {
                                echo "Waiting for bastion SSH... retry ${i+1}/${max_retries}"
                                sleep delay_sec
                            }
                        }
                        if (!bastion_ready) {
                            error("Bastion not reachable via SSH after ${max_retries} attempts.")
                        }
                    }
                }
            }
        }
        stage('Generate Ansible Inventory') {
            when {
                expression { !params.DESTROY_INFRA_ONLY && env.BASTION_IP && env.MONGO_PRIVATE_IPS }
            }
            steps {
                dir('ansible') {
                    script {
                        def mongo_ips = env.MONGO_PRIVATE_IPS.split(',')
                        def host_entries = ""
                        for (int idx = 0; idx < mongo_ips.size(); idx++) {
                            def ip = mongo_ips[idx]
                            host_entries += "mongo${idx+1} ansible_host=${ip} ansible_user=ubuntu\n"
                        }
                        def inventory = "[mongo]\n${host_entries}"
                        writeFile file: 'inventory.ini', text: inventory
                        echo "Generated Ansible inventory:"
                        echo inventory
                    }
                }
            }
        }
        stage('Debug SSH through Bastion') {
            when {
                expression { !params.DESTROY_INFRA_ONLY && env.BASTION_IP && env.MONGO_PRIVATE_IPS }
            }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ANSIBLE_SSH_KEY', keyFileVariable: 'KEY')]) {
                    script {
                        def bastion_ip = env.BASTION_IP
                        def mongo_ips = env.MONGO_PRIVATE_IPS.split(',')
                        for (int idx = 0; idx < mongo_ips.size(); idx++) {
                            def ip = mongo_ips[idx]
                            sh """
                                echo "Testing SSH to mongo${idx+1} (${ip}) via bastion..."
                                ssh -vvv -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i ${KEY} -o StrictHostKeyChecking=no -W %h:%p ubuntu@${bastion_ip}" -i ${KEY} ubuntu@${ip} 'echo SSH_OK'
                            """
                        }
                    }
                }
            }
        }
        stage('Run Ansible Playbook') {
            when {
                expression { !params.DESTROY_INFRA_ONLY && env.BASTION_IP && env.MONGO_PRIVATE_IPS }
            }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ANSIBLE_SSH_KEY', keyFileVariable: 'KEY')]) {
                    dir('ansible') {
                        sh """
                            export ANSIBLE_SSH_ARGS='-o ProxyCommand="ssh -i \$KEY -o StrictHostKeyChecking=no -W %h:%p ubuntu@${env.BASTION_IP}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
                            ansible all -i inventory.ini -m ping -u ubuntu --private-key="\$KEY" -vvvv
                            ansible-playbook -i inventory.ini -u ubuntu --private-key="\$KEY" -f 1 mongodb-replica.yml
                        """
                    }
                }
            }
        }
    }
    post {
        failure {
            script {
                def infraCreated = fileExists('terraform/terraform.tfstate')
                def infraError   = currentBuild.description == "INFRA_ERROR"
                if (infraCreated || infraError) {
                    echo "Pipeline failed or error during infra creation. Destroying infrastructure..."
                    dir('terraform') {
                        sh 'terraform destroy -auto-approve || true'
                    }
                } else {
                    echo "No infrastructure to destroy."
                }
            }
        }
        aborted {
            script {
                if (fileExists('terraform/terraform.tfstate')) {
                    echo "Pipeline aborted. Destroying infrastructure..."
                    dir('terraform') {
                        sh 'terraform destroy -auto-approve || true'
                    }
                }
            }
        }
    }
}