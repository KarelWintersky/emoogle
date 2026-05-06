#!/bin/bash
#
# Deploy script for https://github.com/KarelWintersky/emoogle
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
RESET='\033[0m' # No Color

PACKAGE_URL="https://github.com/KarelWintersky/emoji-finder/releases/"
PACKAGE_NAME=$(basename "$PACKAGE_URL")
PACKAGE_ROOT="/opt/emoji-search-site"

# Функция для вывода информационных сообщений
log_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

# Функция для вывода успешных сообщений
log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

# Функция для вывода предупреждений
log_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Функция для вывода ошибок
log_error() {
    echo -e "${RED}❌${NC} $1"
}

# Функция проверки последней команды
check_status() {
    if [ $? -eq 0 ]; then
        log_success "$1"
    else
        log_error "$2"
        exit 1
    fi
}

# Not supported now
download_and_install_package() {
    local TEMP_DIR="/tmp/emoji-deploy-$$"

    echo "📦 Attempting to download required package from:"
    echo "   $PACKAGE_URL"

    # Создаем временную директорию
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"

    # Скачиваем пакет
    if wget -q --show-progress "$PACKAGE_URL" -O "$PACKAGE_NAME"; then
        echo "✅ Package downloaded successfully"

        # Устанавливаем пакет
        echo "💾 Installing package with dpkg..."
        if sudo dpkg -i "$PACKAGE_NAME"; then
            echo "✅ Package installed successfully"
        else
            echo "❌ Failed to install package"
            echo "💡 Attempting to fix dependencies..."
            sudo apt-get install -f -y
            if [ $? -eq 0 ]; then
                echo "✅ Dependencies fixed, package should be installed"
            else
                echo "❌ Could not resolve dependencies"
                echo "⚠️  Continuing deployment, but performance may be unstable"
            fi
        fi
    else
        echo "❌ Failed to download package from: $PACKAGE_URL"
        echo "⚠️  Continuing without the package - performance may be impacted"
    fi

    # Очистка
    cd /
    rm -rf "$TEMP_DIR"

    # Даем пользователю время прочитать сообщение
    sleep 3
}

check_requirements() {
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_mb=$((total_ram_kb / 1024))

    echo "🔍 Checking system requirements..."
    echo "📊 Total RAM detected: ${total_ram_mb} MB"
    if [ $total_ram_mb -lt 1024 ]; then
        echo "⚠️  WARNING: Insufficient RAM (${total_ram_mb} MB < 1024 MB)"
        echo "   This application requires at least 1 GB of RAM."

#        echo "Do you want to install it via dpkg? (y/n)"
#        read -r answer
#        if [[ "$answer" =~ ^[Yy]$ ]]; then
#            download_and_install_package
#        else
#            echo "❌ Installation cancelled. Cannot proceed without sufficient RAM."
#            exit 1
#        fi
        exit 1
    else
        echo "✅ System meets minimum RAM requirements (${total_ram_mb} MB >= 1024 MB)"
    fi
}

# Функция обновления системы
update_system() {
    log_info "Обновление системы..."
    sudo apt update && sudo apt upgrade -y
    check_status "Система обновлена" "Ошибка при обновлении системы"

    log_info "Установка необходимых пакетов..."
    sudo apt install -y curl wget git build-essential
    check_status "Пакеты установлены" "Ошибка при установке пакетов"
}

# Функция установки Node.js 25
install_nodejs() {
    log_info "Установка Node.js 25 через Nodesource..."
    curl -fsSL https://deb.nodesource.com/setup_25.x | sudo -E bash -
    check_status "Репозиторий Nodesource добавлен" "Ошибка при добавлении репозитория Nodesource"

    sudo apt install -y nodejs
    check_status "Node.js установлен" "Ошибка при установке Node.js"

    log_info "Версия Node.js: $(node --version)"
    log_info "Версия npm: $(npm --version)"
}

# Функция создания пользователя и директорий
create_user_and_directories() {
    log_info "Создание пользователя emojiapp..."
    sudo useradd -m -s /bin/bash emojiapp || true
    check_status "Пользователь создан" "Ошибка при создании пользователя"

    log_info "Создание директории ${PACKAGE_ROOT}..."
    sudo mkdir -p ${PACKAGE_ROOT}
    sudo chown emojiapp:emojiapp ${PACKAGE_ROOT}
    check_status "Директория создана" "Ошибка при создании директории"
}

