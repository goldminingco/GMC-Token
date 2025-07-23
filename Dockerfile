# Dockerfile para GMC Token - Native Rust (sem Anchor)
# Baseado em uma imagem oficial do Rust para maior estabilidade

FROM rustlang/rust:nightly-bullseye

ENV DEBIAN_FRONTEND=noninteractive

# Etapa 1: Instalar dependências essenciais (Node.js, Yarn, etc.)
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    libssl-dev \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && NODE_MAJOR=18 \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g yarn

# Etapa 2: Instalar Solana CLI e configurar ambiente
RUN wget https://github.com/solana-labs/solana/releases/download/v1.18.26/solana-release-x86_64-unknown-linux-gnu.tar.bz2 \
    && tar -jxvf solana-release-x86_64-unknown-linux-gnu.tar.bz2 \
    && mv solana-release/bin/* /usr/local/bin/ \
    && rm -rf solana-release* \
    && mkdir -p /root/.cache/solana

# Verificar instalação do Solana
RUN solana --version

# Etapa 3: Configurar o ambiente de trabalho
WORKDIR /app

# Etapa 4: Copiar arquivos do projeto e instalar dependências
COPY . .
RUN yarn install --frozen-lockfile

# Etapa 5: Construir programas Native Rust
RUN chmod +x ./build_all.sh
RUN ./build_all.sh

# Expor portas para desenvolvimento
EXPOSE 8899 8900

# Comando padrão
CMD ["solana-test-validator"]