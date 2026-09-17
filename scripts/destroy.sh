#!/bin/bash
set -e

echo "WARNING: This action will irreversibly destroy all infrastructure in Yandex Cloud!"
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Operation canceled."
    exit 1
fi

echo "Destroying Terraform resources..."
cd infra-main
terraform destroy -auto-approve

echo "Infrastructure successfully destroyed."
echo "Remember to manually delete Container Registry and Service Accounts in Yandex Cloud console if they were created separately."
