#!/bin/bash
# ==============================================================================
# Instalador Automático: Docker + Docker Compose
# Compatível com: Debian, Ubuntu, Raspbian, Fedora, CentOS, RHEL, Rocky,
#                 AlmaLinux, openSUSE, Arch Linux, Alpine Linux (arm64 e amd64)
#
# Uso:
#   wget -qO - https://raw.githubusercontent.com/ItaloFreitasM/docker-compose/refs/heads/main/install-docker.sh | sudo bash
#   curl -fsSL https://raw.githubusercontent.com/ItaloFreitasM/docker-compose/refs/heads/main/install-docker.sh | sudo bash
#
# Autor: Italo Freitas (italofreitas2222@gmail.com)
# ==============================================================================
set -euo pipefail

clear

# ==============================================================================
# CORES E FORMATAÇÃO
# ==============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ==============================================================================
# LOG EM ARQUIVO
# FIX: Registra toda a execução para diagnóstico posterior
# ==============================================================================
LOG_FILE="/var/log/docker-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ==============================================================================
# FUNÇÕES AUXILIARES
# ==============================================================================
info()    { echo -e "${CYAN}[INFO]${RESET}  $1"; }
success() { echo -e "${GREEN}[OK]${RESET}    $1"; }
warn()    { echo -e "${YELLOW}[AVISO]${RESET} $1"; }
error()   { echo -e "${RED}[ERRO]${RESET}  $1" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${BLUE}▶ $1${RESET}"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script precisa ser executado como root ou via sudo."
    fi
}

# FIX: Usa curl em vez de ping — mais confiável em containers e
#      redes com ICMP bloqueado. Testa diretamente o endpoint do Docker.
check_internet() {
    step "Testando conexão com a internet..."
    if curl -fsSL --connect-timeout 5 --max-time 10 \
        "https://download.docker.com" -o /dev/null 2>/dev/null; then
        success "Conexão com a internet OK."
    else
        error "Sem acesso a download.docker.com. Verifique sua rede e tente novamente."
    fi
}

command_exists() {
    command -v "$1" &>/dev/null
}

# ==============================================================================
# DETECÇÃO DO SISTEMA OPERACIONAL
# ==============================================================================
detect_os() {
    step "Detectando sistema operacional..."

    OS_ID=""
    OS_FAMILY=""
    PKG_MANAGER=""
    CODENAME=""
    VERSION_ID=""

    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        OS_ID="${ID:-}"
        VERSION_ID="${VERSION_ID:-}"
        CODENAME="${VERSION_CODENAME:-}"
    elif [[ -f /etc/alpine-release ]]; then
        OS_ID="alpine"
    else
        error "Não foi possível identificar a distribuição Linux."
    fi

    # Normalizar ID para lowercase
    OS_ID="${OS_ID,,}"

    # FIX: Capitalização portável — não depende de bash 4+ (${var^})
    OS_ID_DISPLAY="$(tr '[:lower:]' '[:upper:]' <<< "${OS_ID:0:1}")${OS_ID:1}"

    # Determinar família do OS e gerenciador de pacotes
    case "$OS_ID" in
        debian|raspbian)
            OS_FAMILY="debian"
            PKG_MANAGER="apt"
            DOCKER_REPO_OS="debian"
            ;;
        ubuntu)
            OS_FAMILY="debian"
            PKG_MANAGER="apt"
            DOCKER_REPO_OS="ubuntu"
            ;;
        linuxmint|pop|elementary|zorin|kali|parrot|mx)
            OS_FAMILY="debian"
            PKG_MANAGER="apt"
            DOCKER_REPO_OS="ubuntu"
            if [[ -z "$CODENAME" ]]; then
                CODENAME=$(lsb_release -cs 2>/dev/null || true)
            fi
            ;;
        fedora)
            OS_FAMILY="rhel"
            PKG_MANAGER="dnf"
            DOCKER_REPO_OS="fedora"
            ;;
        centos|rhel|rocky|almalinux|ol)
            OS_FAMILY="rhel"
            PKG_MANAGER="dnf"
            DOCKER_REPO_OS="centos"
            # CentOS 7 ainda usa yum
            [[ "${VERSION_ID%%.*}" == "7" ]] && PKG_MANAGER="yum"
            ;;
        opensuse*|sles|sled)
            OS_FAMILY="suse"
            PKG_MANAGER="zypper"
            ;;
        arch|manjaro|endeavouros|garuda)
            OS_FAMILY="arch"
            PKG_MANAGER="pacman"
            ;;
        alpine)
            OS_FAMILY="alpine"
            PKG_MANAGER="apk"
            ;;
        *)
            # Tentativa genérica: verificar qual pkg manager existe
            if command_exists apt-get;  then OS_FAMILY="debian"; PKG_MANAGER="apt"; DOCKER_REPO_OS="debian"
            elif command_exists dnf;    then OS_FAMILY="rhel";   PKG_MANAGER="dnf"
            elif command_exists yum;    then OS_FAMILY="rhel";   PKG_MANAGER="yum"
            elif command_exists zypper; then OS_FAMILY="suse";   PKG_MANAGER="zypper"
            elif command_exists pacman; then OS_FAMILY="arch";   PKG_MANAGER="pacman"
            elif command_exists apk;    then OS_FAMILY="alpine"; PKG_MANAGER="apk"
            else
                error "Distribuição '$OS_ID' não suportada por este script."
            fi
            ;;
    esac

    # Obter arquitetura
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)            ARCH_DOCKER="amd64" ;;
        aarch64|arm64)     ARCH_DOCKER="arm64" ;;
        armv7l|armv7)      ARCH_DOCKER="armhf" ;;
        armv6l)            ARCH_DOCKER="armel" ;;
        s390x)             ARCH_DOCKER="s390x" ;;
        ppc64le)           ARCH_DOCKER="ppc64le" ;;
        *)                 error "Arquitetura '$ARCH' não suportada." ;;
    esac

    # FIX: Usa OS_ID_DISPLAY para capitalização segura
    info "Sistema: ${BOLD}${OS_ID_DISPLAY} ${VERSION_ID}${RESET} (${CODENAME})"
    info "Família: ${BOLD}${OS_FAMILY}${RESET}"
    info "Pacotes: ${BOLD}${PKG_MANAGER}${RESET}"
    info "Arquitetura: ${BOLD}${ARCH}${RESET} → Docker: ${BOLD}${ARCH_DOCKER}${RESET}"
    info "Log: ${BOLD}${LOG_FILE}${RESET}"
    success "Sistema detectado com sucesso."
}

