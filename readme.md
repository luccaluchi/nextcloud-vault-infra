# ☁️ Nextcloud Vault Infrastructure

> **Infraestrutura autogerenciada para Nextcloud focada em segurança (Zero Trust), privacidade e persistência de dados.**

Este projeto implementa um ambiente de armazenamento em nuvem pessoal "hardened" (endurecido), utilizando contêineres e criptografia de disco para garantir a soberania dos dados.

## 🏗️ Arquitetura do Projeto

A solução foi desenhada para desacoplar a aplicação (efêmera) dos dados (persistentes), garantindo portabilidade e segurança em camadas.

| Componente | Tecnologia | Papel Estratégico |
| :--- | :--- | :--- |
| **Orquestração** | **Podman Compose** | Gerenciamento de containers *daemonless* para maior segurança e menor overhead no host. |
| **Rede Zero Trust** | **Tailscale** | Elimina a necessidade de expor portas na internet pública. Gerencia DNS (MagicDNS) e Certificados SSL automaticamente. |
| **Segurança de Dados** | **LUKS (dm-crypt)** | Criptografia de disco em repouso (Data-at-Rest), protegendo fisicamente o HDD de armazenamento. |
| **Performance** | **Redis** | Cache em memória para indexação de arquivos e *locking* transacional, reduzindo I/O no disco mecânico. |
| **Banco de Dados** | **PostgreSQL** | Persistência relacional robusta, isolada em container dedicado. |

## 🧠 Princípios de Engenharia

* **Segurança em Profundidade:** O acesso é restrito à VPN (Tailscale), o tráfego é criptografado (HTTPS) e o armazenamento físico é ilegível sem a chave (LUKS).
* **Imutabilidade e IaC:** Toda a infraestrutura é definida como código (`compose.yaml`), permitindo recuperação rápida de desastres (Disaster Recovery).
* **Eficiência de Recursos:** O uso do Podman e Redis permite que a stack rode com baixo consumo de CPU/RAM, maximizando a vida útil do hardware.

## 🛠️ Tech Stack

![Podman](https://img.shields.io/badge/Podman-892CA0?style=for-the-badge&logo=podman&logoColor=white)
![Tailscale](https://img.shields.io/badge/Tailscale-1E1E1E?style=for-the-badge&logo=tailscale&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![Redis](https://img.shields.io/badge/redis-%23DD0031.svg?style=for-the-badge&logo=redis&logoColor=white)
![Nextcloud](https://img.shields.io/badge/Nextcloud-0082C9?style=for-the-badge&logo=Nextcloud&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)

## ✅ Status Operacional

Este projeto está em produção com as seguintes rotinas de manutenção ativas:

* [x] **Backups:** Estratégia 3-2-1 implementada (Local + HDD Externo + Nuvem Criptografada).
* [x] **Monitoramento:** Healthchecks nativos configurados no `compose.yaml`.
* [x] **Persistência:** Volumes montados em disco físico dedicado e criptografado.

## 🚀 Como Implantar

Para instruções técnicas detalhadas de instalação, configuração de variáveis de ambiente e scripts de automação, consulte o manual de implantação:

👉 **[Acesse o Manual de Instalação (INSTALL.md)](./INSTALL.md)**