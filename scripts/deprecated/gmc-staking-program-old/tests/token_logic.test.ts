import { assert } from "chai";

// Constants for GMC Token
const GMC_CONSTANTS = {
  TOKEN_NAME: "Gold Mining Token",
  TOKEN_SYMBOL: "GMC",
  DECIMALS: 9,
  TOTAL_SUPPLY_UNITS: 100_000_000, // 100 million tokens
  TRANSFER_FEE_BASIS_POINTS: 50, // 0.5%
  MAX_TRANSFER_FEE_UNITS: 1_000, // 1,000 GMC
  
  // Distribution percentages (in units, not percentages)
  DISTRIBUTION: {
    STAKING_POOL: 70_000_000,      // 70%
    STRATEGIC_RESERVE: 10_000_000, // 10%
    TEAM: 2_000_000,               // 2%
    PRESALE: 8_000_000,            // 8%
    TREASURY: 2_000_000,           // 2%
    MARKETING: 6_000_000,          // 6%
    AIRDROP: 2_000_000             // 2%
  }
} as const;

// Helper function to convert token units to smallest denomination
function toTokenAmount(units: number, decimals: number = GMC_CONSTANTS.DECIMALS): bigint {
  return BigInt(units) * (BigInt(10) ** BigInt(decimals));
}

// Types for our GMC Token logic
interface TokenConfig {
  name: string;
  symbol: string;
  decimals: number;
  totalSupply: bigint;
  transferFeeBasisPoints: number;
  maxTransferFee: bigint;
}

interface TokenDistribution {
  stakingPool: bigint;
  strategicReserve: bigint;
  team: bigint;
  presale: bigint;
  treasury: bigint;
  marketing: bigint;
  airdrop: bigint;
}

// REFACTORED: Clean, well-organized implementation
function createGmcTokenConfig(): TokenConfig {
  return {
    name: GMC_CONSTANTS.TOKEN_NAME,
    symbol: GMC_CONSTANTS.TOKEN_SYMBOL,
    decimals: GMC_CONSTANTS.DECIMALS,
    totalSupply: toTokenAmount(GMC_CONSTANTS.TOTAL_SUPPLY_UNITS),
    transferFeeBasisPoints: GMC_CONSTANTS.TRANSFER_FEE_BASIS_POINTS,
    maxTransferFee: toTokenAmount(GMC_CONSTANTS.MAX_TRANSFER_FEE_UNITS)
  };
}

function calculateTokenDistribution(totalSupply: bigint): TokenDistribution {
  const dist = GMC_CONSTANTS.DISTRIBUTION;
  
  return {
    stakingPool: toTokenAmount(dist.STAKING_POOL),
    strategicReserve: toTokenAmount(dist.STRATEGIC_RESERVE),
    team: toTokenAmount(dist.TEAM),
    presale: toTokenAmount(dist.PRESALE),
    treasury: toTokenAmount(dist.TREASURY),
    marketing: toTokenAmount(dist.MARKETING),
    airdrop: toTokenAmount(dist.AIRDROP)
  };
}

function validateTokenDistribution(distribution: TokenDistribution, totalSupply: bigint): boolean {
  const sum = Object.values(distribution).reduce((acc, value) => acc + value, BigInt(0));
  return sum === totalSupply;
}

function calculateTransferFee(amount: bigint, feeBasisPoints: number, maxFee: bigint): bigint {
  const fee = (amount * BigInt(feeBasisPoints)) / BigInt(10000);
  return fee > maxFee ? maxFee : fee;
}

