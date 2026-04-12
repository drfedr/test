#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Установка Docker и 3x-ui${NC}"
echo -e "${GREEN}========================================${NC}"

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Ошибка: Запустите скрипт с sudo${NC}"
    echo "Пример: sudo ./install_3x-ui.sh"
    exit 1
fi

# 1. Обновляем пакеты
echo -e "\n${YELLOW}[1/7] Обновление списка пакетов...${NC}"
apt update -qq

# 2. Устанавливаем зависимости
echo -e "\n${YELLOW}[2/7] Установка зависимостей...${NC}"
apt install ca-certificates curl -y -qq
echo -e "${GREEN}✓ Зависимости установлены${NC}"

# 3. Добавляем GPG ключ Docker
echo -e "\n${YELLOW}[3/7] Добавление GPG ключа Docker...${NC}"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo -e "${GREEN}✓ GPG ключ добавлен${NC}"

# 4. Добавляем репозиторий Docker
echo -e "\n${YELLOW}[4/7] Добавление репозитория Docker...${NC}"
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
echo -e "${GREEN}✓ Репозиторий добавлен${NC}"

# 5. Устанавливаем Docker
echo -e "\n${YELLOW}[5/7] Установка Docker...${NC}"
apt update -qq
apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y -qq
echo -e "${GREEN}✓ Docker установлен${NC}"

# 6. Создаем директории для данных и сертификатов
echo -e "\n${YELLOW}[6/7] Создание директорий...${NC}"
mkdir -p "$PWD/db"
mkdir -p "$PWD/cert"
echo -e "${GREEN}✓ Директории созданы:${NC}"
echo "  - $PWD/db"
echo "  - $PWD/cert"

# 7. Запускаем контейнер 3x-ui
echo -e "\n${YELLOW}[7/7] Запуск контейнера 3x-ui...${NC}"

# Проверяем, не запущен ли уже контейнер
if [ "$(docker ps -q -f name=3x-ui)" ]; then
    echo -e "${YELLOW}Контейнер 3x-ui уже запущен. Останавливаем...${NC}"
    docker stop 3x-ui
    docker rm 3x-ui
fi

# Запускаем новый контейнер
sudo docker run -itd \
   -e XRAY_VMESS_AEAD_FORCED=false \
   -v $PWD/db/:/etc/x-ui/ \
   -v $PWD/cert/:/root/cert/ \
   --network=host \
   --restart=unless-stopped \
   --name 3x-ui \
   ghcr.io/mhsanaei/3x-ui:latest

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Контейнер 3x-ui успешно запущен${NC}"
else
    echo -e "${RED}✗ Ошибка при запуске контейнера${NC}"
    exit 1
fi

# Получаем IP сервера
SERVER_IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || echo "не определен")

# Выводим информацию
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Установка завершена успешно!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${BLUE}Информация для доступа к панели:${NC}"
echo -e "  Адрес: ${GREEN}http://${SERVER_IP}:2053${NC}"
echo -e "  Логин: ${GREEN}admin${NC}"
echo -e "  Пароль: ${GREEN}admin${NC}"
echo -e "  ${YELLOW}⚠ Обязательно смените пароль после первого входа!${NC}"

echo -e "\n${BLUE}Полезные команды:${NC}"
echo -e "  Просмотр логов: ${GREEN}docker logs -f 3x-ui${NC}"
echo -e "  Перезапуск:     ${GREEN}docker restart 3x-ui${NC}"
echo -e "  Остановка:      ${GREEN}docker stop 3x-ui${NC}"
echo -e "  Удаление:       ${GREEN}docker rm -f 3x-ui${NC}"

echo -e "\n${BLUE}Директории с данными:${NC}"
echo -e "  База данных:    ${GREEN}$PWD/db${NC}"
echo -e "  Сертификаты:    ${GREEN}$PWD/cert${NC}"

# Проверяем статус контейнера
echo -e "\n${YELLOW}Статус контейнера:${NC}"
docker ps --filter "name=3x-ui" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\n${GREEN}Готово! Панель доступна по адресу: http://${SERVER_IP}:2053${NC}"
