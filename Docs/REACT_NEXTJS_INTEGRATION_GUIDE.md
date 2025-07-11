# 🚀 GMC Ecosystem - React/Next.js Integration Guide

## 📋 Visão Geral

Este guia fornece exemplos práticos de como integrar o frontend React/Next.js com o GMC Ecosystem, incluindo configuração, hooks customizados, components e interação com todos os 5 smart contracts.

## 🏗️ Setup do Projeto

### 1. Inicialização do Projeto

```bash
# Criar projeto Next.js com TypeScript
npx create-next-app@latest gmc-frontend --typescript --tailwind --eslint --app

cd gmc-frontend

# Instalar dependências do Solana
npm install @solana/web3.js @solana/wallet-adapter-base @solana/wallet-adapter-react @solana/wallet-adapter-react-ui @solana/wallet-adapter-wallets @coral-xyz/anchor

# Instalar dependências adicionais
npm install @radix-ui/react-dialog @radix-ui/react-toast lucide-react clsx tailwind-merge

# Instalar dependências de desenvolvimento
npm install -D @types/bn.js
```

### 2. Configuração do Ambiente

```typescript
// config/constants.ts
import { PublicKey } from '@solana/web3.js';

export const PROGRAM_IDS = {
  GMC_TOKEN: new PublicKey("9cxPbpRkTkoWqs2gj6B84ojM41DUfLWKodmUjd5KaYCx"),
  GMC_STAKING: new PublicKey("9xef742EHoWyB6eJFeY9qD8nsVadsXvLByL8J6Lhvtz1"),
  GMC_RANKING: new PublicKey("CUM2m3SXR1S8Yg8rPBUVv7fWEN2n5JzR3W3vA1Xv2b7b"),
  GMC_TREASURY: new PublicKey("GMCm26i3oB35nCHfswhN5aXgx1sxyxxa9f5c4hL3p8v"),
  GMC_VESTING: new PublicKey("6PSoDRr6cMMY2db3d1y37tcLNp8uWFWd2kH7CjXqey7U")
} as const;

export const NETWORK = {
  DEVNET: 'https://api.devnet.solana.com',
  MAINNET: 'https://api.mainnet-beta.solana.com',
  LOCALNET: 'http://localhost:8899'
} as const;

export const STAKING_CONSTANTS = {
  MIN_STAKE_LONG_TERM: 100_000_000_000, // 100 GMC
  MIN_STAKE_FLEXIBLE: 50_000_000_000,   // 50 GMC
  LOCK_PERIOD_MONTHS: 12,
  BURN_FOR_BOOST_USDT_FEE: 800_000,     // 0.8 USDT
  BURN_FOR_BOOST_GMC_FEE_PERCENT: 10,
  EMERGENCY_UNSTAKE_USDT_FEE: 5_000_000, // 5 USDT
  EMERGENCY_UNSTAKE_GMC_PENALTY: 50,     // 50%
  FLEXIBLE_WITHDRAWAL_FEE: 2.5,          // 2.5%
  MAX_AFFILIATE_LEVELS: 6,
  MAX_AFFILIATE_BOOST: 50,               // 50%
  CLAIM_REWARDS_GMC_FEE: 1,              // 1%
  CLAIM_REWARDS_USDT_FEE: 0.3,           // 0.3%
} as const;
```

### 3. Tipos TypeScript

```typescript
// types/gmc.ts
import { PublicKey } from '@solana/web3.js';

export type StakeType = "LongTerm" | "Flexible";

export interface StakePosition {
  owner: PublicKey;
  stake_type: StakeType;
  principal_amount: number;
  start_timestamp: number;
  last_reward_claim_timestamp: number;
  is_active: boolean;
  position_id: number;
  long_term_data?: {
    total_gmc_burned_for_boost: number;
    staking_power_from_burn: number;
    affiliate_power_boost: number;
  };
}

export interface UserStakeInfo {
  owner: PublicKey;
  referrer: PublicKey;
  total_positions: number;
  active_positions: number;
}

export interface GlobalState {
  authority: PublicKey;
  team_wallet: PublicKey;
  ranking_contract: PublicKey;
  burn_address: PublicKey;
  total_staked_long_term: number;
  total_staked_flexible: number;
  total_rewards_distributed: number;
  is_paused: boolean;
}

export interface UserBalances {
  gmc_balance: number;
  usdt_balance: number;
  staked_gmc: number;
  available_rewards_gmc: number;
  available_rewards_usdt: number;
  total_burned_gmc: number;
}

export interface StakingPositionDisplay {
  position_id: number;
  type: StakeType;
  principal_amount: number;
  current_apy: number;
  time_remaining: number;
  rewards_earned: number;
  can_withdraw: boolean;
  staking_power: number;
}

export interface RankingData {
  transactions: Array<{
    user: PublicKey;
    count: number;
    rank: number;
  }>;
  referrals: Array<{
    user: PublicKey;
    count: number;
    rank: number;
  }>;
  burns: Array<{
    user: PublicKey;
    amount: number;
    rank: number;
  }>;
}
```

