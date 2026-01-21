# ⚙️ Manual de Implantação Técnica

Este documento detalha o procedimento passo-a-passo para replicar a infraestrutura do Nextcloud Vault.

**Pré-requisitos:**

* Linux (Fedora/RHEL ou Debian/Ubuntu)
* Podman instalado (Rootless recomendado)
* HDD secundário formatado e criptografado com LUKS
* Conta ativa no Tailscale

---

## ⚠️ 1. Preparação do Disco (LUKS)

O script de automação requer exclusividade sobre o dispositivo. Certifique-se de que ele não está montado automaticamente pela interface gráfica do Linux.

```bash
# Identifique seu mapper LUKS
ls /dev/mapper/

# Feche o dispositivo (substitua pelo seu UUID ou nome do mapper)
sudo cryptsetup close luks-SEU-UUID-AQUI

```

## 🛡️ 2. Estrutura de Diretórios e Permissões

Prepare as pastas locais no diretório do projeto. Isso garante que o Podman tenha permissão de escrita e que o estado do Tailscale seja salvo corretamente no disco.

```bash
# Crie as pastas locais (no mesmo diretório do compose.yaml)
mkdir -p ./certs
mkdir -p ./tailscale-data

# Ajuste as permissões de segurança
# ./tailscale-data: Privado (700) - contém a identidade da VPN e chaves
chmod 700 ./tailscale-data

# ./certs: Compartilhado (775) - acessível para containers web e usuário
chmod 775 ./certs

```

## 💾 3. Configuração do Storage (`setup_hdd.sh`)

Edite o script `setup_hdd.sh` na raiz do projeto e insira o UUID do seu disco físico.

```bash
# Edite as variáveis UUID_LUKS e PONTO_MONTAGEM
nano setup_hdd.sh

# Execute a montagem
sudo ./setup_hdd.sh

```

## 🔐 4. Variáveis de Ambiente (.env)

O repositório inclui um arquivo de exemplo. Copie-o e edite as credenciais. **Use aspas simples** nas senhas para evitar erros de interpretação do shell.

```bash
# Copie o exemplo para o arquivo real
cp .env.example .env

# Edite os valores
nano .env
```

## 🌐 5. Configuração do Tailscale (Web)

Acesse o Painel Administrativo do Tailscale:

1. Ative **MagicDNS** e **HTTPS Certificates** na aba DNS.
2. Gere uma **Auth Key** nova, preferencialmente com uma Tag (ex: `tag:nextcloud`).
3. Nas configurações da máquina (após subir a primeira vez), ative **"Disable key expiry"** para evitar desconexão a cada 6 meses.

## 🚀 6. Execução e Deploy

Siga a ordem estrita para garantir a geração dos certificados SSL antes da aplicação subir:

### Passo 6.1: Subir a Rede VPN

```bash
podman compose up -d tailscale

```

### Passo 6.2: Gerar Certificados

Primeiro, verifique o nome completo da máquina na VPN:

```bash
podman exec ts-nextcloud tailscale status
# Exemplo de saída: nextcloud-server.shark-banana.ts.net

```

Gere os certificados usando o nome completo obtido acima. O comando abaixo salva os arquivos na pasta mapeada `./certs`:

```bash
podman exec ts-nextcloud tailscale cert \
  --cert-file /certs_temp/nextcloud.crt \
  --key-file /certs_temp/nextcloud.key \
  "SEU-HOSTNAME-COMPLETO.ts.net"

```

### Passo 6.3: Subir a Aplicação

```bash
podman compose up -d

```

## ⚡ 7. Pós-Instalação (Otimização)

Ative o Redis para cache e *file locking* transacional. Isso melhora drasticamente a performance da interface web:

```bash
podman exec --user www-data nextcloud-app php occ config:system:set redis host --value=127.0.0.1
podman exec --user www-data nextcloud-app php occ config:system:set redis port --value=6379
podman exec --user www-data nextcloud-app php occ config:system:set memcache.local --value='\OC\Memcache\Redis'
podman exec --user www-data nextcloud-app php occ config:system:set memcache.locking --value='\OC\Memcache\Redis'

```

## 🔧 Troubleshooting

**Conflito de Identidade (Hostname "Unknown"):**
Se o hostname aparecer como "unknown" ou houver conflito de chaves, realize um Hard Reset limpando a pasta local de estado:

```bash
# 1. Derrube a stack
podman compose down

# 2. Limpe o estado LOCAL do Tailscale (Isso apaga a identidade da VPN)
# CUIDADO: Este comando apaga tudo dentro da pasta de dados do Tailscale
rm -rf ./tailscale-data/*

# 3. Remova a máquina antiga ("Offline") do painel Web do Tailscale

# 4. Suba novamente (uma nova identidade será gerada)
podman compose up -d

```