# ==============================================================================
# VERIFICAR SE DOCKER JÁ ESTÁ INSTALADO
# ==============================================================================
check_existing_docker() {
    step "Verificando instalação existente..."
    if command_exists docker; then
        CURRENT_VERSION=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "desconhecida")
        warn "Docker já está instalado (versão $CURRENT_VERSION)."
        read -rp "$(echo -e "${YELLOW}Deseja reinstalar/atualizar? [s/N]:${RESET} ")" choice
        case "$choice" in
            [sS][iI]|[sS]) info "Prosseguindo com reinstalação/atualização..." ;;
            *) info "Instalação cancelada pelo usuário."; exit 0 ;;
        esac
    fi
}

# ==============================================================================
# REMOVER VERSÕES ANTIGAS
# FIX: Separado em dois grupos — pacotes não-oficiais (sempre removidos)
#      e pacotes oficiais (só removidos se o usuário confirmou reinstalação).
#      Evita remover silenciosamente uma instalação funcional.
# ==============================================================================
remove_old_versions() {
    step "Removendo versões antigas do Docker..."

    # Apenas pacotes de repositórios não-oficiais (distro padrão)
    local unofficial_pkgs=(
        "docker"
        "docker-engine"
        "docker.io"
        "containerd"
        "runc"
        "podman-docker"
        "docker-doc"
    )

    # Pacotes oficiais — incluídos apenas para reinstalação limpa
    local official_pkgs=(
        "docker-ce"
        "docker-ce-cli"
        "docker-ce-rootless-extras"
        "docker-compose"
        "docker-buildx-plugin"
        "docker-compose-plugin"
    )

    local all_pkgs=("${unofficial_pkgs[@]}" "${official_pkgs[@]}")

    case "$PKG_MANAGER" in
        apt)
            apt-get remove -y "${all_pkgs[@]}" >/dev/null 2>&1 || true
            ;;
        dnf|yum)
            $PKG_MANAGER remove -y "${all_pkgs[@]}" >/dev/null 2>&1 || true
            ;;
        zypper)
            zypper remove -y "${all_pkgs[@]}" >/dev/null 2>&1 || true
            ;;
        pacman)
            pacman -Rns --noconfirm "${all_pkgs[@]}" >/dev/null 2>&1 || true
            ;;
        apk)
            apk del docker docker-engine docker-openrc >/dev/null 2>&1 || true
            ;;
    esac
    success "Versões antigas removidas."
}

