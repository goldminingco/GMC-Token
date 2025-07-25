#!/bin/bash
# Script para recuperar carteira automaticamente

SEED_PHRASE="$1"
OUTPUT_FILE="$2"

if [ -z "$SEED_PHRASE" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Uso: $0 \"seed phrase\" output_file"
    exit 1
fi

# Criar script expect temporário
cat > /tmp/recover_expect.exp << EOF
#!/usr/bin/expect -f
set timeout 10
spawn solana-keygen recover -o "$OUTPUT_FILE" --force
expect "[recover] seed phrase:"
send "$SEED_PHRASE\r"
expect {
    "Otherwise, press ENTER to continue:" {
        send "\r"
        exp_continue
    }
    "Continue? (y/n):" {
        send "y\r"
        exp_continue
    }
    eof
}
EOF

chmod +x /tmp/recover_expect.exp

# Verificar se expect está disponível
if command -v expect >/dev/null 2>&1; then
    /tmp/recover_expect.exp
    rm -f /tmp/recover_expect.exp
    
    if [ -f "$OUTPUT_FILE" ]; then
        ADDRESS=$(solana-keygen pubkey "$OUTPUT_FILE")
        echo "✅ Carteira recuperada: $ADDRESS"
        echo "📁 Arquivo: $OUTPUT_FILE"
        exit 0
    else
        echo "❌ Falha na recuperação"
        exit 1
    fi
else
    echo "❌ expect não está instalado. Instalando..."
    # Para macOS
    if command -v brew >/dev/null 2>&1; then
        brew install expect
        /tmp/recover_expect.exp
        rm -f /tmp/recover_expect.exp
    else
        echo "❌ Não foi possível instalar expect automaticamente"
        echo "Execute: brew install expect"
        exit 1
    fi
fi 