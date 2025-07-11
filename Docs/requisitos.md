Of course. Here is the professional English translation of the technical requirements document for the Gold Mining Token (GMC) smart contracts.

---

### **Technical Requirements Document for Smart Contracts – Gold Mining Token (GMC)**

**Version:** 1.0
**Date:** July 7, 2025
**Project:** Gold Mining Token (GMC)
**Target Audience:** Smart Contract Developers (Solana/Rust)

---

### **1. Overview of the Contract Architecture**

To implement the described logic, we propose a modular architecture consisting of the following programs (smart contracts) on the Solana network:

1.  **`GmcTokenContract`**: The GMC token itself, implemented using the **SPL Token-2022** standard to support the native transfer fee extension.
2.  **`StakingContract`**: The main program that will manage all staking logic (Long-Term and Flexible), burn-for-boost mechanics, APY calculations, affiliate management, and fee distribution.
3.  **`RankingRewardsContract`**: A dedicated program to manage the ranking reward funds, track user performance metrics, and distribute monthly and annual prizes.
4.  **`VestingContract`**: A program to manage the scheduled release (vesting) of tokens allocated to the Team and the Strategic Reserve.

### **2. Inconsistencies and Points for Clarification**

Before development begins, the following points from the source documents require a final decision as they contain conflicting information:

*   **Early Withdrawal Penalty (Long-Term Staking):**
    *   **Section 4.1.1:** Describes the penalty as "total loss of interest" and forfeiture of **10%** of the principal capital (user receives 90%).
    *   **Fee Table (Row 3):** Describes the penalty as "**5 USDT + 50% of capital + 80% of interest**".
    *   **Implementation Recommendation:** The rule in Section 4.1.1 (10% penalty on principal) is more common and technically simpler to implement on-chain. The rule from the table is more complex and punitive. **This requirements document will assume the rule from the table, but a final decision is crucial.** **Atualização: Alinhado com tabela.md - usar 5 USDT + 50% capital + 80% juros.**

*   **Interest Payment (Flexible Staking):**
    *   **Section 4.3:** States that "the withdrawal of interest can be carried out at any time by the user."
    *   **Staking Table:** Indicates "Payment 30 days of Interest".
    *   **Implementation Recommendation:** The "claim anytime" model is more flexible and aligned with DeFi user expectations. **This requirements document will assume the "claim anytime" model.** **Atualização: Alinhado com tabela.md - pagamento a cada 30 dias.**

*   **GMC Transfer Fee Distribution:**
    *   **Section 3.1:** States the 0.5% fee is split into "0.25% for Burn" and "0.25% for the Rewards Fund."
    *   **Fee Table (Row 1):** States the 0.5% fee is split into "**50% Burn** • **40% Staking Fund** • **10% Ranking Program**." (This equates to 0.25% Burn, 0.20% Staking Fund, 0.05% Ranking).
    *   **Implementation Recommendation:** The Fee Table's distribution is more detailed and aligns with the complete ecosystem. **This requirements document will assume the distribution from the Fee Table.** **Atualização: Confirmado e unificado com tabela.md.**

---

### **3. Contract 1: `GmcTokenContract` (SPL Token-2022)**

This program will define the GMC token using the `TransferFee` extension of the Token-2022 standard.

**3.1. Token Specifications:**
*   **Name:** Gold Mining Token
*   **Symbol:** GMC
*   **Decimals:** 9 (standard for SPL Tokens)
*   **Fixed Maximum Supply:** 100,000,000.000000000 (one hundred million tokens)
*   **Mint Authority:** Must be disabled after the initial minting to guarantee the fixed supply.

**3.2. Extension: Transfer Fee (`TransferFeeConfig`)**
*   **`transfer_fee_basis_points`**: `50` (equivalent to 0.5%).
*   **`maximum_fee`**: A maximum fee in GMC (e.g., 1,000 GMC) to be defined to prevent excessive fees on large transfers.
*   **Fee Collection Logic (`withdraw_withheld_authority`)**: The contract must have a designated authority (preferably the `StakingContract`) to withdraw the fees withheld in token accounts.
*   **Fee Distribution (to be executed by the withdrawal authority):**
    *   **50%** of collected tokens must be sent to a burn address (e.g., `11111111111111111111111111111111`).
    *   **40%** must be sent to the `StakingContract`'s rewards pool account.
    *   **10%** must be sent to the `RankingRewardsContract`'s rewards fund account.