# Функция клонирования репозитория и установки зависимостей
clone_and_install() {
    log_info "Клонирование репозитория и установка зависимостей..."
    sudo -u emojiapp bash -c "
        cd ${PACKAGE_ROOT}
        rm -rf .git *
        git clone https://github.com/KarelWintersky/emoogle.git .
        npm install
    "
    check_status "Репозиторий склонирован и зависимости установлены" \
                 "Ошибка при клонировании или установке зависимостей"
}

# Функция сборки для продакшена
build_production() {
    log_info "Сборка проекта для продакшена..."
    sudo -u emojiapp bash -c "
        cd ${PACKAGE_ROOT}
        npm run build
        rm -rf .next/standalone/.next/static .next/standalone/public
        ln -s ../../../.next/static .next/standalone/.next/static
        ln -s ../../public .next/standalone/public 2>/dev/null || true
        npm prune --production
        rm -rf .next/cache
        rm -rf node_modules
    "
    check_status "Сборка завершена успешно" "Ошибка при сборке проекта"
}

create_systemd_service() {
    log_info "Создание systemd сервиса..."
    sudo tee ${PACKAGE_ROOT}/emoji-search.service > /dev/null <<EOF
[Unit]
Description=Emoji Search Site
After=network.target

[Service]
Type=simple
User=emojiapp
Group=emojiapp
WorkingDirectory=${PACKAGE_ROOT}
Environment=NODE_ENV=production
Environment=NEXT_TELEMETRY_DISABLED=1
Environment="HOST=0.0.0.0"
ExecStart=/usr/bin/node --max-old-space-size=4096 ${PACKAGE_ROOT}/.next/standalone/server.js
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=3
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=emoji-search
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    check_status "systemd сервис создан" "Ошибка при создании systemd сервиса"

    # Создаём симлинк в systemd директорию
    sudo ln -sf ${PACKAGE_ROOT}/emoji-search.service /etc/systemd/system/emoji-search.service
    check_status "Симлинк создан в /etc/systemd/system/" "Ошибка при создании симлинка"
}

# Функция запуска и включения сервиса
start_and_enable_service() {
    log_info "Перезагрузка systemd и запуск сервиса..."
    sudo systemctl daemon-reload
    check_status "systemd перезагружен" "Ошибка при перезагрузке systemd"

    sudo systemctl enable emoji-search.service
    check_status "Сервис добавлен в автозагрузку" "Ошибка при добавлении в автозагрузку"

    sudo systemctl start emoji-search.service
    check_status "Сервис запущен" "Ошибка при запуске сервиса"
}

# Функция проверки статуса сервиса
check_service_status() {
    log_info "Проверка статуса сервиса..."
    sleep 3 # Даем время сервису запуститься

    if sudo systemctl is-active --quiet emoji-search.service; then
        log_success "Сервис активен и работает"
        sudo systemctl status emoji-search.service --no-pager -l
    else
        log_error "Сервис не активен"
        sudo systemctl status emoji-search.service --no-pager -l
        log_warning "Логи сервиса:"
        sudo journalctl -u emoji-search.service -n 20 --no-pager
        exit 1
    fi
}

# Функция проверки порта
check_port() {
    log_info "Проверка порта 3000..."
    if sudo ss -tulpn | grep -q ":3000"; then
        log_success "Порт 3000 прослушивается"
        sudo ss -tulpn | grep :3000
    else
        log_warning "Порт 3000 не прослушивается"
    fi
}

# Функция получения IP адреса
get_server_ip() {
    local SERVER_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1)

    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
    fi

    echo "$SERVER_IP"
}

# Функция вывода информации о завершении
print_completion_info() {
    local SERVER_IP=$(get_server_ip)

    echo ""
    echo "========================================="
    log_success "✅ Deploy completed!"
    echo "========================================="
    echo ""
    log_info "🌐 Service listens on: ${GREEN}http://${SERVER_IP}:3000${NC}"
    echo ""
    log_info "📋 Useful commands:"
    echo -e "   Check service status:    ${YELLOW}sudo systemctl status emoji-search.service${NC}"
    echo -e "   Restart service:         ${YELLOW}sudo systemctl restart emoji-search.service${NC}"
    echo -e "   Stop service:            ${YELLOW}sudo systemctl stop emoji-search.service${NC}"
    echo -e ""
    echo -e "   View systemd logs:       ${YELLOW}journalctl -u emoji-search.service -f${NC}"
    echo -e "   View last 100 log lines: ${YELLOW}journalctl -u emoji-search.service -n 100 --no-pager${NC}"
    echo ""
}

