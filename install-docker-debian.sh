#!/bin/bash
# ----------------------------------------------------------
# Instalador Automático: Docker + Docker Compose
# Para Debian 12/13 (arm64 e amd64)
# Compatível com Raspberry Pi 4 (ARM)
# wget -qO - https://raw.githubusercontent.com/italofreitasM/docker/main/install-docker-debian.sh | sudo bash
#
# Autor: Italo Freitas (italofreitas2222@gmail.com)
# ----------------------------------------------------------
set -e

clear

### Funções auxiliares ###
error() {
    echo "ERRO: $1"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script precisa ser executado como root ou via sudo."
    fi
}

check_internet() {
    echo "[CHECK] Testando conexão com a internet..."
    if ! ping -c 1 google.com &> /dev/null; then
        error "Sem conexão com a internet."
    fi
}

check_debian() {
    if [[ ! -f /etc/debian_version ]]; then
        error "Este script só funciona no Debian."
    fi
}

### INÍCIO ###
echo "======================================"
echo " INSTALADOR DOCKER PARA DEBIAN 12/13"
echo "======================================"

check_root
check_internet
check_debian

# 1) Remover versões antigas
echo "[1/7] Removendo versões antigas..."
apt remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

# 2) Atualizar sistema e instalar dependências
echo "[2/7] Instalando dependências..."
apt update -y
apt install -y ca-certificates curl gnupg lsb-release

# 3) Chave GPG do Docker
echo "[3/7] Configurando chave GPG..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# 4) Repositório Docker
echo "[4/7] Adicionando repositório Docker..."
CODENAME=$( . /etc/os-release && echo $VERSION_CODENAME )
ARCH=$( dpkg --print-architecture )

echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $CODENAME stable" \
> /etc/apt/sources.list.d/docker.list

# 5) Instalar Docker + Compose
echo "[5/7] Instalando Docker Engine + Compose..."
apt update -y
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6) Habilitar Docker
echo "[6/7] Ativando Docker..."
systemctl enable docker
systemctl start docker

# 7) Testar instalação
echo "[7/7] Testando instalação..."
docker --version || error "Docker não instalado."
docker compose version || error "Docker Compose não instalado."

echo ""
echo "=============================================="
echo " Docker + Docker Compose instalados com sucesso!"
echo "=============================================="
echo ""
echo "⚙️ Para usar Docker sem sudo, execute:"
echo "   usermod -aG docker \$USER"
echo ""