**3.3. Initial Distribution (Genesis Actions):**
The deployment script must perform the following transfers from the total supply:
*   `70,000,000 GMC` to the `StakingContract`'s rewards pool account.
*   `10,000,000 GMC` to the `VestingContract` (for the Strategic Reserve).
*   `2,000,000 GMC` to the `VestingContract` (for the Team).
*   `8,000,000 GMC` to the Pre-sale/ICO wallet.
*   `2,000,000 GMC` to the Treasury wallet.
*   `6,000,000 GMC` to the Marketing wallet.
*   `2,000,000 GMC` to the Airdrop wallet.

---

### **4. Contract 2: `StakingContract`**

This is the most complex program, handling staking, burns, affiliates, and USDT-based fees.

**4.1. Data Structures (Accounts):**

*   `GlobalState`: A singleton account to store global addresses (e.g., team wallet, `RankingRewardsContract` address, burn address).
*   `UserStakeInfo`: A per-user account to store staker data, such as `referrer_address` and a counter for active staking positions.
*   `StakePosition`: An account for each individual staking position.
    *   `owner`: Pubkey
    *   `stake_type`: Enum (`LongTerm`, `Flexible`)
    *   `principal_amount`: u64 (amount of GMC staked)
    *   `start_timestamp`: i64
    *   `last_reward_claim_timestamp`: i64
    *   `is_active`: bool
    *   `long_term_data`: Struct (optional, only for Long-Term Staking)
        *   `total_gmc_burned_for_boost`: u64
        *   `staking_power_from_burn`: u8 (0-100)
        *   `affiliate_power_boost`: u8 (0-50)

**4.2. Staking Functions (Long-Term - "Staking Burn"):**

*   `stake_long_term(amount: u64)`
    *   Requirements: `amount >= 100 GMC`.
    *   **Fee in USDT:** Requires a pre-transaction of USDT-SPL from the user to a contract account. The fee amount is calculated based on the tiers defined in the Fee Table (Row 2).
    *   Creates a new `StakePosition` account with `stake_type = LongTerm`, `start_timestamp = now`, `principal_amount = amount`.
    *   Transfers `amount` of GMC from the user to a contract vault account.
    *   Distributes the received USDT fee: 40% to Team, 40% to Staking Fund (USDT), 20% to `RankingRewardsContract`.

*   `burn_for_boost(stake_position_id: Pubkey, amount_to_burn: u64)`
    *   **Fee:** Requires a pre-transaction of `0.8 USDT` from the user.
    *   Calculates an additional 10% GMC fee on `amount_to_burn`.
    *   Transfers `amount_to_burn` + `10%` of GMC from the user to the burn address.
    *   Updates `total_gmc_burned_for_boost` in the `StakePosition`.
    *   Recalculates and updates `staking_power_from_burn` using the formula: `MIN(100, (total_gmc_burned_for_boost / principal_amount) * 100)`.
    *   Calls the `RankingRewardsContract` to log the burn: `log_burn(user, amount_to_burn)`.
    *   Distributes the USDT fee: 40% to Team, 50% to Staking Fund (USDT), 10% to `RankingRewardsContract`.

*   `withdraw_principal_long(stake_position_id: Pubkey)`
    *   Checks if `now >= start_timestamp + 12 months`.
    *   Transfers the `principal_amount` of GMC from the vault back to the user.
    *   Closes the `StakePosition` account.

*   `emergency_unstake_long(stake_position_id: Pubkey)`
    *   Checks if `now < start_timestamp + 12 months`.
    *   **Penalty (as per Fee Table, Row 3):**
        *   Requires a pre-transaction of `5 USDT` from the user.
        *   Calculates a 50% penalty on the `principal_amount` in GMC.
        *   Calculates 80% of the accrued but unclaimed GMC interest.
    *   The user receives back: `principal_amount - gmc_capital_penalty`.
    *   Distributes the GMC penalty: 30% to Burn, 50% to Staking Fund (GMC), 20% to `RankingRewardsContract`.
    *   Closes the `StakePosition` account.

**4.3. Staking Functions (Flexible):**

*   `stake_flexible(amount: u64)`
    *   Requirements: `amount >= 50 GMC`.
    *   USDT fee logic is identical to `stake_long_term`.
    *   Creates a `StakePosition` with `stake_type = Flexible`.