# Функция обновления кода из репозитория
# Функция обновления кода из репозитория
update_code() {
    log_info "Обновление кода из репозитория..."

    sudo -u emojiapp bash -c "
        cd ${PACKAGE_ROOT}
        git fetch origin
        git reset --hard origin/\$(git branch --show-current)
    "

    check_status "Код обновлен из репозитория" "Ошибка при обновлении кода"
}

install() {
    echo "🚀 Deploying Emoji Search Site on Node.js 25 + systemd..."
    echo "=========================================================="
    echo ""

    update_system
    install_nodejs
    create_user_and_directories
    clone_and_install
    build_production
    create_systemd_service
    start_and_enable_service
    check_port
    print_completion_info
}

# Функция переустановки
reinstall() {
    log_warning "Переустановка приложения..."
    uninstall
    install
}

# Функция обновления (без переустановки)
update() {
    log_info "Обновление приложения..."

    if [ ! -d "${PACKAGE_ROOT}/.git" ]; then
        log_error "Приложение не установлено. Сначала выполните установку."
        exit 1
    fi

    update_code
    build_production
    restart_service
    check_port
    print_completion_info
}

# Функция удаления
uninstall() {
    log_warning "Удаление приложения..."

    # Останавливаем и отключаем сервис
    if systemctl is-active --quiet emoji-search.service 2>/dev/null; then
        sudo systemctl stop emoji-search.service
        log_success "Сервис остановлен"
    fi

    if systemctl is-enabled --quiet emoji-search.service 2>/dev/null; then
        sudo systemctl disable emoji-search.service
        log_success "Сервис отключен из автозагрузки"
    fi

    # Удаляем файлы сервиса
    sudo rm -f /etc/systemd/system/emoji-search.service
    sudo systemctl daemon-reload
    log_success "Файлы сервиса удалены"

    # Удаляем директорию приложения
    if [ -d "${PACKAGE_ROOT}" ]; then
        sudo rm -rf ${PACKAGE_ROOT}
        log_success "Директория приложения удалена"
    fi

    # Опционально: удаляем пользователя
    if id "emojiapp" &>/dev/null; then
        userdel emojiapp
        log_warning "Пользователь emojiapp не был удален (можно удалить вручную: sudo userdel emojiapp)"
    fi

    log_success "Приложение полностью удалено"
}

# Функция отображения меню
show_menu() {
    clear
    echo "========================================="
    echo "   🚀 ${GREEN}Emoji Search Site Deployment Tool${RESET}"
    echo "========================================="
    echo ""
    echo "Выберите действие:"
    echo ""
    echo "  1) Install / Reinstall - Полная установка или переустановка"
    echo "  2) Update - Обновление кода и пересборка"
    echo "  3) Remove - Полное удаление приложения"
    echo "  4) Exit - Выход"
    echo ""
    echo "========================================="
    echo -n "Ваш выбор [1-4]: "
    read -r choice

    case $choice in
        1)
            echo ""
            if [ -d "${PACKAGE_ROOT}" ] && [ -f "/etc/systemd/system/emoji-search.service" ]; then
                echo "⚠️  Приложение уже установлено."
                echo -n "Вы хотите выполнить переустановку? (y/n): "
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    reinstall
                else
                    log_info "Операция отменена"
                    exit 0
                fi
            else
                install
            fi
            ;;
        2)
            update
            ;;
        3)
            echo ""
            echo "⚠️  ВНИМАНИЕ: Это действие полностью удалит приложение и все его данные!"
            echo -n "Вы уверены, что хотите продолжить? (y/n): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                uninstall
            else
                log_info "Операция отменена"
                exit 0
            fi
            ;;
        4)
            log_info "Выход из программы"
            exit 0
            ;;
        *)
            log_error "Неверный выбор. Пожалуйста, выберите 1, 2, 3 или 4"
            exit 1
            ;;
    esac
}

# Запуск меню

show_menu