## 🔧 Configuração do Wallet Provider

```typescript
// providers/WalletProvider.tsx
'use client';

import React, { useMemo } from 'react';
import { ConnectionProvider, WalletProvider } from '@solana/wallet-adapter-react';
import { WalletAdapterNetwork } from '@solana/wallet-adapter-base';
import { WalletModalProvider } from '@solana/wallet-adapter-react-ui';
import { PhantomWalletAdapter, SolflareWalletAdapter } from '@solana/wallet-adapter-wallets';
import { clusterApiUrl } from '@solana/web3.js';

require('@solana/wallet-adapter-react-ui/styles.css');

export default function AppWalletProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  const network = WalletAdapterNetwork.Devnet;
  const endpoint = useMemo(() => clusterApiUrl(network), [network]);
  
  const wallets = useMemo(
    () => [
      new PhantomWalletAdapter(),
      new SolflareWalletAdapter(),
    ],
    []
  );

  return (
    <ConnectionProvider endpoint={endpoint}>
      <WalletProvider wallets={wallets} autoConnect>
        <WalletModalProvider>
          {children}
        </WalletModalProvider>
      </WalletProvider>
    </ConnectionProvider>
  );
}
```

## 🎣 Hooks Customizados

### 1. Hook para Anchor Program

```typescript
// hooks/useAnchorProgram.ts
import { useMemo } from 'react';
import { useConnection, useWallet } from '@solana/wallet-adapter-react';
import { AnchorProvider, Program, web3 } from '@coral-xyz/anchor';
import { PROGRAM_IDS } from '@/config/constants';

export function useAnchorProgram() {
  const { connection } = useConnection();
  const wallet = useWallet();

  const provider = useMemo(() => {
    if (!wallet.publicKey || !wallet.signTransaction) {
      return null;
    }
    
    return new AnchorProvider(
      connection,
      wallet as any,
      { commitment: 'confirmed' }
    );
  }, [connection, wallet]);

  const programs = useMemo(() => {
    if (!provider) return null;

    return {
      token: new Program(gmcTokenIdl, PROGRAM_IDS.GMC_TOKEN, provider),
      staking: new Program(gmcStakingIdl, PROGRAM_IDS.GMC_STAKING, provider),
      ranking: new Program(gmcRankingIdl, PROGRAM_IDS.GMC_RANKING, provider),
      treasury: new Program(gmcTreasuryIdl, PROGRAM_IDS.GMC_TREASURY, provider),
      vesting: new Program(gmcVestingIdl, PROGRAM_IDS.GMC_VESTING, provider),
    };
  }, [provider]);

  return { provider, programs };
}
```

### 2. Hook para Staking

