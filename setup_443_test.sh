#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Настройка тестового сервера на порту 443${NC}"
echo -e "${GREEN}========================================${NC}"

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Ошибка: Запустите скрипт с sudo${NC}"
    echo "Пример: sudo ./setup_443_test.sh"
    exit 1
fi

# 1. Открываем порт 443 в фаерволе
echo -e "\n${YELLOW}[1/8] Открываем порт 443 в UFW...${NC}"
ufw allow 443/tcp
echo -e "${GREEN}✓ Порт 443 открыт${NC}"

# 2. Обновляем пакеты
echo -e "\n${YELLOW}[2/8] Обновление списка пакетов...${NC}"
apt update -qq

# 3. Устанавливаем nginx
echo -e "\n${YELLOW}[3/8] Установка nginx...${NC}"
apt install nginx -y -qq
echo -e "${GREEN}✓ Nginx установлен${NC}"

# 4. Создаем тестовую HTML-страницу
echo -e "\n${YELLOW}[4/8] Создание тестовой HTML-страницы...${NC}"
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>IP White Test</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        .success { color: green; font-size: 24px; }
        .info { color: blue; margin-top: 20px; }
    </style>
</head>
<body>
    <h1 class="success">Test successful!</h1>
    <p>Port 443 is finally working.</p>
    <p class="info">Your IP: <strong id="ip"></strong></p>
    <script>
        fetch('https://api.ipify.org?format=json')
            .then(r => r.json())
            .then(data => document.getElementById('ip').textContent = data.ip);
    </script>
</body>
</html>
EOF
echo -e "${GREEN}✓ Тестовая страница создана${NC}"

# 5. Создаем конфигурацию nginx
echo -e "\n${YELLOW}[5/8] Настройка конфигурации nginx...${NC}"
cat > /etc/nginx/sites-available/test << 'EOF'
server {
    listen 443 default_server;
    listen [::]:443 default_server;
    server_name _;
    root /var/www/html;
    index index.html;
    
    # Добавляем заголовки для диагностики
    add_header X-Test-Header "Port-443-Works" always;
    add_header Access-Control-Allow-Origin "*" always;
}
EOF
echo -e "${GREEN}✓ Конфигурация создана${NC}"

# 6. Активируем сайт и удаляем дефолтный
echo -e "\n${YELLOW}[6/8] Активация сайта...${NC}"
ln -sf /etc/nginx/sites-available/test /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
echo -e "${GREEN}✓ Сайт активирован${NC}"

# 7. Проверяем конфигурацию и перезапускаем nginx
echo -e "\n${YELLOW}[7/8] Проверка конфигурации nginx...${NC}"
if nginx -t 2>/dev/null; then
    echo -e "${GREEN}✓ Конфигурация корректна${NC}"
    systemctl restart nginx
    echo -e "${GREEN}✓ Nginx перезапущен${NC}"
else
    echo -e "${RED}✗ Ошибка в конфигурации nginx${NC}"
    nginx -t
    exit 1
fi

# 8. Тестируем локально
echo -e "\n${YELLOW}[8/8] Локальное тестирование...${NC}"
sleep 2

# Получаем IP сервера
SERVER_IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || echo "не определен")

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Установка завершена успешно!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "Тестируем локально через curl:"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:443 | grep -q "200"; then
    echo -e "${GREEN}✓ Локальный тест пройден (HTTP 200)${NC}"
else
    echo -e "${YELLOW}⚠ Локальный тест не дал 200 ответа${NC}"
fi

echo -e "\n${GREEN}Для проверки с телефона:${NC}"
echo -e "1. Отключите Wi-Fi на телефоне"
echo -e "2. Включите мобильный интернет (МТС/Мегафон)"
echo -e "3. Откройте в браузере: ${YELLOW}http://${SERVER_IP}:443${NC}\n"

echo -e "${YELLOW}Если сайт открывается — IP белый!${NC}"
echo -e "${RED}Если нет — IP серый или порт заблокирован${NC}\n"

# Показываем статус сервиса
echo -e "${YELLOW}Статус nginx:${NC}"
systemctl status nginx --no-pager -l | head -5

echo -e "\n${YELLOW}Для остановки сервера выполните:${NC}"
echo "  sudo systemctl stop nginx"
echo "  sudo ufw delete allow 443"
