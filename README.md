# 🐳 Docker Universal Installer

Script de instalação automática do **Docker Engine + Docker Compose** para as principais distribuições Linux, suportando arquiteturas `amd64` e `arm64`.

---

## ✨ Destaques

- 🔍 Detecção automática de distro e arquitetura
- 📦 Suporte a múltiplos gerenciadores de pacotes (`apt`, `dnf`, `yum`, `zypper`, `pacman`, `apk`)
- 🔐 Verificação de fingerprint da chave GPG oficial do Docker
- 🌐 Teste de conectividade diretamente contra `download.docker.com`
- 📋 Log automático em `/var/log/docker-install-*.log`
- ♻️ Remoção de versões antigas antes da instalação

---

## 🖥️ Distribuições Suportadas

| Família | Distros |
|---|---|
| **Debian/Ubuntu** | Debian, Ubuntu, Raspbian, Linux Mint, Pop!\_OS, Kali, Parrot, Zorin, MX |
| **RHEL** | Fedora, CentOS, RHEL, Rocky Linux, AlmaLinux, Oracle Linux |
| **SUSE** | openSUSE, SLES, SLED |
| **Arch** | Arch Linux, Manjaro, EndeavourOS, Garuda |
| **Alpine** | Alpine Linux |

---

## 🚀 Instalação

### Via `curl`
```bash
curl -fsSL https://raw.githubusercontent.com/ItaloFreitasM/docker/refs/heads/main/install-docker.sh | sudo bash
```

### Via `wget`
```bash
wget -qO - https://raw.githubusercontent.com/ItaloFreitasM/docker/refs/heads/main/install-docker.sh | sudo bash
```

> ⚠️ O script deve ser executado como **root** ou via **sudo**.

---

## ⚙️ Pós-instalação

Para usar o Docker **sem sudo**, adicione seu usuário ao grupo `docker`:

```bash
usermod -aG docker $USER
newgrp docker   # ou faça logout/login
```

---

## 🔒 Segurança

- A chave GPG do Docker é baixada com `--retry 3` e `--connect-timeout 15`
- O fingerprint é verificado contra o valor oficial:
  ```
  9DC858229FC7DD38854AE2D88D81803C0EBFCD88
  ```
- A instalação é abortada automaticamente se o fingerprint não conferir

---

## 📋 O que o script faz

```
1. Verifica execução como root
2. Testa conectividade com download.docker.com
3. Detecta distro, versão, codinome e arquitetura
4. Remove versões antigas do Docker (repositórios não-oficiais)
5. Instala dependências básicas (curl, ca-certificates, gnupg…)
6. Configura repositório oficial do Docker
7. Verifica fingerprint da chave GPG
8. Instala docker-ce, docker-ce-cli, containerd.io,
   docker-buildx-plugin e docker-compose-plugin
9. Habilita e inicia o serviço (systemd / OpenRC)
10. Verifica a instalação e exibe resumo
```

---

## 📁 Log

Cada execução gera um log com timestamp em:

```
/var/log/docker-install-YYYYMMDD-HHMMSS.log
```

---

## 🧪 Testando a instalação

```bash
docker run hello-world       # Verifica o daemon
docker ps                    # Lista containers em execução
docker compose version       # Confirma o Compose
```

---

## 📄 Licença

MIT — livre para usar, modificar e distribuir.

---

**Autor:** Italo Freitas — [italofreitas2222@gmail.com](mailto:italofreitas2222@gmail.com)