```typescript
// hooks/useStaking.ts
import { useState, useCallback } from 'react';
import { useWallet } from '@solana/wallet-adapter-react';
import { PublicKey, SystemProgram } from '@solana/web3.js';
import { BN } from '@coral-xyz/anchor';
import { useAnchorProgram } from './useAnchorProgram';
import { STAKING_CONSTANTS } from '@/config/constants';
import { StakeType } from '@/types/gmc';

export function useStaking() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { publicKey } = useWallet();
  const { programs } = useAnchorProgram();

  const stakeLongTerm = useCallback(async (amount: number) => {
    if (!programs?.staking || !publicKey) {
      throw new Error('Wallet not connected or program not loaded');
    }

    setLoading(true);
    setError(null);

    try {
      // Validar quantidade mínima
      if (amount < STAKING_CONSTANTS.MIN_STAKE_LONG_TERM) {
        throw new Error(`Minimum stake amount is ${STAKING_CONSTANTS.MIN_STAKE_LONG_TERM / 1e9} GMC`);
      }

      // Derivar PDAs
      const [globalStatePda] = PublicKey.findProgramAddressSync(
        [Buffer.from("global_state")],
        programs.staking.programId
      );

      const [userStakeInfoPda] = PublicKey.findProgramAddressSync(
        [Buffer.from("user_stake_info"), publicKey.toBuffer()],
        programs.staking.programId
      );

      const [stakingVaultPda] = PublicKey.findProgramAddressSync(
        [Buffer.from("staking_vault")],
        programs.staking.programId
      );

      // Obter número de posições do usuário
      let userStakeInfo;
      try {
        userStakeInfo = await programs.staking.account.userStakeInfo.fetch(userStakeInfoPda);
      } catch {
        // Usuário não tem informações ainda, será criado
        userStakeInfo = { totalPositions: 0 };
      }

      const positionId = (userStakeInfo.totalPositions || 0) + 1;

      const [stakePositionPda] = PublicKey.findProgramAddressSync(
        [
          Buffer.from("stake_position"),
          publicKey.toBuffer(),
          new BN(positionId).toArrayLike(Buffer, "le", 8)
        ],
        programs.staking.programId
      );

      // Obter contas de token do usuário
      const userGmcAccount = await getAssociatedTokenAddress(
        GMC_MINT_ADDRESS, // Definir em constants
        publicKey
      );

      const tx = await programs.staking.methods
        .stakeLongTerm(new BN(amount))
        .accounts({
          user: publicKey,
          globalState: globalStatePda,
          userStakeInfo: userStakeInfoPda,
          stakePosition: stakePositionPda,
          userTokenAccount: userGmcAccount,
          stakingVault: stakingVaultPda,
          tokenProgram: TOKEN_PROGRAM_ID,
          systemProgram: SystemProgram.programId,
        })
        .rpc();

      return tx;
    } catch (err: any) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, [programs, publicKey]);

  const stakeFlexible = useCallback(async (amount: number) => {
    // Implementação similar ao stakeLongTerm
    // mas usando stakeFlexible method
  }, [programs, publicKey]);

  const burnForBoost = useCallback(async (
    positionId: number, 
    burnAmount: number
  ) => {
    if (!programs?.staking || !publicKey) {
      throw new Error('Wallet not connected or program not loaded');
    }

    setLoading(true);
    setError(null);

    try {
      const [globalStatePda] = PublicKey.findProgramAddressSync(
        [Buffer.from("global_state")],
        programs.staking.programId
      );

      const [stakePositionPda] = PublicKey.findProgramAddressSync(
        [
          Buffer.from("stake_position"),
          publicKey.toBuffer(),
          new BN(positionId).toArrayLike(Buffer, "le", 8)
        ],
        programs.staking.programId
      );

      const userGmcAccount = await getAssociatedTokenAddress(
        GMC_MINT_ADDRESS,
        publicKey
      );

      const userUsdtAccount = await getAssociatedTokenAddress(
        USDT_MINT_ADDRESS,
        publicKey
      );

      const tx = await programs.staking.methods
        .burnForBoost(new BN(burnAmount))
        .accounts({
          user: publicKey,
          globalState: globalStatePda,
          stakePosition: stakePositionPda,
          userTokenAccount: userGmcAccount,
          burnAddressAccount: BURN_ADDRESS, // Definir em constants
          userUsdtAccount: userUsdtAccount,
          teamUsdtAccount: TEAM_USDT_ACCOUNT, // Definir em constants
          stakingUsdtVault: STAKING_USDT_VAULT, // Definir em constants
          rankingUsdtAccount: RANKING_USDT_ACCOUNT, // Definir em constants
          tokenProgram: TOKEN_PROGRAM_ID,
        })
        .rpc();

      return tx;
    } catch (err: any) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, [programs, publicKey]);

  const calculateAPY = useCallback((
    stakingPower: number, 
    affiliateBoost: number, 
    isLongTerm: boolean
  ): number => {
    const baseAPY = isLongTerm ? 10 : 5;
    const maxAPY = isLongTerm ? 280 : 70;
    const totalPower = Math.min(100, stakingPower + affiliateBoost);
    const bonusAPY = (totalPower / 100) * (maxAPY - baseAPY);
    return baseAPY + bonusAPY;
  }, []);

  return {
    stakeLongTerm,
    stakeFlexible,
    burnForBoost,
    calculateAPY,
    loading,
    error,
  };
}
```

### 3. Hook para Ranking

