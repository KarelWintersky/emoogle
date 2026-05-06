#!/bin/bash
set -euo pipefail

echo "🚀 Deploying Emoji Search Site on Node.js 25 + systemd..."

# 1) Обновление системы
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git build-essential

# 2) Node.js 25 через Nodesource
curl -fsSL https://deb.nodesource.com/setup_25.x | sudo -E bash -
sudo apt install -y nodejs

# Проверка версии
node --version
npm --version

# 3) Создание пользователя для приложения
sudo useradd -m -s /bin/bash emojiapp || true
sudo mkdir -p /opt/emoji-search-site
sudo chown emojiapp:emojiapp /opt/emoji-search-site

# 4) Клонирование и сборка
sudo -u emojiapp bash -c "
  cd /opt/emoji-search-site
  git init
  git remote add origin https://github.com/KarelWintersky/emoogle.git
  git fetch origin main
  git checkout main
  git pull origin main
"

# Если нет GitHub-репо, создай проект локально:
sudo -u emojiapp bash -c "
  cd /opt/emoji-search-site
  npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias '@/*'
  npm install emoogle-emoji-search-engine
"

# 5) Сборка для продакшена
sudo -u emojiapp bash -c "
  cd /opt/emoji-search-site
  npm ci --only=production
  npm run build
"

# 6) Создание systemd-сервиса
sudo tee /etc/systemd/system/emoji-search.service > /dev/null <<EOF
[Unit]
Description=Emoji Search Site (Next.js)
After=network.target

[Service]
Type=simple
User=emojiapp
Group=emojiapp
WorkingDirectory=/opt/emoji-search-site
Environment=NODE_ENV=production
ExecStart=/usr/bin/node --max-old-space-size=4096 /opt/emoji-search-site/.next/standalone/server.js
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

# 7) Перезапуск systemd и запуск сервиса
sudo systemctl daemon-reload
sudo systemctl enable emoji-search.service
sudo systemctl start emoji-search.service

# 8) Проверка статуса
sudo systemctl status emoji-search.service --no-pager
sudo ss -tulpn | grep :3000

echo "✅ Deploy completed!"
echo "📡 Service listens on localhost:3000"
echo "🔍 Logs: journalctl -u emoji-search.service -f"
echo "🔄 Restart: systemctl restart emoji-search.service"