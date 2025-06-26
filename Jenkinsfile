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
                            // Set a flag if infra was created (terraform.tfstate exists)
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
                        // Save as environment variables for later stages
                        env.BASTION_IP = bastion_ip
                        env.MONGO_PRIVATE_IPS = mongo_private_ips.join(',')
                        // Optionally show output
                        echo "Bastion IP: ${bastion_ip}"
                        echo "Mongo Private IPs: ${mongo_private_ips}"
                    }
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
                        def inventory = """
[bastion]
${env.BASTION_IP}

[mongodb]
${env.MONGO_PRIVATE_IPS.replace(',', '\n')}
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
                // Only run destroy if infra was created or flagged as errored
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
        // Optionally, always clean up for dev/test stacks:
        // always {
        //     script {
        //         if (fileExists('terraform/terraform.tfstate')) {
        //             echo "Always: Cleaning up infrastructure..."
        //             dir('terraform') {
        //                 sh 'terraform destroy -auto-approve || true'
        //             }
        //         }
        //     }
        // }
    }
}