```typescript
// hooks/useRanking.ts
import { useState, useCallback, useEffect } from 'react';
import { useWallet } from '@solana/wallet-adapter-react';
import { PublicKey } from '@solana/web3.js';
import { useAnchorProgram } from './useAnchorProgram';
import { RankingData } from '@/types/gmc';

export function useRanking() {
  const [ranking, setRanking] = useState<RankingData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { publicKey } = useWallet();
  const { programs } = useAnchorProgram();

  const fetchRankingData = useCallback(async () => {
    if (!programs?.ranking) return;

    setLoading(true);
    try {
      // Simular busca de dados de ranking
      // Em implementação real, seria através de um indexer ou API
      const mockRankingData: RankingData = {
        transactions: [
          { user: new PublicKey("..."), count: 1250, rank: 1 },
          { user: new PublicKey("..."), count: 980, rank: 2 },
          // ... mais dados
        ],
        referrals: [
          { user: new PublicKey("..."), count: 45, rank: 1 },
          { user: new PublicKey("..."), count: 32, rank: 2 },
          // ... mais dados
        ],
        burns: [
          { user: new PublicKey("..."), amount: 15000, rank: 1 },
          { user: new PublicKey("..."), amount: 12000, rank: 2 },
          // ... mais dados
        ],
      };

      setRanking(mockRankingData);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [programs]);

  const claimReward = useCallback(async (
    amountGmc: number,
    amountUsdt: number,
    merkleProof: Array<Array<number>>
  ) => {
    if (!programs?.ranking || !publicKey) {
      throw new Error('Wallet not connected or program not loaded');
    }

    try {
      const [rankingStatePda] = PublicKey.findProgramAddressSync(
        [Buffer.from("ranking_state")],
        programs.ranking.programId
      );

      const tx = await programs.ranking.methods
        .claimReward(amountGmc, amountUsdt, merkleProof)
        .accounts({
          user: publicKey,
          rankingState: rankingStatePda,
        })
        .rpc();

      return tx;
    } catch (err: any) {
      setError(err.message);
      throw err;
    }
  }, [programs, publicKey]);

  useEffect(() => {
    fetchRankingData();
  }, [fetchRankingData]);

  return {
    ranking,
    claimReward,
    fetchRankingData,
    loading,
    error,
  };
}
```

## 🎨 Components de UI

### 1. Dashboard Principal

```typescript
// components/Dashboard.tsx
'use client';

import React from 'react';
import { useWallet } from '@solana/wallet-adapter-react';
import { WalletMultiButton } from '@solana/wallet-adapter-react-ui';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatGMC, formatUSDT } from '@/utils/format';
import { UserBalances } from '@/types/gmc';

interface DashboardProps {
  balances: UserBalances;
  isLoading: boolean;
}

export default function Dashboard({ balances, isLoading }: DashboardProps) {
  const { connected } = useWallet();

  if (!connected) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen">
        <h1 className="text-4xl font-bold mb-8">GMC Ecosystem</h1>
        <WalletMultiButton />
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="container mx-auto p-6">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold">GMC Dashboard</h1>
        <WalletMultiButton />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        <Card>
          <CardHeader>
            <CardTitle>GMC Balance</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold text-green-600">
              {formatGMC(balances.gmc_balance)}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>USDT Balance</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold text-blue-600">
              {formatUSDT(balances.usdt_balance)}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Staked GMC</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold text-purple-600">
              {formatGMC(balances.staked_gmc)}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>GMC Rewards</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold text-yellow-600">
              {formatGMC(balances.available_rewards_gmc)}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>USDT Rewards</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold text-indigo-600">
              {formatUSDT(balances.available_rewards_usdt)}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Total Burned</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold text-red-600">
              {formatGMC(balances.total_burned_gmc)}
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
```

### 2. Interface de Staking

```typescript
// components/StakingInterface.tsx
import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { useStaking } from '@/hooks/useStaking';
import { STAKING_CONSTANTS } from '@/config/constants';
import { StakeType } from '@/types/gmc';

export default function StakingInterface() {
  const [amount, setAmount] = useState('');
  const [stakeType, setStakeType] = useState<StakeType>('LongTerm');
  const { stakeLongTerm, stakeFlexible, calculateAPY, loading, error } = useStaking();

  const handleStake = async () => {
    const stakeAmount = parseFloat(amount) * 1e9; // Converter para lamports
    
    try {
      if (stakeType === 'LongTerm') {
        await stakeLongTerm(stakeAmount);
      } else {
        await stakeFlexible(stakeAmount);
      }
      
      // Reset form
      setAmount('');
      // Show success message
    } catch (err) {
      console.error('Stake error:', err);
    }
  };

  const estimatedAPY = calculateAPY(0, 0, stakeType === 'LongTerm');
  const minAmount = stakeType === 'LongTerm' 
    ? STAKING_CONSTANTS.MIN_STAKE_LONG_TERM / 1e9 
    : STAKING_CONSTANTS.MIN_STAKE_FLEXIBLE / 1e9;

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader>
        <CardTitle>Stake GMC Tokens</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div>
          <label className="block text-sm font-medium mb-2">Stake Type</label>
          <Select value={stakeType} onValueChange={(value) => setStakeType(value as StakeType)}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="LongTerm">
                Long-Term (12 months) - Up to 280% APY
              </SelectItem>
              <SelectItem value="Flexible">
                Flexible (No lock) - Up to 70% APY
              </SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div>
          <label className="block text-sm font-medium mb-2">
            Amount (Min: {minAmount} GMC)
          </label>
          <Input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder={`Minimum ${minAmount} GMC`}
            min={minAmount}
            step="0.1"
          />
        </div>

        <div className="bg-gray-50 p-3 rounded-lg">
          <div className="flex justify-between text-sm">
            <span>Estimated Base APY:</span>
            <span className="font-semibold">{estimatedAPY}%</span>
          </div>
          <div className="flex justify-between text-sm">
            <span>Lock Period:</span>
            <span>{stakeType === 'LongTerm' ? '12 months' : 'None'}</span>
          </div>
          <div className="flex justify-between text-sm">
            <span>Boost Potential:</span>
            <span>{stakeType === 'LongTerm' ? '+270%' : '+35%'}</span>
          </div>
        </div>

        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-3 py-2 rounded">
            {error}
          </div>
        )}

        <Button 
          onClick={handleStake} 
          disabled={loading || !amount || parseFloat(amount) < minAmount}
          className="w-full"
        >
          {loading ? 'Staking...' : `Stake ${amount || '0'} GMC`}
        </Button>
      </CardContent>
    </Card>
  );
}
```

