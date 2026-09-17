#!/bin/bash
set -e

echo "ВНИМАНИЕ: Это действие необратимо удалит всю инфраструктуру в Яндекс.Облаке!"
read -p "Вы уверены, что хотите продолжить? (введите 'yes' для подтверждения): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Операция отменена."
    exit 1
fi

echo "Уничтожение ресурсов Terraform..."
cd infra-main
terraform destroy -auto-approve

echo "Инфраструктура успешно уничтожена."
echo "Не забудьте вручную удалить Container Registry и Service Accounts в консоли Яндекс.Облака, если они создавались отдельно."