*   `withdraw_flexible(stake_position_id: Pubkey, amount_to_withdraw: u64)`
    *   **Cancellation Fee (as per Table, Row 4):** A 2.5% fee on the `amount_to_withdraw` is withheld.
    *   Transfers `amount_to_withdraw * 97.5%` of GMC to the user.
    *   The 2.5% GMC fee is distributed: 40% to Team, 40% to Staking Fund (GMC), 20% to `RankingRewardsContract`.
    *   If the `principal_amount` reaches zero, the `StakePosition` account is closed.

**4.4. Reward and Affiliate Functions:**

*   `register_referrer(referrer_address: Pubkey)`
    *   Can only be called once by a new user.
    *   Stores the `referrer_address` in the caller's `UserStakeInfo` account.
    *   Calls the `RankingRewardsContract` to log the recruitment: `log_referral(referrer_address)`.

*   `claim_rewards(stake_position_id: Pubkey)`
    *   Calculates the accrued GMC interest since `last_reward_claim_timestamp`.
    *   **APY Calculation (Long-Term):**
        1.  `base_power = staking_power_from_burn`
        2.  `affiliate_boost = calculate_affiliate_boost(user)` (see section 4.5)
        3.  `total_power = base_power + affiliate_boost`
        4.  `APY = 10% + ((total_power / 100) * (280% - 10%))`
    *   **APY Calculation (Flexible):** Uses a configurable APY rate (5-70%) stored in `GlobalState`.
    *   **Withdrawal Fee (GMC - Table, Row 5):** Withholds 1% of the calculated interest.
    *   Transfers 99% of the GMC interest to the user.
    *   Distributes the 1% fee: 40% to Burn, 50% to Staking Fund (GMC), 10% to `RankingRewardsContract`.
    *   Updates `last_reward_claim_timestamp`.
    *   **Pagamento:** A cada 30 dias, conforme tabela.md.

*   `claim_usdt_rewards()`
    *   Calculates the user's proportional share of the USDT rewards pool (accumulated from entry fees).
    *   **Withdrawal Fee (USDT - Table, Row 8):** Withholds 0.3% of the withdrawn USDT amount.
    *   Transfers 99.7% of the USDT to the user.
    *   Distributes the 0.3% fee: 40% to Team, 40% to Staking Fund (USDT), 20% to `RankingRewardsContract`.

**4.5. Affiliate Boost Calculation Logic:**
*   `calculate_affiliate_boost(user: Pubkey)` -> `u8`
    *   This function will be computationally expensive and must be optimized.
    *   It traverses the user's referral tree up to 6 levels deep.
    *   For each affiliate found, it reads the `staking_power_from_burn` from their long-term staking position(s).
    *   It sums the weighted power: `total_boost += affiliate_power * percentage_for_level` (Level 1: 20%, Level 2: 15%, etc.).
    *   Returns `MIN(50, total_boost)`.

---

### **5. Contract 3: `RankingRewardsContract`**

This program acts as a fund collector and activity ledger, with distribution logic.

**5.1. Data Structures:**
*   `RankingState`: A singleton account to store the funds (`monthly_pool_gmc`, `monthly_pool_usdt`, `annual_pool_gmc`, `annual_pool_usdt`) and the Top 20 Holders list (which could be a separate, updatable data account).
*   `UserActivity`: A per-user account to track metrics.
    *   `monthly_tx_count`: u32
    *   `monthly_referrals_count`: u32
    *   `monthly_burn_volume`: u64
    *   `annual_burn_volume`: u64

**5.2. Functions:**
*   `deposit_funds(token_type: Enum, amount: u64)`: A function to receive GMC and USDT from the other contracts.
*   `log_transaction(user: Pubkey)`: Increments `monthly_tx_count`. (Note: Tracking all transactions on-chain can be expensive. An off-chain solution with an oracle may be necessary for this metric).
*   `log_referral(user: Pubkey)`: Increments `monthly_referrals_count`. Called by the `StakingContract`.
*   `log_burn(user: Pubkey, amount: u64)`: Increments `monthly_burn_volume` and `annual_burn_volume`. Called by the `StakingContract`.
*   `distribute_monthly_rewards()`:
    *   Function restricted to an admin authority.
    *   Reads the data from all `UserActivity` accounts.
    *   Identifies the Top 7 in each category (Transactors, Recruiters, Burners).
    *   Checks if the winners are not on the exclusion list (Top 20 Holders).
    *   Distributes funds from the monthly pools to the winners.
    *   Resets the monthly counters in all `UserActivity` accounts.
