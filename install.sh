#!/bin/bash
# Скрипт установки Telemt через Docker
# Main repository https://github.com/An0nX/telemt-docker
# ⚠️ Внимание! Скрипт выполняет команды на сервере
# Использование: sh install.sh 

FOLDER="TELEMT"

echo "⚠️ Внимание! Этот скрипт выполнит команды на вашем сервере."
read -p "Продолжить? (y/N) " confirm < /dev/tty
if [ "$confirm" != "y" ]; then
    echo "Отмена."
    exit 1
fi
read -p "Domain name (Fake TLS): " domain < /dev/tty
TLS_DOMAIN="$domain"
# Создать папку и перейти в неё
mkdir -p "$FOLDER"
cd "$FOLDER" || exit

# Генерация случайного username (8 символов) и секретного ключа
USERNAME=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 8)
SECRET=$(openssl rand -hex 16)

# Создать telemt.toml
cat > telemt.toml <<EOF
# === General Settings ===
[general]
# ad_tag = "00000000000000000000000000000000"

[general.modes]
classic = false
secure = false
tls = true

# === Anti-Censorship & Masking ===
[censorship]
tls_domain = "$TLS_DOMAIN"

[access.users]
$USERNAME = "$SECRET"
EOF

# Создать docker-compose.yml
cat > docker-compose.yml <<EOF
services:
  telemt:
    image: whn0thacked/telemt-docker:latest
    container_name: telemt
    restart: unless-stopped

    # Telemt uses RUST_LOG for verbosity (optional)
    environment:
      RUST_LOG: "info"

    # Telemt reads config from CMD (default: /etc/telemt.toml)
    volumes:
      - ./telemt.toml:/etc/telemt.toml:ro

    ports:
      - "443:443/tcp"

    # Hardening
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    read_only: true
    tmpfs:
      - /tmp:rw,nosuid,nodev,noexec,size=16m

    # Resource limits (optional)
    deploy:
      resources:
        limits:
          cpus: "0.50"
          memory: 256M

    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
EOF


echo "==============================="
echo "TLS_DOMAIN: $TLS_DOMAIN"
echo "username: $USERNAME"
echo "secret: $SECRET"
echo "==============================="

# Запуск контейнера
docker compose up -d
docker compose logs -f