### 3. Component de Burn-for-Boost

```typescript
// components/BurnForBoost.tsx
import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useStaking } from '@/hooks/useStaking';
import { STAKING_CONSTANTS } from '@/config/constants';
import { StakingPositionDisplay } from '@/types/gmc';

interface BurnForBoostProps {
  position: StakingPositionDisplay;
  onSuccess: () => void;
}

export default function BurnForBoost({ position, onSuccess }: BurnForBoostProps) {
  const [burnAmount, setBurnAmount] = useState('');
  const { burnForBoost, calculateAPY, loading, error } = useStaking();

  const handleBurn = async () => {
    const burnAmountLamports = parseFloat(burnAmount) * 1e9;
    
    try {
      await burnForBoost(position.position_id, burnAmountLamports);
      setBurnAmount('');
      onSuccess();
    } catch (err) {
      console.error('Burn error:', err);
    }
  };

  const currentStakingPower = position.staking_power;
  const newStakingPower = Math.min(
    100,
    currentStakingPower + (parseFloat(burnAmount || '0') / (position.principal_amount / 1e9)) * 100
  );
  
  const currentAPY = position.current_apy;
  const newAPY = calculateAPY(newStakingPower, 0, true); // Assumindo long-term
  const apyIncrease = newAPY - currentAPY;

  const usdtFee = STAKING_CONSTANTS.BURN_FOR_BOOST_USDT_FEE / 1e6;
  const gmcFee = parseFloat(burnAmount || '0') * (STAKING_CONSTANTS.BURN_FOR_BOOST_GMC_FEE_PERCENT / 100);
  const totalGmcBurned = parseFloat(burnAmount || '0') + gmcFee;

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader>
        <CardTitle>🔥 Burn for Boost</CardTitle>
        <p className="text-sm text-gray-600">
          Burn GMC tokens to permanently increase your APY
        </p>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="bg-blue-50 p-3 rounded-lg">
          <div className="flex justify-between text-sm">
            <span>Current APY:</span>
            <span className="font-semibold">{currentAPY.toFixed(2)}%</span>
          </div>
          <div className="flex justify-between text-sm">
            <span>Current Staking Power:</span>
            <span className="font-semibold">{currentStakingPower}%</span>
          </div>
          <div className="flex justify-between text-sm">
            <span>Principal Amount:</span>
            <span className="font-semibold">{(position.principal_amount / 1e9).toFixed(2)} GMC</span>
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium mb-2">
            GMC Amount to Burn
          </label>
          <Input
            type="number"
            value={burnAmount}
            onChange={(e) => setBurnAmount(e.target.value)}
            placeholder="Enter amount to burn"
            min="0"
            step="0.1"
          />
        </div>

        {burnAmount && parseFloat(burnAmount) > 0 && (
          <div className="bg-yellow-50 p-3 rounded-lg border border-yellow-200">
            <h4 className="font-medium text-yellow-800 mb-2">Burn Preview</h4>
            <div className="space-y-1 text-sm text-yellow-700">
              <div className="flex justify-between">
                <span>GMC to burn:</span>
                <span>{burnAmount} GMC</span>
              </div>
              <div className="flex justify-between">
                <span>GMC fee (10%):</span>
                <span>{gmcFee.toFixed(4)} GMC</span>
              </div>
              <div className="flex justify-between">
                <span>USDT fee:</span>
                <span>{usdtFee} USDT</span>
              </div>
              <div className="flex justify-between font-medium">
                <span>Total GMC burned:</span>
                <span>{totalGmcBurned.toFixed(4)} GMC</span>
              </div>
              <hr className="border-yellow-300" />
              <div className="flex justify-between">
                <span>New Staking Power:</span>
                <span>{newStakingPower.toFixed(1)}%</span>
              </div>
              <div className="flex justify-between">
                <span>New APY:</span>
                <span className="font-semibold text-green-600">{newAPY.toFixed(2)}%</span>
              </div>
              <div className="flex justify-between">
                <span>APY Increase:</span>
                <span className="font-semibold text-green-600">+{apyIncrease.toFixed(2)}%</span>
              </div>
            </div>
          </div>
        )}

        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-3 py-2 rounded">
            {error}
          </div>
        )}

        <Button 
          onClick={handleBurn} 
          disabled={loading || !burnAmount || parseFloat(burnAmount) <= 0}
          className="w-full bg-orange-600 hover:bg-orange-700"
        >
          {loading ? 'Burning...' : `🔥 Burn ${burnAmount || '0'} GMC`}
        </Button>

        <div className="text-xs text-gray-500">
          ⚠️ This action is permanent and cannot be undone. Your APY boost will be maintained for the entire staking duration.
        </div>
      </CardContent>
    </Card>
  );
}
```

