pipeline {
    agent any
    environment {
    AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    TF_VAR_aws_access_key = credentials('AWS_ACCESS_KEY_ID')
    TF_VAR_aws_secret_key = credentials('AWS_SECRET_ACCESS_KEY')
    TF_VAR_ssh_key_name   = 'ubuntu-slave-jen'
    ANSIBLE_PRIVATE_KEY   = credentials('ANSIBLE_SSH_KEY')
    INFRA_CREATED         = "false"
}
    stages {
        stage('Terraform Init & Apply') {
            steps {
                dir('terraform') {
                    script {
                        try {
                            sh 'terraform init'
                            sh 'terraform apply -auto-approve'
                            env.INFRA_CREATED = "true"
                        } catch (e) {
                            error("Terraform apply failed: ${e}")
                        }
                    }
                }
            }
        }
        stage('Generate Ansible Inventory') {
            steps {
                script {
                    def bastion_ip = sh(script: "terraform -chdir=terraform output -raw bastion_ip", returnStdout: true).trim()
                    def ips = sh(script: "terraform -chdir=terraform output -json mongo_private_ips | jq -r '.[]'", returnStdout: true).trim().split("\n")
                    def inventory = "[mongo]\n"
                    ips.eachWithIndex { ip, idx ->
                        inventory += "mongo${idx+1} ansible_host=${ip} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/.ssh/ubuntu-slave-jen ansible_ssh_common_args='-o ProxyCommand=\"ssh -i /home/ubuntu/.ssh/ubuntu-slave-jen -W %h:%p ubuntu@${bastion_ip}\"'\n"
                    }
                    writeFile file: 'ansible/inventory.ini', text: inventory
                }
            }
        }
        stage('Run Ansible Playbook') {
            steps {
                sh '''
                ansible-playbook -i ansible/inventory.ini ansible/mongodb-replica.yml --private-key=$ANSIBLE_PRIVATE_KEY
                '''
            }
        }
    }
    post {
        failure {
            script {
                if (env.INFRA_CREATED == "true") {
                    echo "Pipeline failed after infrastructure creation. Destroying infrastructure..."
                    dir('terraform') {
                        sh 'terraform destroy -auto-approve'
                    }
                }
            }
        }
        aborted {
            script {
                if (env.INFRA_CREATED == "true") {
                    echo "Pipeline was aborted after infrastructure creation. Destroying infrastructure..."
                    dir('terraform') {
                        sh 'terraform destroy -auto-approve'
                    }
                }
            }
        }
    }
}