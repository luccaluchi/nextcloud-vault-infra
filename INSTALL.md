# ⚙️ Manual de Implantação Técnica

Este documento detalha o procedimento passo-a-passo para replicar a infraestrutura do Nextcloud Vault.

**Pré-requisitos:**
* Linux (Fedora/RHEL ou Debian/Ubuntu)
* Podman instalado
* HDD secundário formatado e criptografado com LUKS
* Conta ativa no Tailscale

---

## ⚠️ 1. Preparação do Disco (LUKS)

O script de automação requer exclusividade sobre o dispositivo. Certifique-se de que ele não está montado pela interface gráfica.

```bash
# Identifique seu mapper LUKS
ls /dev/mapper/

# Feche o dispositivo (substitua pelo seu UUID)
sudo cryptsetup close luks-SEU-UUID-AQUI

```

## 🛡️ 2. Permissões de Host (SELinux)

Prepare o diretório de certificados para evitar erros de permissão no Podman.

```bash
mkdir -p ~/certs
sudo chown -R $USER:$USER ~/certs
chmod 775 ~/certs

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

Crie o arquivo `.env` baseado no exemplo abaixo. **Use aspas simples** para evitar erros de interpretação de shell em senhas complexas.

```ini
# Database
POSTGRES_DB='nextcloud'
POSTGRES_USER='nextcloud_user'
POSTGRES_PASSWORD='SUA_SENHA_FORTE'

# App Admin
NEXTCLOUD_ADMIN_USER='admin'
NEXTCLOUD_ADMIN_PASSWORD='SUA_SENHA_FORTE'

# Tailscale Auth
TS_AUTHKEY='tskey-auth-...'
TS_HOSTNAME='nextcloud-server'

```

## 🌐 5. Configuração do Tailscale

No Painel Administrativo:

1. Ative **MagicDNS** e **HTTPS Certificates**.
2. Gere uma Auth Key com Tag (ex: `tag:nextcloud`).
3. Nas configurações da máquina, ative **"Disable key expiry"**.

## 🚀 6. Execução e Deploy

Siga a ordem estrita para garantir a geração dos certificados SSL:

1. **Subir a Rede:**
```bash
podman compose up -d tailscale

```


2. **Gerar Certificados:**
```bash
podman exec ts-nextcloud tailscale cert \
  --cert-file /certs_temp/nextcloud.crt \
  --key-file /certs_temp/nextcloud.key \
  "SEU-HOSTNAME.SUA-TAILNET.ts.net"

```


3. **Subir a Aplicação:**
```bash
podman compose up -d

```



## ⚡ 7. Pós-Instalação (Otimização)

Ative o Redis para cache e locking transacional:

```bash
podman exec --user www-data nextcloud-app php occ config:system:set redis host --value=127.0.0.1
podman exec --user www-data nextcloud-app php occ config:system:set redis port --value=6379
podman exec --user www-data nextcloud-app php occ config:system:set memcache.local --value='\OC\Memcache\Redis'
podman exec --user www-data nextcloud-app php occ config:system:set memcache.locking --value='\OC\Memcache\Redis'

```

## 🔧 Troubleshooting

**Conflito de Identidade (MagicDNS):**
Se o hostname aparecer entre parênteses `("nome")` ou o DNS falhar, realize um Hard Reset:

```bash
podman compose down
podman volume rm nextcloud_ts_state
# Remova a máquina antiga do painel Tailscale
podman compose up -d

```