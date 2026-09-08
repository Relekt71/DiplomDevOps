#!/bin/bash
set -euo pipefail

# ============================================
# DIPLOM DEVOPS - ПОЛНЫЙ DESTROY SCRIPT
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    exit 1
}

# Подтверждение
echo "=========================================="
echo -e "${RED}  ВНИМАНИЕ! ЭТО УДАЛИТ ВСЮ ИНФРАСТРУКТУРУ!"
echo "=========================================="
echo ""
read -p "Вы уверены? (да/нет): " confirm

if [ "$confirm" != "да" ]; then
    echo "Операция отменена."
    exit 0
fi

# Шаг 1: Удаление GitHub репозитория (опционально)
destroy_github() {
    log "=== ШАГ 1: Удаление GitHub репозитория ==="
    
    if command -v gh &> /dev/null; then
        read -p "Удалить GitHub репозиторий Relekt71/DiplomDevOps? (да/нет): " gh_confirm
        if [ "$gh_confirm" = "да" ]; then
            gh repo delete Relekt71/DiplomDevOps --yes
            success "GitHub репозиторий удален"
        fi
    else
        warn "gh CLI не установлен. Удалите репозиторий вручную."
    fi
}

# Шаг 2: Удаление Container Registry
destroy_registry() {
    log "=== ШАГ 2: Удаление Container Registry ==="
    
    if [ -f ~/Netology/DiplomDevOps/registry_id.txt ]; then
        REGISTRY_ID=$(cat ~/Netology/DiplomDevOps/registry_id.txt)
        
        cd ~/Netology/DiplomDevOps/infra-registry
        terraform destroy -auto-approve
        
        success "Registry удален"
    else
        warn "registry_id.txt не найден. Пропускаем."
    fi
}

# Шаг 3: Удаление инфраструктуры
destroy_infrastructure() {
    log "=== ШАГ 3: Удаление инфраструктуры ==="
    
    cd ~/Netology/DiplomDevOps/infra-main
    terraform destroy -auto-approve
    
    success "Инфраструктура удалена"
}

# Шаг 4: Очистка локальных файлов
cleanup_local() {
    log "=== ШАГ 4: Очистка локальных файлов ==="
    
    rm -f ~/Netology/DiplomDevOps/master_ip.txt
    rm -f ~/Netology/DiplomDevOps/registry_id.txt
    rm -f ~/Netology/DiplomDevOps/registry_sa_id.txt
    rm -f ~/Netology/DiplomDevOps/registry-key.json
    
    success "Локальные файлы очищены"
}

# Главная функция
main() {
    echo ""
    log "Начинаем уничтожение инфраструктуры..."
    echo ""
    
    destroy_github
    destroy_registry
    destroy_infrastructure
    cleanup_local
    
    echo ""
    echo "=========================================="
    success "DESTROY ЗАВЕРШЕН УСПЕШНО!"
    echo "=========================================="
    echo ""
}

main "$@"
