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
                // Installs jq if not already present (Debian/Ubuntu and RedHat/CentOS compatible)
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
                dir('terraform') {
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                }
            }
        }
        stage('Get Terraform Outputs') {
            steps {
                dir('terraform') {
                    script {
                        // Example: get outputs and save to environment or files
                        def bastion_ip = sh(script: 'terraform output -raw bastion_ip', returnStdout: true).trim()
                        def mongo_private_ips = sh(script: 'terraform output -json mongo_private_ips | jq -r .[]', returnStdout: true).trim()
                        echo "Bastion IP: ${bastion_ip}"
                        echo "Mongo Private IPs: ${mongo_private_ips}"
                        // You can write to files or stash as needed for Ansible etc.
                    }
                }
            }
        }
        stage('Generate Ansible Inventory') {
            steps {
                // Your Ansible inventory generation logic here
                echo "Generating Ansible inventory..."
            }
        }
        stage('Run Ansible Playbook') {
            steps {
                // Your Ansible playbook run logic here
                echo "Running Ansible playbook..."
            }
        }
    }
    post {
        always {
            script {
                // Will always try to destroy infra if tfstate exists
                if (fileExists('terraform/terraform.tfstate')) {
                    echo "Cleaning up infrastructure: Running terraform destroy"
                    dir('terraform') {
                        sh 'terraform destroy -auto-approve'
                    }
                } else {
                    echo "No terraform state file found. Skipping destroy."
                }
            }
        }
    }
}