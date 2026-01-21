# ☁️ Nextcloud Vault Infrastructure

**Infraestrutura autogerenciada para Nextcloud focada em segurança Zero Trust, soberania de dados e resiliência de estado.**

Este projeto implementa um ambiente de armazenamento em nuvem pessoal "hardened" (endurecido), utilizando orquestração de contêineres e criptografia de disco para garantir que os dados permaneçam sob controle estrito do proprietário, sem exposição à internet pública.

## 🏗️ Arquitetura do Projeto

A solução foi desenhada para desacoplar a aplicação (efêmera) dos dados (persistentes), garantindo portabilidade e segurança em camadas (Defense in Depth).

| Componente | Tecnologia | Papel Estratégico |
| --- | --- | --- |
| **Orquestração** | **Podman Compose** | Containers *daemonless* e *rootless*, reduzindo a superfície de ataque no host. |
| **Rede Zero Trust** | **Tailscale** | Rede mesh overlay que elimina a exposição de portas WAN. Gerencia DNS (MagicDNS) e certificados SSL/TLS automaticamente. |
| **Segurança de Dados** | **LUKS (dm-crypt)** | Criptografia de disco em repouso (Data-at-Rest), protegendo o HDD físico contra acesso não autorizado. |
| **Persistência** | **Bind Mounts** | Estratégia de volumes locais com gestão de contextos SELinux, garantindo a identidade da VPN e certificados entre reboots. |
| **Performance** | **Redis** | Cache em memória para indexação de arquivos e locking transacional. |

## 📂 Estrutura de Diretórios & OpSec

A organização de diretórios reflete uma política de segurança estrita, separando o código auditável de estados sensíveis e segredos.

```text
.
├── certs/              # Certificados SSL/TLS (Mapeado com :z compartilhado)
│   └── .gitkeep        # Estrutura mantida no Git, conteúdo ignorado
├── tailscale-data/     # Identidade e Node ID da VPN (Mapeado com :Z privado)
│   └── .gitkeep        # Garante a persistência da identidade do servidor
├── .env.example        # Modelo de variáveis de ambiente
├── .gitignore          # Proteção contra vazamento de segredos no repositório
├── docker-compose.yml  # Infraestrutura como Código (IaC)
└── setup_hdd.sh        # Automação de montagem do volume criptografado

```

**Nota sobre SELinux:** A infraestrutura utiliza sufixos `:Z` e `:z` nos volumes para compatibilidade nativa com políticas de segurança de distribuições RHEL/Fedora.

## 🧠 Princípios de Engenharia

* **Segurança em Profundidade:** Nenhuma porta é aberta no roteador. O acesso é exclusivo via VPN, com tráfego TLS e armazenamento físico criptografado.
* **Resiliência de Identidade:** Diferente de implantações padrão em container, esta stack persiste o `tailscaled.state`, evitando que o servidor perca sua identidade e compartilhamentos ao ser reiniciado.
* **Imutabilidade:** Toda a configuração da aplicação é definida via variáveis de ambiente no `.env`, facilitando o Disaster Recovery.

## ✅ Status Operacional

* [x] **Backup 3-2-1:** Estratégia implementada (Local + HDD Externo + Cloud).
* [x] **SSL/TLS:** Renovação automática de certificados via Tailscale.
* [x] **Persistência:** Identidade da VPN protegida contra perda de estado.

## 🚀 Configuração Rápida

Este repositório contém a definição da infraestrutura. A implantação exige a preparação do ambiente local conforme o manual.

1. **Clone o projeto e prepare os arquivos:**
```bash
git clone https://github.com/seu-usuario/nextcloud-vault.git
cd nextcloud-vault
cp .env.example .env

```


2. **Siga o Manual Técnico:**
Para detalhes sobre preparação de disco LUKS, permissões de pastas e geração de certificados SSL, acesse:
👉 **[Manual de Implantação (INSTALL.md)](https://www.google.com/search?q=./INSTALL.md)**