# Дипломный проект DevOps - Полная автоматизация инфраструктуры и CI/CD

##  Описание проекта

Полностью автоматизированная инфраструктура в Яндекс.Облаке с Kubernetes кластером, мониторингом и CI/CD пайплайном.

##  Архитектура

┌─────────────────────────────────────────────────────────────┐
│                    Yandex Cloud (ru-central1)                │
├─────────────────────────────────────────────────────────────┤
│  VPC: diploma-network                                       │
│  ├── Subnet A (10.10.0.0/16) - ru-central1-a               │
│  │   ├── k8s-master (10.10.0.5, Public: 51.250.73.33)     │
│  │   └── k8s-worker-0 (10.10.0.32, Public: NAT)           │
│  ├── Subnet B (10.11.0.0/16) - ru-central1-b               │
│  │   └── k8s-worker-1 (10.11.0.9, Public: NAT)            │
│  └── Container Registry: crpht3918eo252ctvgjn               │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (v1.30.4)              │
├─────────────────────────────────────────────────────────────┤
│  Control Plane: node1 (k8s-master)                          │
│  Workers: node2, node3                                      │
│  Network: Calico                                            │
│  DNS: CoreDNS                                               │
│  Monitoring: Prometheus + Grafana                           │
│  Ingress: nginx-ingress-controller                          │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                    CI/CD Pipeline (GitHub Actions)           │
├─────────────────────────────────────────────────────────────┤
│  Trigger: Git tag (v*)                                      │
│  1. Build Docker image                                      │
│  2. Push to Yandex Container Registry                       │
│  3. Deploy to Kubernetes (rolling update)                   │
└─────────────────────────────────────────────────────────────┘

##  Структура проекта

DiplomDevOps/
├── infra-bootstrap/       # Terraform для начальной инфраструктуры (backend, SA)
├── infra-main/           # Terraform для ВМ и сетей
├── infra-registry/       # Terraform для Container Registry
├── test-app/             # Тестовое приложение + Dockerfile + CI/CD
│   ├── .github/workflows/ci-cd.yml
│   ├── Dockerfile
│   └── index.html
├── scripts/              # Автоматизация деплоя
│   ├── deploy.sh
│   └── destroy.sh
└── README.md


##  Быстрый старт

### 1. Развертывание инфраструктуры

	cd infra-main
	terraform init
	terraform plan
	terraform apply

### 2. Установка Kubernetes

	cd scripts
	make deploy

### 3. Доступ к приложениям

    Тестовое приложение: http://51.250.73.33:32042
    Grafana: http://51.250.73.33:32040/grafana
        Логин: admin
        Пароль: diploma-admin

## Технологии

    Infrastructure as Code: Terraform (Yandex Cloud Provider)
    Configuration Management: Ansible (Kubespray)
    Container Orchestration: Kubernetes v1.30.4
    Container Runtime: containerd
    Network Plugin: Calico
    Monitoring: Prometheus + Grafana (kube-prometheus-stack)
    CI/CD: GitHub Actions
    Container Registry: Yandex Container Registry
    Ingress Controller: nginx-ingress

## Мониторинг

Grafana доступна по адресу: http://51.250.73.33:32040/grafana
Дашборды:

    Kubernetes Cluster Monitoring
    Node Exporter
    CoreDNS
    NGINX Ingress Controller

## CI/CD Pipeline

### Автоматический деплой при создании тега:

	git tag v1.0.0
	git push origin v1.0.0
	
### GitHub Actions автоматически:

    Собирает Docker образ
    Отправляет в Yandex Container Registry
    Обновляет Deployment в Kubernetes (rolling update)

### История деплоев:

	kubectl rollout history deployment/diploma-test-app

### Безопасность

    SSH ключи хранятся в .gitignore
    Секреты GitHub Actions используются для аутентификации
    Service Account с минимальными правами (puller/pusher)
    Port 6443 открыт только для GitHub Actions (Security Group)

### Примеры использования
Проверка статуса кластера:

	kubectl get nodes
	kubectl get pods -A
	
### Просмотр логов приложения:

	kubectl logs -l app=diploma-test-app

### Масштабирование приложения:

	kubectl scale deployment/diploma-test-app --replicas=3
	
## Скриншоты:

Инфраструктура: terraform plan и yc compute instance list

Kubernetes: kubectl get nodes и kubectl get pods -A

Мониторинг: Открыть Grafana в браузере

CI/CD: Создать тег v1.0.9 и показать автоматический деплой в GitHub Actions

Rollback: kubectl rollout undo deployment/diploma-test-app

