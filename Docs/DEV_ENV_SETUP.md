# 🛠️ Guia de Setup do Ambiente de Desenvolvimento – GMC Token Ecosystem

> Versão: 1.0   Data: Janeiro 2025  
> Manter este arquivo atualizado sempre que novos requisitos ou scripts forem adicionados.

---

## 1. Pré-requisitos de Sistema

| Ferramenta | Versão mínima recomendada | Comando de verificação |
|------------|--------------------------|------------------------|
| **Rust**   | 1.75.0 (stable)          | `rustc --version`      |
| **Solana CLI** | 1.18.x                | `solana --version`     |
| **Anchor CLI** | 0.30.x                | `anchor --version`     |
| **Node .js**   | 18.x LTS              | `node -v`              |
| **NPM**        | 9.x ou 10.x           | `npm -v`               |
| **Yarn** _(opcional)_ | ≥ 1.22         | `yarn -v`              |
| **Docker** _(opcional)_ | 24.x        | `docker -v`            |

> 💡 Diversos scripts (e.g. `devnet_deploy.sh`) supõem um shell *bash* ou *zsh*.

---

## 2. Instalação Passo-a-Passo

1. **Rust**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
   rustup default stable
   rustup update stable
   ```
2. **Solana CLI**
   ```bash
   sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
   # Adicione ~/.local/share/solana/install/active_release/bin ao $PATH, se necessário
   solana config set --url localhost            # para testes locais
   solana-keygen new --silent                   # cria keypair default
   ```
3. **Anchor CLI**
   ```bash
   npm install -g @coral-xyz/anchor-cli@0.30.1   # mantenha a versão alinhada ao Cargo.toml
   ```
4. **Node/NPM Dependências**
   ```bash
   git clone https://github.com/goldminingco/GMC-Token.git
   cd GMC-Token
   npm install                                        # instala dependências JS/TS
   ```
5. **Scripts Automatizados (opcional)**
   ```bash
   ./scripts/setup_environment.sh localnet            # instala toolchains corretas
   ```
6. **Compilar tudo para validação rápida**
   ```bash
   anchor build                                       # gera artefatos .so e IDL
   npm run test:unit                                  # executa testes unitários
   ```

---

## 3. Ajustes de Rede & Timeout (Workarounds)

Ambientes com **proxy corporativo** ou conexões instáveis podem sofrer *timeouts* ao baixar crates do GitHub.

```bash
# Força o Cargo a usar o binário do Git em vez do libgit2 (mais resiliente)
export CARGO_NET_GIT_FETCH_WITH_CLI=true

# Aumenta timeout de clone (em segundos)
export GIT_HTTP_LOW_SPEED_LIMIT=0
export GIT_HTTP_LOW_SPEED_TIME=999999
```

Se você usa **Windows + WSL2**, também recomendamos:
```bash
git config --global core.symlinks true   # evita problemas com links simbólicos
```

---

## 4. Variáveis de Ambiente Importantes

| Variável | Descrição | Valor sugerido |
|----------|-----------|----------------|
| `SOLANA_CONFIG` | Caminho do arquivo de configuração padrão (~/.config/solana/cli/config.yml). | _(auto)_ |
| `ANCHOR_WALLET` | Keypair que assinará deploy/tests. | `~/.config/solana/id.json` |
| `SOLANA_CLUSTER` | Cluster alvo para scripts (`localnet`, `devnet`, `testnet`, `mainnet-beta`). | `localnet` |
| `RUSTFLAGS` | Flags extra para otimização ou debugs. | `-C target-cpu=native` |
| `CARGO_NET_GIT_FETCH_WITH_CLI` | Workaround de rede descrito acima. | `true` |
| `TS_NODE_TRANSPILE_ONLY` | Melhora desempenho dos testes TS. | `1` |

> 💡 Todas as variáveis acima são opcionais – os scripts fornecem *defaults* seguros.

---

## 5. Do Clone ao Primeiro Deploy Local

```bash
# 1. Clone o repo
git clone https://github.com/goldminingco/GMC-Token.git && cd GMC-Token

# 2. Instale dependências Node
npm ci

# 3. Inicie o validador local (terminal 1)
solana-test-validator --reset --quiet &   # porta 8899

# 4. Compile e deploy contratos (terminal 2)
anchor build
anchor deploy --provider.cluster localnet

# 5. Execute testes completos (terminal 3)
npm run test
```

> ⚠️ Alguns testes E2E esperam um **saldo inicial de SOL** na carteira default. Use:
> ```bash
> solana airdrop 10 $(solana address)
> ```

---

## 6. Tabela de Comandos Rápidos

| Ação | Comando |
|------|---------|
| **Compilar todos os programas** | `anchor build` |
| **Deploy localnet** | `anchor deploy --provider.cluster localnet` |
| **Iniciar validador** | `solana-test-validator --reset` |
| **Executar testes unitários** | `npm run test:unit` |
| **Executar suíte completa** | `npm test` |
| **Checar configuração de assinatura** | `npm run check:signature` |
| **Executar linter** | `npm run lint` ou `./scripts/check_linter_health.sh` |
| **Bootstrap volume stress test** | `npm run volume:setup` |
| **Clean build artifacts** | `anchor clean && git clean -fdX target` |

---

## 7. Solução de Erros Comuns

| Erro / Sintoma | Causa provável | Solução |
|----------------|---------------|---------|
| `Signature verification failed` | Signer ausente ou PDA como signer | Consulte [`Docs/ANCHOR_SIGNATURE_TROUBLESHOOTING.md`](./ANCHOR_SIGNATURE_TROUBLESHOOTING.md) |
| `error[E0463]: can't find crate` | Cache Cargo corrompido | `cargo clean -p <crate>` ou `rm -rf ~/.cargo/registry` |
| `File too large (>100 MB) rejected by GitHub` | Artefatos em *git add* | Verifique `.gitignore`, use `git lfs` se necessário |
| Timeout em `cargo build` | Rede lenta | `export CARGO_NET_GIT_FETCH_WITH_CLI=true` + proxy |
| Anchor não gera IDL | Versões incompatíveis | `npm i -g @coral-xyz/anchor-cli@0.30.1` |

Para problemas de compilação específicos, veja [`Docs/COMPILATION_ANALYSIS.md`](./COMPILATION_ANALYSIS.md).

---

## 8. Próximos Passos

1. **Atualizar README**: adicionar link para este guia na seção “Installation”.
2. **Automação CI**: incluir verificação de variáveis obrigatórias no workflow GitHub Actions.
3. **Feedback**: abra uma *issue* se encontrar lacunas neste documento.

> _“Works on my machine” não é documentação! Mantenha este guia vivo para garantir **onboarding** rápido e builds reproduzíveis para toda a comunidade._ 