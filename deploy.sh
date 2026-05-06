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
  rm -rf .git *
  git clone https://github.com/KarelWintersky/emoogle.git .
  npm install
"

# 5) Сборка для продакшена
sudo -u emojiapp bash -c "
  cd /opt/emoji-search-site
  npm run build
  rm -rf .next/standalone/.next/static .next/standalone/public
  ln -s ../../../.next/static .next/standalone/.next/static
  ln -s ../../public .next/standalone/public 2>/dev/null || true
  npm prune --production
  rm -rf .next/cache
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
Environment=NEXT_TELEMETRY_DISABLED=1
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

SERVER_IP=$(ip a s | grep -oP '(?<=inet\s)\d+(\.\d+){3}(?=/)' | grep -v 127.0.0.1 | head -1)
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="localhost"
fi

echo "✅ Deploy completed!"
echo "📡 Service listens on http://${SERVER_IP}:3000"
echo "🔄 Restart: systemctl restart emoji-search.service"
echo "🔍 Logs: journalctl -u emoji-search.service -f"
echo ""