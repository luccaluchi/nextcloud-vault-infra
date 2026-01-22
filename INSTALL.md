# ⚙️ Manual de Implantação Técnica (Nextcloud Vault)

Este documento detalha o procedimento para implantar a infraestrutura "Zero Trust" do Nextcloud Vault.

**Status da Automação:**

* ✅ Certificados SSL (Tailscale/Let's Encrypt): **Automático**
* ✅ Renovação de Certificados: **Automático**
* ✅ Configuração de Domínios Confiáveis: **Automático**
* ✅ Otimização Redis (Cache/Locking): **Automático**

---

## ⚠️ CRÍTICO: LEIA ANTES DE INICIAR (Rate Limits)

O sistema de geração de certificados HTTPS possui limites de segurança estritos impostos pela Let's Encrypt.

1. **Não apague a pasta `./certs`:** Se você reiniciar ou recriar os containers, o sistema reutilizará os certificados existentes. Se você apagar essa pasta e tentar gerar de novo muitas vezes, **você será bloqueado**.
2. **Sintoma de Bloqueio:** Se o comando de subida parecer "travado" no log com a mensagem `⚠️ Falha no certificado...`, você atingiu o limite.
3. **Solução de Emergência:** Se for bloqueado, edite o arquivo `.env` e mude o `TS_HOSTNAME` (ex: de `nextcloud` para `nextcloud-v2`) para obter uma nova identidade.

---

## 🐧 1. Preparação do Sistema Host (Tuning)

Para garantir a performance do Tailscale (UDP) e a estabilidade do Redis, aplique as configurações de kernel abaixo no seu sistema Linux (Fedora/RHEL/Debian).

Crie o arquivo de configuração persistente:

```bash
# 1. Criar arquivo de parâmetros do kernel
sudo nano /etc/sysctl.d/99-nextcloud-infra.conf

# 2. Cole o conteúdo abaixo:
# ---
# Permite que o Redis gerencie memória em cenários de pouca RAM (evita falhas de salvamento)
vm.overcommit_memory = 1

# Aumenta buffers UDP para performance do Tailscale (DERP/WireGuard)
net.core.rmem_max = 7500000
net.core.wmem_max = 7500000
# ---

# 3. Aplique as mudanças imediatamente
sudo sysctl -p /etc/sysctl.d/99-nextcloud-infra.conf

```

## 🛡️ 2. Estrutura de Diretórios e Permissões

Prepare as pastas locais. Isso garante persistência dos dados e permissão de escrita para os containers.

```bash
# Crie as pastas na raiz do projeto
mkdir -p ./certs ./tailscale-data ./db_data

# Ajuste permissões críticas
# ./tailscale-data: Privado (700) - Identidade da VPN
chmod 700 ./tailscale-data

# ./certs: Compartilhado (775) - Acessível para Tailscale e Nextcloud
chmod 775 ./certs

```

## 💾 3. Configuração do Storage (`setup_hdd.sh`)

Se estiver usando um HDD externo criptografado, certifique-se de que ele **não** está montado automaticamente pela interface gráfica. Use o script incluído:

```bash
# Edite as variáveis UUID_LUKS e PONTO_MONTAGEM se necessário
nano setup_hdd.sh

# Execute a montagem (descriptografa e monta o volume)
sudo ./setup_hdd.sh

```

## 🔐 4. Variáveis de Ambiente (.env)

Copie o modelo e preencha suas credenciais.

```bash
cp .env.example .env
nano .env

```

**Pontos de Atenção:**

* `TS_AUTHKEY`: Gere uma chave **Reutilizável** e **Ephemeral** (opcional) no painel do Tailscale.
* `TS_HOSTNAME`: O nome que sua máquina terá na VPN (ex: `cloud-server`).
* `TS_TAILNET_NAME`: Seu domínio Tailscale (ex: `tailc1234.ts.net`).

## 🌐 5. Configuração no Painel Tailscale

Antes de subir, acesse [login.tailscale.com/admin/dns](https://login.tailscale.com/admin/dns):

1. Ative **MagicDNS**.
2. Ative **HTTPS Certificates**.

## 🚀 6. Execução (Deploy Automatizado)

Diferente da versão anterior, agora **um único comando** gerencia toda a orquestração (VPN, Certificados e Aplicação).

```bash
podman-compose up -d

```

### 6.1 Monitoramento da Instalação

A primeira inicialização pode demorar de 1 a 3 minutos enquanto o certificado SSL é gerado. **Não interrompa o processo.**

Acompanhe o log da VPN para saber quando terminar:

```bash
podman logs -f ts-nextcloud

```

**Sequência de Sucesso Esperada:**

1. `✅ Socket encontrado!`
2. `✅ VPN Ativa: 100.x.y.z`
3. `🎯 Domínio alvo configurado: nextcloud.seu-dominio.ts.net`
4. `🎉 SUCESSO! Certificado gerado em /certs_temp.`

*Assim que a mensagem de sucesso aparecer, o container do Nextcloud detectará os arquivos automaticamente e iniciará o servidor Web.*

## ⚡ 7. Verificação Pós-Instalação

O script de inicialização configura automaticamente o **Redis** e os **Trusted Domains**. Você pode verificar se tudo subiu corretamente acessando a URL:

`https://<TS_HOSTNAME>.<TS_TAILNET_NAME>`

Para confirmar se o Redis está ativo dentro do container:

```bash
podman exec -u www-data nextcloud-app php occ config:system:get redis
# Deve retornar host: 127.0.0.1 e port: 6379

```

---

## 🔧 Troubleshooting

**1. Terminal travado em "Solicitando Certificado SSL..."**

* **Causa:** Rate Limit do Let's Encrypt ou DNS não propagado.
* **Ação:** Se durar mais de 2 minutos, pare (`Ctrl+C`). Mude o `TS_HOSTNAME` no `.env` e suba novamente.

**2. Erro "Access through untrusted domain"**

* **Causa:** O container subiu antes do certificado ou variável de ambiente incorreta.
* **Ação:** O novo `compose` corrige isso no boot. Se persistir, force a atualização manual:
```bash
podman exec -u www-data nextcloud-app php occ config:system:set trusted_domains 1 --value="SEU.DOMINIO.COMPLETO"

```



**3. Reset Total (Hard Reset)**
Se precisar reinstalar do zero (cuidado, isso apaga a identidade da VPN):

```bash
podman-compose down
sudo rm -rf ./tailscale-data/*
# Opcional: rm -rf ./certs/* (Só faça isso se os certificados estiverem inválidos)
podman-compose up -d

```