*   `distribute_annual_rewards()`:
    *   Similar to the monthly function, but for the Top 12 Burners of the Year and uses the annual pools.
    *   Resets the `annual_burn_volume` counter.

---

### **6. Contract 4: `VestingContract`**

A standard program for the linear release of tokens.

**6.1. Data Structures:**
*   `VestingSchedule`: An account for each vesting schedule.
    *   `beneficiary`: Pubkey
    *   `total_amount`: u64
    *   `start_timestamp`: i64
    *   `duration_seconds`: i64
    *   `amount_released`: u64

**6.2. Functions:**
*   `create_schedule(beneficiary, amount, duration)`: An admin function to create a new schedule. The document specifies a 5-year schedule for the Reserve.
*   `release()`: A public function that anyone can call for a `VestingSchedule`.
    *   Calculates the amount of releasable tokens based on the time elapsed since the start.
    *   Transfers the releasable amount (if any) to the `beneficiary`.
    *   Updates `amount_released`.


    Com certeza! Com base no arquivo `Regras do staking`, criei duas tabelas que organizam e apresentam claramente todas as regras de taxas e as condições dos planos de staking, exatamente como em uma planilha.

### **Tabela 1: Regras de Taxas do Ecossistema GMC**

Esta tabela detalha cada taxa, seu valor, como é paga e para onde os fundos são destinados.

| # | Tipo de Taxa | Valor e Regras | Forma de Pagamento | Destino / Finalidade |
| :-- | :--- | :--- | :--- | :--- |
| **1** | **Taxa de Transação GMC** | **0,5%** por transação | GMC | • **50%** Queima <br> • **40%** Fundo de Staking <br> • **10%** Programa de Ranking |
| **2** | **Fee de Entrada no Staking** (Longo e Flexível) | Taxa variável em USDT, calculada sobre a quantidade de GMC depositado:<br>• **Até 1.000 GMC:** 10% <br>• **1.001 a 10.000 GMC:** 5% <br>• **10.001 a 100.000 GMC:** 2,5% <br>• **100.001 a 500.000 GMC:** 1% <br>• **Acima de 500.000 GMC:** 0,5% | USDT-SPL (Solana) | • **40%** Equipe <br> • **40%** Fundo de Staking <br> • **20%** Programa de Ranking |
| **3** | **Penalidade de Saque Antecipado** (Staking Longo) | **5 USDT** + **50%** do capital + **80%** dos juros | GMC | • **30%** Queima <br> • **50%** Fundo de Staking <br> • **20%** Programa de Ranking |
| **4** | **Taxa de Cancelamento** (Staking Flexível) | **2,5%** sobre o capital | GMC | • **40%** Equipe <br> • **40%** Fundo de Staking <br> • **20%** Programa de Ranking |
| **5** | **Taxa de Saque de Juros** (GMC) | **1%** sobre o valor sacado | GMC | • **40%** Queima <br> • **50%** Fundo de Staking <br> • **10%** Programa de Ranking |
| **7** | **Fee para Burn-for-Boost** | **0,8 USDT** + **10% do GMC** (da queima) por operação | USDT-SPL | • **40%** Equipe <br> • **50%** Fundo de Staking <br> • **10%** Programa de Ranking |
| **8** | **Taxa de Saque de Recompensas** (em USDT) | **0,3%** sobre o valor sacado | USDT-SPL | • **40%** Equipe <br> • **40%** Fundo de Staking <br> • **20%** Programa de Ranking |

---

### **Tabela 2: Resumo dos Planos de Staking**

Esta tabela compara as principais características dos dois tipos de staking disponíveis.

| Tipo de Staking | APY Anual (Rendimento) | Pagamento dos Juros | Investimento Mínimo | Fundo Inicial do Pool |
| :--- | :--- | :--- | :--- | :--- |
| **Staking de Longo Prazo (Staking Burn)** | **10% - 280%** APY | Pagamentos diários | 100 GMC | **70.000.000 GMC** |
| **Staking Flexível** | **5% - 70%** APY | Pagamento a cada 30 dias | 50 GMC | **70.000.000 GMC** |

---
**Observação Importante do Documento:**
> OBS: No primeiro ano o vamos tentar pagar da melhor forma possível subisidiando do fundo, mas para membros(carteiras) que se engajarem na queima de moedas.