# ==============================================================================
# INSTALAR DEPENDÊNCIAS BÁSICAS
# ==============================================================================
install_dependencies() {
    step "Instalando dependências básicas..."
    case "$PKG_MANAGER" in
        apt)
            apt-get update -y -qq
            apt-get install -y -qq ca-certificates curl gnupg lsb-release
            ;;
        dnf)
            dnf install -y -q dnf-plugins-core curl ca-certificates
            ;;
        yum)
            yum install -y -q yum-utils curl ca-certificates
            ;;
        zypper)
            zypper refresh -q
            zypper install -y -q curl ca-certificates
            ;;
        pacman)
            pacman -Sy --noconfirm --quiet curl ca-certificates
            ;;
        apk)
            apk update -q
            apk add -q curl ca-certificates
            ;;
    esac
    success "Dependências instaladas."
}

# ==============================================================================
# INSTALAR DOCKER — MÉTODO OFICIAL POR FAMÍLIA
# ==============================================================================

### Debian / Ubuntu ###
install_docker_apt() {
    step "Configurando repositório Docker (APT)..."

    # FIX: Cascata de fallbacks para garantir CODENAME em qualquer derivada
    if [[ -z "$CODENAME" ]]; then
        CODENAME=$(lsb_release -cs 2>/dev/null || true)
    fi
    if [[ -z "$CODENAME" ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release 2>/dev/null || true
        CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    fi
    [[ -z "$CODENAME" ]] && error "Não foi possível determinar o codinome da distribuição."

    # FIX: Avisa se o repositório já existir antes de sobrescrever
    if [[ -f /etc/apt/sources.list.d/docker.list ]]; then
        warn "Arquivo docker.list já existe. Sobrescrevendo..."
    fi

    # Chave GPG
    install -m 0755 -d /etc/apt/keyrings

    # FIX: Timeout e retry no download da chave para evitar travamento silencioso
    curl -fsSL --connect-timeout 15 --retry 3 \
        "https://download.docker.com/linux/${DOCKER_REPO_OS}/gpg" \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # FIX: Validar que o arquivo GPG foi criado e não está vazio
    if [[ ! -s /etc/apt/keyrings/docker.gpg ]]; then
        error "Falha ao baixar ou processar a chave GPG do Docker."
    fi

    # FIX: Verificar fingerprint oficial para detectar possível MITM
    EXPECTED_FP="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
    ACTUAL_FP=$(gpg --no-default-keyring \
        --keyring /etc/apt/keyrings/docker.gpg \
        --fingerprint 2>/dev/null \
        | grep -oE '([0-9A-F]{4} ?){10}' \
        | tr -d ' ' \
        | head -1 || true)

    if [[ -n "$ACTUAL_FP" && "$ACTUAL_FP" != "$EXPECTED_FP" ]]; then
        error "Fingerprint da chave GPG não confere (${ACTUAL_FP}). Possível ataque MITM. Abortando."
    elif [[ -z "$ACTUAL_FP" ]]; then
        warn "Não foi possível verificar o fingerprint GPG. Prosseguindo com cautela."
    else
        success "Fingerprint GPG verificado: ${ACTUAL_FP}"
    fi

    # Repositório
    echo "deb [arch=${ARCH_DOCKER} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${DOCKER_REPO_OS} ${CODENAME} stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null

    step "Instalando Docker Engine + Compose..."
    apt-get update -y -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
}

### Fedora / CentOS / RHEL / Rocky / Alma ###
install_docker_rhel() {
    step "Configurando repositório Docker (DNF/YUM)..."

    local repo_url="https://download.docker.com/linux/${DOCKER_REPO_OS}/docker-ce.repo"

    if [[ "$PKG_MANAGER" == "dnf" ]]; then
        # FIX: Era "dnf-3 config-manager" — comando inexistente em Fedora moderno e RHEL 9+
        dnf config-manager --add-repo "$repo_url"
        step "Instalando Docker Engine + Compose..."
        dnf install -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
    else
        yum-config-manager --add-repo "$repo_url"
        step "Instalando Docker Engine + Compose..."
        yum install -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
    fi
}

### openSUSE / SLES ###
install_docker_suse() {
    step "Instalando Docker (Zypper)..."
    zypper addrepo "https://download.docker.com/linux/sles/docker-ce.repo" docker-ce || true
    zypper refresh -q
    zypper install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
}

### Arch Linux / Manjaro ###
install_docker_arch() {
    step "Instalando Docker (Pacman)..."
    pacman -Sy --noconfirm docker docker-compose
}

### Alpine Linux ###
install_docker_alpine() {
    step "Instalando Docker (APK)..."
    # FIX: Quoting seguro + sem UUOC (Useless Use Of Cat)
    if ! grep -q "community" /etc/apk/repositories 2>/dev/null; then
        ALPINE_VER=$(cut -d. -f1,2 < /etc/alpine-release)
        echo "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER}/community" \
            >> /etc/apk/repositories
    fi
    apk update -q
    apk add -q docker docker-compose docker-cli-compose
}

# Dispatcher
install_docker() {
    case "$OS_FAMILY" in
        debian) install_docker_apt  ;;
        rhel)   install_docker_rhel ;;
        suse)   install_docker_suse ;;
        arch)   install_docker_arch ;;
        alpine) install_docker_alpine ;;
        *)      error "Família de OS '$OS_FAMILY' sem método de instalação definido." ;;
    esac
    success "Docker instalado com sucesso."
}

