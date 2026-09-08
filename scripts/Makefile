.PHONY: help deploy destroy status logs clean

# Цвета
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

help: ## Показать эту справку
	@echo ""
	@echo -e "$(BLUE)DIPLOM DEVOPS - Makefile$(NC)"
	@echo ""
	@echo -e "Использование: make [target]"
	@echo ""
	@echo -e "Доступные команды:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

deploy: ## Полное развертывание проекта
	@echo -e "$(GREEN)Запуск полного деплоя...$(NC)"
	./deploy.sh

destroy: ## Полное уничтожение инфраструктуры
	@echo -e "$(YELLOW)Запуск уничтожения...$(NC)"
	./destroy.sh

status: ## Показать статус кластера
	@echo -e "$(BLUE)Статус нод:$(NC)"
	@kubectl get nodes
	@echo ""
	@echo -e "$(BLUE)Статус подов:$(NC)"
	@kubectl get pods -A
	@echo ""
	@echo -e "$(BLUE)Сервисы:$(NC)"
	@kubectl get svc -A

logs: ## Показать логи подов приложения
	@kubectl logs -f deployment/diploma-test-app -n default

clean: ## Очистка временных файлов
	@echo -e "$(YELLOW)Очистка временных файлов...$(NC)"
	@find . -name "*.tfplan" -delete
	@find . -name ".terraform" -type d -exec rm -rf {} +
	@find . -name "terraform.tfstate.backup" -delete
	@echo -e "$(GREEN)Очистка завершена$(NC)"

test-app: ## Открыть тестовое приложение в браузере
	@MASTER_IP=$$(cat ~/Netology/DiplomDevOps/master_ip.txt 2>/dev/null || echo "111.88.250.212")
	@echo -e "$(GREEN)Открываем приложение: http://$$MASTER_IP:32040/app$(NC)"
	@xdg-open "http://$$MASTER_IP:32040/app" 2>/dev/null || echo "Откройте вручную: http://$$MASTER_IP:32040/app"

grafana: ## Открыть Grafana в браузере
	@MASTER_IP=$$(cat ~/Netology/DiplomDevOps/master_ip.txt 2>/dev/null || echo "111.88.250.212")
	@echo -e "$(GREEN)Открываем Grafana: http://$$MASTER_IP:32040/grafana$(NC)"
	@xdg-open "http://$$MASTER_IP:32040/grafana" 2>/dev/null || echo "Откройте вручную: http://$$MASTER_IP:32040/grafana"

github: ## Открыть GitHub Actions в браузере
	@echo -e "$(GREEN)Открываем GitHub Actions...$(NC)"
	@xdg-open "https://github.com/Relekt71/DiplomDevOps/actions" 2>/dev/null || echo "Откройте вручную: https://github.com/Relekt71/DiplomDevOps/actions"

scale-up: ## Увеличить количество реплик приложения до 5
	@echo -e "$(BLUE)Масштабируем приложение до 5 реплик...$(NC)"
	@kubectl scale deployment/diploma-test-app --replicas=5 -n default
	@echo -e "$(GREEN)Готово!$(NC)"

scale-down: ## Уменьшить количество реплик приложения до 2
	@echo -e "$(BLUE)Масштабируем приложение до 2 реплик...$(NC)"
	@kubectl scale deployment/diploma-test-app --replicas=2 -n default
	@echo -e "$(GREEN)Готово!$(NC)"

restart: ## Перезапустить приложение
	@echo -e "$(YELLOW)Перезапускаем приложение...$(NC)"
	@kubectl rollout restart deployment/diploma-test-app -n default
	@echo -e "$(GREEN)Перезапуск инициирован$(NC)"

history: ## Показать историю деплоев
	@kubectl rollout history deployment/diploma-test-app -n default

rollback: ## Откатить деплой на предыдущую версию
	@echo -e "$(YELLOW)Откатываем деплой...$(NC)"
	@kubectl rollout undo deployment/diploma-test-app -n default
	@echo -e "$(GREEN)Откат выполнен$(NC)"
