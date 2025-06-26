pipeline {
    agent any
    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        TF_VAR_aws_access_key = credentials('AWS_ACCESS_KEY_ID')
        TF_VAR_aws_secret_key = credentials('AWS_SECRET_ACCESS_KEY')
        TF_VAR_ssh_key_name   = 'ubuntu-slave-jen'
        ANSIBLE_PRIVATE_KEY   = credentials('ANSIBLE_SSH_KEY')
    }
    stages {
        stage('Install Dependencies') {
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
                expression { fileExists('terraform/terraform.tfstate') }
            }
            steps {
                dir('terraform') {
                    script {
                        def bastion_ip = sh(script: 'terraform output -raw bastion_ip', returnStdout: true).trim()
                        def mongo_private_ips = sh(script: 'terraform output -json mongo_private_ips | jq -r .[]', returnStdout: true).trim().split('\n')
                        env.BASTION_IP = bastion_ip
                        env.MONGO_PRIVATE_IPS = mongo_private_ips.join(',')
                        echo "Bastion IP: ${bastion_ip}"
                        echo "Mongo Private IPs: ${mongo_private_ips}"
                    }
                }
            }
        }
        stage('Copy SSH Key to Bastion') {
            when {
                expression { env.BASTION_IP }
            }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ANSIBLE_SSH_KEY', keyFileVariable: 'KEY')]) {
                    sh '''
                        echo "Copying SSH key to Bastion server..."
                        scp -o StrictHostKeyChecking=no -i $KEY $KEY ubuntu@$BASTION_IP:~/mongo-key.pem
                        ssh -o StrictHostKeyChecking=no -i $KEY ubuntu@$BASTION_IP "chmod 600 ~/mongo-key.pem"
                    '''
                }
            }
        }
        stage('Generate Ansible Inventory') {
            when {
                expression { env.BASTION_IP && env.MONGO_PRIVATE_IPS }
            }
            steps {
                dir('ansible') {
                    script {
                        def bastion = env.BASTION_IP
                        def ssh_key = "~/mongo-key.pem"
                        def host_entries = env.MONGO_PRIVATE_IPS.split(',').withIndex().collect { ip, idx ->
                            "mongo${idx+1} ansible_host=${ip} ansible_user=ubuntu ansible_ssh_private_key_file=${ssh_key} ansible_ssh_common_args='-o ProxyCommand=\"ssh -i ${ssh_key} -o StrictHostKeyChecking=no -W %h:%p ubuntu@${bastion}\"'"
                        }.join('\n')

                        def inventory = """
[mongo]
${host_entries}
"""
                        writeFile file: 'inventory.ini', text: inventory
                        echo "Generated Ansible inventory:"
                        echo inventory
                    }
                }
            }
        }
        stage('Run Ansible Playbook') {
            when {
                expression { env.BASTION_IP && env.MONGO_PRIVATE_IPS }
            }
            steps {
                dir('ansible') {
                    sh '''
                        ansible-playbook -i inventory.ini -u ubuntu --private-key="$ANSIBLE_PRIVATE_KEY" mongodb-replica.yml
                    '''
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