describe("GMC Token Logic (Unit Tests)", () => {
  const EXPECTED_TOTAL_SUPPLY = toTokenAmount(GMC_CONSTANTS.TOTAL_SUPPLY_UNITS);

  it("Should create GMC token configuration with correct specifications", () => {
    const config = createGmcTokenConfig();
    
    assert.equal(config.name, GMC_CONSTANTS.TOKEN_NAME, "Token name should match specification");
    assert.equal(config.symbol, GMC_CONSTANTS.TOKEN_SYMBOL, "Token symbol should match specification");
    assert.equal(config.decimals, GMC_CONSTANTS.DECIMALS, `Decimals should be ${GMC_CONSTANTS.DECIMALS}`);
    assert.equal(config.totalSupply.toString(), EXPECTED_TOTAL_SUPPLY.toString(), "Total supply should be 100 million tokens");
    assert.equal(config.transferFeeBasisPoints, GMC_CONSTANTS.TRANSFER_FEE_BASIS_POINTS, "Transfer fee should be 0.5% (50 basis points)");
    
    console.log("✅ GMC Token config validated");
  });

  it("Should calculate correct token distribution according to tokenomics", () => {
    const distribution = calculateTokenDistribution(EXPECTED_TOTAL_SUPPLY);
    const dist = GMC_CONSTANTS.DISTRIBUTION;
    
    // Use helper function for cleaner assertions
    const assertions = [
      { actual: distribution.stakingPool, expected: toTokenAmount(dist.STAKING_POOL), name: "Staking pool" },
      { actual: distribution.strategicReserve, expected: toTokenAmount(dist.STRATEGIC_RESERVE), name: "Strategic reserve" },
      { actual: distribution.team, expected: toTokenAmount(dist.TEAM), name: "Team allocation" },
      { actual: distribution.presale, expected: toTokenAmount(dist.PRESALE), name: "Presale" },
      { actual: distribution.treasury, expected: toTokenAmount(dist.TREASURY), name: "Treasury" },
      { actual: distribution.marketing, expected: toTokenAmount(dist.MARKETING), name: "Marketing" },
      { actual: distribution.airdrop, expected: toTokenAmount(dist.AIRDROP), name: "Airdrop" }
    ];
    
    assertions.forEach(({ actual, expected, name }) => {
      assert.equal(actual.toString(), expected.toString(), `${name} should match expected allocation`);
    });
    
    console.log("✅ Token distribution calculated correctly");
  });

  it("Should validate that distribution adds up to total supply", () => {
    const distribution = calculateTokenDistribution(EXPECTED_TOTAL_SUPPLY);
    const isValid = validateTokenDistribution(distribution, EXPECTED_TOTAL_SUPPLY);
    
    assert.isTrue(isValid, "Token distribution should sum to total supply");
    
    // Verify the sum calculation directly
    const actualSum = Object.values(distribution).reduce((acc, value) => acc + value, BigInt(0));
    assert.equal(actualSum.toString(), EXPECTED_TOTAL_SUPPLY.toString(), "Sum of distribution should equal total supply");
    
    console.log("✅ Token distribution validation passed");
  });

  it("Should calculate transfer fees correctly", () => {
    const transferAmount = toTokenAmount(1000); // 1000 GMC
    const expectedFee = toTokenAmount(5); // 0.5% of 1000 GMC = 5 GMC
    
    const actualFee = calculateTransferFee(
      transferAmount, 
      GMC_CONSTANTS.TRANSFER_FEE_BASIS_POINTS, 
      toTokenAmount(GMC_CONSTANTS.MAX_TRANSFER_FEE_UNITS)
    );
    
    assert.equal(actualFee.toString(), expectedFee.toString(), "Transfer fee should be 0.5% of transfer amount");
    
    // Test max fee cap
    const largeTransfer = toTokenAmount(1_000_000); // 1M GMC
    const maxFee = toTokenAmount(GMC_CONSTANTS.MAX_TRANSFER_FEE_UNITS); // 1000 GMC max
    const cappedFee = calculateTransferFee(largeTransfer, GMC_CONSTANTS.TRANSFER_FEE_BASIS_POINTS, maxFee);
    
    assert.equal(cappedFee.toString(), maxFee.toString(), "Large transfer fee should be capped at maximum");
    
    console.log("✅ Transfer fee calculation validated");
  });
}); 