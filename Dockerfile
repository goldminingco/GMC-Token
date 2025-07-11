# Use uma imagem base com Rust e ferramentas de build essenciais
FROM rust:1.88

# Variáveis de ambiente para Solana e Anchor
ENV SOLANA_VERSION=1.18.26
ENV ANCHOR_VERSION=v0.31.1

# Instalar dependências necessárias
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    pkg-config \
    libssl-dev \
    libudev-dev \
    git \
    wget \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Instalar Node.js e Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get install -y nodejs
RUN npm install -g yarn

# Instalar Solana CLI
RUN sh -c "$(curl -sSfL https://release.solana.com/v${SOLANA_VERSION}/install)"
ENV PATH="/root/.local/share/solana/install/active_release/bin:${PATH}"

# Instalar Anchor Version Manager (avm) e Anchor
RUN cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
RUN avm install ${ANCHOR_VERSION}
RUN avm use ${ANCHOR_VERSION}
ENV PATH="/root/.avm/bin:${PATH}"

# Configurar o diretório de trabalho
WORKDIR /app

# Copiar os arquivos de configuração do projeto
COPY Anchor.toml Cargo.toml package.json yarn.lock ./

# Copiar o código-fonte dos programas
COPY programs ./programs

# Instalar dependências Rust (sem compilar os programas ainda)
RUN cargo fetch

# Instalar dependências Node.js
RUN yarn install

# Copiar o resto dos arquivos do projeto (testes, scripts, etc.)
COPY . .

# Comando padrão (pode ser sobrescrito)
CMD ["bash"]