### 4. Display de Ranking

```typescript
// components/RankingDisplay.tsx
import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { useRanking } from '@/hooks/useRanking';
import { formatGMC } from '@/utils/format';

export default function RankingDisplay() {
  const { ranking, loading, error } = useRanking();

  if (loading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 text-red-700 p-4 rounded">
        Error loading ranking data: {error}
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">🏆 Monthly Rankings</h2>
      
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Top Transactors */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              💼 Top Transactors
              <Badge variant="outline">Top 7</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {ranking?.transactions.slice(0, 7).map((user, index) => (
                <div key={user.user.toString()} className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className={`text-lg ${index < 3 ? 'text-yellow-500' : ''}`}>
                      {index === 0 ? '🥇' : index === 1 ? '🥈' : index === 2 ? '🥉' : `#${index + 1}`}
                    </span>
                    <span className="text-sm text-gray-600">
                      {user.user.toString().slice(0, 8)}...
                    </span>
                  </div>
                  <span className="font-semibold">{user.count.toLocaleString()}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* Top Recruiters */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              🤝 Top Recruiters
              <Badge variant="outline">Top 7</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {ranking?.referrals.slice(0, 7).map((user, index) => (
                <div key={user.user.toString()} className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className={`text-lg ${index < 3 ? 'text-yellow-500' : ''}`}>
                      {index === 0 ? '🥇' : index === 1 ? '🥈' : index === 2 ? '🥉' : `#${index + 1}`}
                    </span>
                    <span className="text-sm text-gray-600">
                      {user.user.toString().slice(0, 8)}...
                    </span>
                  </div>
                  <span className="font-semibold">{user.count}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* Top Burners */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              🔥 Top Burners
              <Badge variant="outline">Top 7</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {ranking?.burns.slice(0, 7).map((user, index) => (
                <div key={user.user.toString()} className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className={`text-lg ${index < 3 ? 'text-yellow-500' : ''}`}>
                      {index === 0 ? '🥇' : index === 1 ? '🥈' : index === 2 ? '🥉' : `#${index + 1}`}
                    </span>
                    <span className="text-sm text-gray-600">
                      {user.user.toString().slice(0, 8)}...
                    </span>
                  </div>
                  <span className="font-semibold">{formatGMC(user.amount * 1e9)}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>📅 Next Distribution</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-center">
            <div>
              <div className="text-2xl font-bold text-blue-600">21</div>
              <div className="text-sm text-gray-600">Monthly Winners</div>
            </div>
            <div>
              <div className="text-2xl font-bold text-green-600">12</div>
              <div className="text-sm text-gray-600">Annual Winners</div>
            </div>
            <div>
              <div className="text-2xl font-bold text-purple-600">90%</div>
              <div className="text-sm text-gray-600">Monthly Pool</div>
            </div>
            <div>
              <div className="text-2xl font-bold text-orange-600">10%</div>
              <div className="text-sm text-gray-600">Annual Pool</div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
```

## 🛠️ Utilitários

```typescript
// utils/format.ts
export function formatGMC(lamports: number): string {
  return (lamports / 1e9).toLocaleString('en-US', { 
    minimumFractionDigits: 2,
    maximumFractionDigits: 2 
  }) + ' GMC';
}

export function formatUSDT(amount: number): string {
  return (amount / 1e6).toLocaleString('en-US', { 
    minimumFractionDigits: 2,
    maximumFractionDigits: 2 
  }) + ' USDT';
}

export function formatAPY(apy: number): string {
  return apy.toFixed(2) + '%';
}

export function formatTimeRemaining(endTimestamp: number): string {
  const now = Date.now() / 1000;
  const remaining = endTimestamp - now;
  
  if (remaining <= 0) return 'Unlocked';
  
  const days = Math.floor(remaining / (24 * 60 * 60));
  const hours = Math.floor((remaining % (24 * 60 * 60)) / (60 * 60));
  
  if (days > 0) {
    return `${days}d ${hours}h`;
  } else {
    return `${hours}h`;
  }
}

export function shortenAddress(address: string, chars = 4): string {
  return `${address.slice(0, chars)}...${address.slice(-chars)}`;
}
```

## 🔄 Context para Estado Global

```typescript
// contexts/GMCContext.tsx
'use client';

import React, { createContext, useContext, useReducer, useEffect } from 'react';
import { useWallet } from '@solana/wallet-adapter-react';
import { UserBalances, StakingPositionDisplay } from '@/types/gmc';

interface GMCState {
  balances: UserBalances | null;
  positions: StakingPositionDisplay[];
  loading: boolean;
  error: string | null;
}

interface GMCContextType extends GMCState {
  refreshData: () => Promise<void>;
  updateBalance: (balances: UserBalances) => void;
  updatePositions: (positions: StakingPositionDisplay[]) => void;
}

const GMCContext = createContext<GMCContextType | null>(null);

type Action = 
  | { type: 'SET_LOADING'; payload: boolean }
  | { type: 'SET_ERROR'; payload: string | null }
  | { type: 'SET_BALANCES'; payload: UserBalances }
  | { type: 'SET_POSITIONS'; payload: StakingPositionDisplay[] };

function gmcReducer(state: GMCState, action: Action): GMCState {
  switch (action.type) {
    case 'SET_LOADING':
      return { ...state, loading: action.payload };
    case 'SET_ERROR':
      return { ...state, error: action.payload, loading: false };
    case 'SET_BALANCES':
      return { ...state, balances: action.payload, loading: false };
    case 'SET_POSITIONS':
      return { ...state, positions: action.payload, loading: false };
    default:
      return state;
  }
}

export function GMCProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(gmcReducer, {
    balances: null,
    positions: [],
    loading: false,
    error: null,
  });

  const { publicKey, connected } = useWallet();

  const refreshData = async () => {
    if (!connected || !publicKey) return;

    dispatch({ type: 'SET_LOADING', payload: true });
    
    try {
      // Fetch user balances
      const balances = await fetchUserBalances(publicKey);
      dispatch({ type: 'SET_BALANCES', payload: balances });

      // Fetch user positions
      const positions = await fetchUserPositions(publicKey);
      dispatch({ type: 'SET_POSITIONS', payload: positions });

    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
    }
  };

  const updateBalance = (balances: UserBalances) => {
    dispatch({ type: 'SET_BALANCES', payload: balances });
  };

  const updatePositions = (positions: StakingPositionDisplay[]) => {
    dispatch({ type: 'SET_POSITIONS', payload: positions });
  };

  useEffect(() => {
    if (connected) {
      refreshData();
    }
  }, [connected, publicKey]);

  return (
    <GMCContext.Provider value={{
      ...state,
      refreshData,
      updateBalance,
      updatePositions,
    }}>
      {children}
    </GMCContext.Provider>
  );
}

export function useGMC() {
  const context = useContext(GMCContext);
  if (!context) {
    throw new Error('useGMC must be used within a GMCProvider');
  }
  return context;
}

// Helper functions (implement based on your backend/indexer)
async function fetchUserBalances(publicKey: any): Promise<UserBalances> {
  // Implementation depends on your data source
  // Could be direct RPC calls, indexer API, or your backend
  return {
    gmc_balance: 0,
    usdt_balance: 0,
    staked_gmc: 0,
    available_rewards_gmc: 0,
    available_rewards_usdt: 0,
    total_burned_gmc: 0,
  };
}

async function fetchUserPositions(publicKey: any): Promise<StakingPositionDisplay[]> {
  // Implementation depends on your data source
  return [];
}
```

## 📱 App Principal

```typescript
// app/page.tsx
'use client';

import React from 'react';
import Dashboard from '@/components/Dashboard';
import StakingInterface from '@/components/StakingInterface';
import BurnForBoost from '@/components/BurnForBoost';
import RankingDisplay from '@/components/RankingDisplay';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { useGMC } from '@/contexts/GMCContext';

export default function HomePage() {
  const { balances, positions, loading } = useGMC();

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="container mx-auto py-8">
        <Dashboard balances={balances || {
          gmc_balance: 0,
          usdt_balance: 0,
          staked_gmc: 0,
          available_rewards_gmc: 0,
          available_rewards_usdt: 0,
          total_burned_gmc: 0,
        }} isLoading={loading} />

        <Tabs defaultValue="staking" className="mt-8">
          <TabsList className="grid w-full grid-cols-4">
            <TabsTrigger value="staking">Staking</TabsTrigger>
            <TabsTrigger value="boost">Burn for Boost</TabsTrigger>
            <TabsTrigger value="ranking">Ranking</TabsTrigger>
            <TabsTrigger value="positions">My Positions</TabsTrigger>
          </TabsList>

          <TabsContent value="staking" className="mt-6">
            <StakingInterface />
          </TabsContent>

          <TabsContent value="boost" className="mt-6">
            {positions.length > 0 ? (
              <div className="grid gap-4">
                {positions
                  .filter(p => p.type === 'LongTerm' && p.is_active)
                  .map(position => (
                    <BurnForBoost 
                      key={position.position_id}
                      position={position}
                      onSuccess={() => {
                        // Refresh data
                      }}
                    />
                  ))}
              </div>
            ) : (
              <div className="text-center py-12">
                <p className="text-gray-500">
                  You need an active long-term staking position to use burn-for-boost.
                </p>
              </div>
            )}
          </TabsContent>

          <TabsContent value="ranking" className="mt-6">
            <RankingDisplay />
          </TabsContent>

          <TabsContent value="positions" className="mt-6">
            {/* Implement positions display */}
            <div>User positions will be displayed here</div>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
}
```

## 📦 Layout Root

```typescript
// app/layout.tsx
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';
import AppWalletProvider from '@/providers/WalletProvider';
import { GMCProvider } from '@/contexts/GMCContext';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'GMC Ecosystem',
  description: 'Advanced DeFi staking platform on Solana',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <AppWalletProvider>
          <GMCProvider>
            {children}
          </GMCProvider>
        </AppWalletProvider>
      </body>
    </html>
  );
}
```

## 🔧 Package.json

```json
{
  "name": "gmc-frontend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "@coral-xyz/anchor": "^0.28.0",
    "@radix-ui/react-dialog": "^1.0.5",
    "@radix-ui/react-select": "^2.0.0",
    "@radix-ui/react-tabs": "^1.0.4",
    "@radix-ui/react-toast": "^1.1.5",
    "@solana/wallet-adapter-base": "^0.9.23",
    "@solana/wallet-adapter-react": "^0.15.35",
    "@solana/wallet-adapter-react-ui": "^0.9.34",
    "@solana/wallet-adapter-wallets": "^0.19.23",
    "@solana/web3.js": "^1.78.8",
    "clsx": "^2.0.0",
    "lucide-react": "^0.292.0",
    "next": "14.0.3",
    "react": "^18",
    "react-dom": "^18",
    "tailwind-merge": "^2.0.0"
  },
  "devDependencies": {
    "@types/bn.js": "^5.1.5",
    "@types/node": "^20",
    "@types/react": "^18",
    "@types/react-dom": "^18",
    "autoprefixer": "^10.0.1",
    "eslint": "^8",
    "eslint-config-next": "14.0.3",
    "postcss": "^8",
    "tailwindcss": "^3.3.0",
    "typescript": "^5"
  }
}
```

## 🚀 Scripts de Deploy

```bash
#!/bin/bash
# scripts/deploy-frontend.sh

echo "🚀 Deploying GMC Frontend..."

# Build the application
echo "📦 Building application..."
npm run build

# Type check
echo "🔍 Running type check..."
npm run type-check

# Run linting
echo "🧹 Running linter..."
npm run lint

# Deploy to Vercel (example)
echo "🌐 Deploying to Vercel..."
vercel --prod

echo "✅ Frontend deployed successfully!"
```

## 📝 Próximos Passos

1. **Configurar IDLs**: Adicionar os arquivos IDL dos contratos na pasta `/idls/`
2. **Implementar Indexer**: Para dados de ranking e histórico de transações
3. **Adicionar Testes**: Testes unitários e de integração para os hooks e components
4. **Otimizações**: Lazy loading, caching, e otimizações de performance
5. **UI/UX**: Melhorar a interface com animações e feedback visual
6. **PWA**: Transformar em Progressive Web App para mobile
7. **Analytics**: Integrar com Google Analytics ou similar
8. **Monitoramento**: Adicionar Sentry para tracking de erros

Este guia fornece uma base sólida para implementar o frontend React/Next.js do GMC Ecosystem, com exemplos práticos de todos os componentes principais e integração completa com os smart contracts Solana. 