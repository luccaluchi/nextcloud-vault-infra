#!/bin/bash

# ==============================================================================
# SCRIPT DE AUTOMAÇÃO DE STORAGE (Auto-Unlock & Mount)
# ==============================================================================
# Este script configura um HDD criptografado (LUKS) para desbloquear e montar
# automaticamente no boot, separando uma pasta específica para containers.

# --- CONFIGURAÇÕES ---

# UUID da partição CRIPTOGRAFADA (/dev/sda1 no seu caso)
UUID_LUKS="df7b239b-1095-4afc-a431-0ff581b5fd64"

# Nome do dispositivo no sistema (Mapper)
NOME_MAPPER="hdd_dados"

# Onde o DISCO INTEIRO será montado
PONTO_MONTAGEM="/mnt/hdd_dados"

# Pasta específica para o Nextcloud (Isolamento)
PASTA_NEXTCLOUD="$PONTO_MONTAGEM/nextcloud"

# Local seguro para guardar a chave de desbloqueio (dentro do NVMe criptografado)
DIR_CHAVES="/root/secrets"
ARQUIVO_CHAVE="$DIR_CHAVES/$NOME_MAPPER.key"

# Detecta o usuário real que chamou o sudo (para ajustar permissões)
USUARIO_REAL=${SUDO_USER:-$(logname)}

# ==============================================================================
# EXECUÇÃO
# ==============================================================================

# 1. Verificação de Segurança
if [ "$EUID" -ne 0 ]; then
  echo "❌ Erro: Este script precisa de acesso root para configurar /etc/fstab."
  echo "👉 Use: sudo ./setup_hdd.sh"
  exit 1
fi

echo "🚀 Iniciando configuração do Storage Secundário..."
echo "👤 Usuário Proprietário: $USUARIO_REAL"
echo "💾 Dispositivo Alvo (UUID): $UUID_LUKS"

# 2. Geração da Chave de Segurança
echo "🔐 Gerando chave de desbloqueio segura..."
mkdir -p "$DIR_CHAVES"
chmod 700 "$DIR_CHAVES"

# Cria uma chave de 4KB com dados aleatórios
dd if=/dev/urandom of="$ARQUIVO_CHAVE" bs=1024 count=4 status=none
chmod 0400 "$ARQUIVO_CHAVE"

# 3. Associação da Chave ao Disco
echo "🔑 Adicionando chave ao HDD."
echo "⚠️  ATENÇÃO: Digite a senha ATUAL do disco HDD quando solicitado abaixo:"
if cryptsetup luksAddKey "UUID=$UUID_LUKS" "$ARQUIVO_CHAVE"; then
    echo "✅ Chave adicionada com sucesso."
else
    echo "❌ Falha ao adicionar chave. Senha incorreta?"
    exit 1
fi

# 4. Configuração do Desbloqueio Automático (crypttab)
echo "📝 Configurando /etc/crypttab..."
# Backup por segurança
cp /etc/crypttab "/etc/crypttab.bak.$(date +%s)"

# Remove configurações antigas deste mapper para evitar conflito
sed -i "/^$NOME_MAPPER/d" /etc/crypttab

# Adiciona a nova configuração
# Sintaxe: nome UUID arquivo_chave opções
echo "$NOME_MAPPER UUID=$UUID_LUKS $ARQUIVO_CHAVE luks,nofail" >> /etc/crypttab

# 5. Configuração da Montagem Automática (fstab)
echo "📝 Configurando /etc/fstab..."
# Backup por segurança
cp /etc/fstab "/etc/fstab.bak.$(date +%s)"

# Cria o diretório de montagem
mkdir -p "$PONTO_MONTAGEM"

# Remove entradas antigas deste ponto de montagem
sed -i "\#$PONTO_MONTAGEM#d" /etc/fstab

# Adiciona a nova configuração
# Sintaxe: device mountpoint fs options dump pass
echo "/dev/mapper/$NOME_MAPPER $PONTO_MONTAGEM ext4 defaults,noatime,nofail 0 2" >> /etc/fstab

# 6. Aplicação e Teste
echo "🔄 Recarregando serviços e montando discos..."

# Limpeza de tentativas anteriores
umount "$PONTO_MONTAGEM" 2>/dev/null || true
cryptsetup close "$NOME_MAPPER" 2>/dev/null || true

# Recarrega o systemd para ler o novo crypttab/fstab
if [ -x "$(command -v systemctl)" ]; then
    systemctl daemon-reload
fi

# Tenta desbloquear usando a nova configuração
echo "🔓 Desbloqueando disco..."
# Tenta via systemd ou comando direto
cryptdisks_start "$NOME_MAPPER" 2>/dev/null || \
systemctl restart "systemd-cryptsetup@$NOME_MAPPER" 2>/dev/null || \
cryptsetup open --key-file "$ARQUIVO_CHAVE" "/dev/disk/by-uuid/$UUID_LUKS" "$NOME_MAPPER"

# Monta tudo que está no fstab
mount -a

# 7. Permissões e Estrutura de Pastas
if mountpoint -q "$PONTO_MONTAGEM"; then
    echo "✅ HDD montado com sucesso em: $PONTO_MONTAGEM"
    
    # Define o seu usuário como dono da RAIZ do HDD
    echo "👤 Ajustando permissões da raiz do disco..."
    chown "$USUARIO_REAL:$USUARIO_REAL" "$PONTO_MONTAGEM"
    chmod 755 "$PONTO_MONTAGEM"

    # Cria a pasta dedicada ao Nextcloud
    echo "📂 Criando diretório dedicado: $PASTA_NEXTCLOUD"
    mkdir -p "$PASTA_NEXTCLOUD"
    chown "$USUARIO_REAL:$USUARIO_REAL" "$PASTA_NEXTCLOUD"
    
    echo "🎉 Configuração Concluída!"
    echo "👉 Atualize seu compose.yaml para usar: $PASTA_NEXTCLOUD"
else
    echo "❌ Erro Crítico: O disco não foi montado. Verifique os logs."
    exit 1
fi