#!/bin/bash

TLS_DOMAIN="$1"
FOLDER="TELEMT"

# Создать папку и перейти в неё
mkdir -p "$FOLDER"
cd "$FOLDER" || exit

# Случайный username (8 символов)
USERNAME=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 8)

# Secret через openssl
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
      # If you enable metrics_port=9090 in config:
      # - "127.0.0.1:9090:9090/tcp"

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

echo "tls_domain: $TLS_DOMAIN"
echo "username: $USERNAME"
echo "secret: $SECRET"

docker compose up -d
docker compose logs -f
