##  Блокирующие замечания

### 1. test-app не отображался в репозитории

**Проблема:** Папка `test-app` была git-submodule без файла `.gitmodules`, поэтому на GitHub отображалась как пустая ссылка.

**Решение:**
- Удалена запись submodule через `git rm --cached test-app`
- Файлы (`Dockerfile`, `index.html`, `.github/workflows/ci-cd.yml`) добавлены как обычные файлы репозитория
- Workflow перемещён в корень: `.github/workflows/ci-cd.yml` (GitHub Actions видит workflow только в корне)
- Исправлены пути в workflow: `context: ./test-app`, `file: ./test-app/Dockerfile`


---

### 2. Отсутствие Security Groups

**Проблема:** Все три ноды имели публичные IP без групп безопасности. Порт 6443 (Kubernetes API) был открыт в интернет.

**Решение:**
- Создан ресурс `yandex_vpc_security_group.k8s_sg` в `infra-main/main.tf`
- Настроены правила:
  - SSH (22) — только с IP администратора
  - Kubernetes API (6443) — IP администратора + диапазон для CI/CD
  - Внутренний трафик — только между подсетями кластера
  - NodePort (30000-32767) — открыт для приложений
- IP администратора определяется автоматически через `my_ip.auto.tfvars`


---

### 3. Пароли Grafana в публичном README

**Проблема:** Логин и пароль от Grafana (`admin` / `diploma-admin`) находились в открытом доступе.

**Решение:**
- Пароли удалены из `README.md` и `LINKS.md`
- Заменены на примечание "выдано проверяющему отдельно"
- Добавлен раздел о безопасности TLS в README

---

### 4. Небезопасный kubeconfig для CI/CD

**Проблема:** GitHub Actions использовал админский kubeconfig с `insecure-skip-tls-verify: true`, что давало полный cluster-admin доступ.

**Решение:**
- Создан отдельный `ServiceAccount` (`github-actions-deployer`) с ограниченными правами
- Настроена `Role`: только `get`, `list`, `patch`, `update` для deployments и pods в namespace `default`
- Сгенерирован токен сроком на 1 год через `kubectl create token`
- Секрет `KUBE_CONFIG` в GitHub обновлён на конфиг с ограниченным токеном
- Проверено: доступ к secrets возвращает `Forbidden` (принцип наименьших привилегий)

---

## Важные замечания

### 5. Хардкод IP-адресов в инвентаре Kubespray

**Проблема:** IP-адреса нод были захардкожены в скрипте, что ломало деплой при пересоздании инфраструктуры.

**Решение:**
- Добавлен файл `infra-main/outputs.tf` с экспортом IP-адресов
- Создан скрипт `scripts/generate_kubespray_inventory.sh`, который динамически получает IP через `terraform output` и генерирует `k8s/kubespray-inventory/hosts.yml`


---

### 6. Неправильный .gitignore

**Проблема:** `.terraform.lock.hcl` был в игноре (а его нужно коммитить), а `terraform.tfvars` — закоммичен.

**Решение:**
- Переписан `.gitignore`: lock-файлы коммитятся, tfvars и секреты игнорируются
- Закоммичены `.terraform.lock.hcl` для всех модулей

---

### 7. Манифесты Kubernetes в heredoc bash-скрипта

**Проблема:** Deployment, Service, Ingress были встроены в `deploy.sh` через heredoc, что делало невозможным code review.

**Решение:**
- Манифесты вынесены в отдельную директорию `k8s/`:
  - `deployment.yaml`, `service.yaml`, `ingress.yaml`, `ci-cd-rbac.yaml`
- `deploy.sh` теперь вызывает `kubectl apply -f k8s/`

---

### 8. Два разных deploy.sh

**Проблема:** В корне и в `scripts/` находились разные версии скрипта, которые расходились.

**Решение:**
- Удалён дубликат в корне проекта
- Оставлен единственный `scripts/deploy.sh`

---

### 9. destroy.sh удалял GitHub-репозиторий

**Проблема:** Скрипт уничтожения инфраструктуры содержал команду `gh repo delete`.

**Решение:**
- Полностью переписан `scripts/destroy.sh`
- Убрана команда удаления репозитория
- Добавлено подтверждение через `read -p` перед выполнением

---

## 📊 Итог

| Категория | До изменений | После изменений |
|-----------|--------------|-----------------|
| Security Groups | 0 | 5 правил |
| Пароли в README | 2 места | 0 |
| Права GitHub Actions | cluster-admin | только patch/get deployments |
| Манифесты в bash | 100% heredoc | отдельные YAML-файлы |
| deploy.sh файлов | 2 (расходятся) | 1 |
| Хардкод IP | есть | динамическая генерация |
| Коммитов | 1 | 15+ |