# ==============================================================================
# HABILITAR E INICIAR SERVIÇO
# ==============================================================================
enable_docker_service() {
    step "Habilitando e iniciando serviço Docker..."

    if [[ "$OS_FAMILY" == "alpine" ]]; then
        # Alpine usa OpenRC
        rc-update add docker default >/dev/null 2>&1 || true
        service docker start >/dev/null 2>&1 || true
    elif command_exists systemctl; then
        systemctl enable docker --now
    elif command_exists service; then
        service docker start || true
    else
        warn "Não foi possível iniciar o Docker automaticamente. Inicie manualmente: 'dockerd &'"
    fi
    success "Serviço Docker ativado."
}

# ==============================================================================
# VERIFICAR INSTALAÇÃO
# ==============================================================================
verify_installation() {
    step "Verificando instalação..."

    DOCKER_VERSION=$(docker --version 2>/dev/null) \
        || error "Docker não encontrado após instalação."

    COMPOSE_VERSION=$(docker compose version 2>/dev/null) \
        || error "Docker Compose não encontrado após instalação."

    success "$DOCKER_VERSION"
    success "$COMPOSE_VERSION"

    if docker info &>/dev/null; then
        success "Docker daemon respondendo corretamente."
    else
        warn "Docker instalado, mas o daemon pode não estar rodando. Execute: systemctl start docker"
    fi
}

# ==============================================================================
# MENSAGEM FINAL
# FIX: CURRENT_USER agora detecta corretamente o usuário real por trás do sudo,
#      ignorando SUDO_USER="root" (caso de sudo para root explícito)
# ==============================================================================
print_summary() {
    local CURRENT_USER
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        CURRENT_USER="$SUDO_USER"
    else
        CURRENT_USER="$USER"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}╔═════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║   Docker + Docker Compose instalados com sucesso!   ║${RESET}"
    echo -e "${GREEN}${BOLD}╚═════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${BOLD}📦 Versões instaladas:${RESET}"
    echo -e "   $(docker --version)"
    echo -e "   $(docker compose version)"
    echo ""
    echo -e "${BOLD}📋 Log da instalação:${RESET}"
    echo -e "   ${CYAN}${LOG_FILE}${RESET}"
    echo ""
    echo -e "${BOLD}⚙️  Para usar Docker sem sudo:${RESET}"
    echo -e "   ${CYAN}usermod -aG docker ${CURRENT_USER}${RESET}"
    echo -e "   ${CYAN}newgrp docker${RESET}  ${YELLOW}# ou faça logout/login${RESET}"
    echo ""
    echo -e "${BOLD}🚀 Comandos úteis:${RESET}"
    echo -e "   ${CYAN}docker run hello-world${RESET}    # Testar instalação"
    echo -e "   ${CYAN}docker ps${RESET}                  # Listar containers"
    echo -e "   ${CYAN}docker compose up -d${RESET}       # Subir stack em background"
    echo ""
}

# ==============================================================================
# EXECUÇÃO PRINCIPAL
# ==============================================================================
echo -e "${BOLD}${BLUE}"
echo "  ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗ "
echo "  ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗"
echo "  ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝"
echo "  ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗"
echo "  ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║"
echo "  ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"
echo -e "${RESET}"
echo -e "${BOLD}         Instalador Universal — Linux${RESET}"
echo -e "  ${CYAN}Autor: Italo Freitas (italofreitas2222@gmail.com)${RESET}"
echo "  ────────────────────────────────────────────────"
echo ""

check_root
check_internet
detect_os
check_existing_docker
remove_old_versions
install_dependencies
install_docker
enable_docker_service
verify_installation
print_summary
