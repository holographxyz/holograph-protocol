/**
 * UniswapService - Handles Uniswap V3 operations and calculations
 * 
 * This service provides a comprehensive interface for Uniswap V3 operations
 * including quotes, fee tier selection, and swap parameter calculations.
 * 
 * Key concepts explained in context of HLG/WETH operations:
 * - Fee tiers: 500 (0.05%), 3000 (0.3%), 10000 (1%) basis points
 * - Tick spacing: Determines precision of liquidity positioning
 * - Price impact: How trade size affects execution price
 */

import { createPublicClient, http, parseAbi } from "viem";
import { sepolia } from "viem/chains";
import { 
  UniswapQuoteResult, 
  UniswapQuoteParams,
  FEE_TIERS,
  UniswapQuoteError,
  EnvironmentConfig 
} from "../types/index.js";
import { getEnvironmentConfig, validateFeeTier } from "../lib/config.js";
import { formatCompactEther } from "../lib/format.js";

export class UniswapService {
  private config: EnvironmentConfig;
  private client = createPublicClient({ chain: sepolia, transport: http() });

  constructor() {
    this.config = getEnvironmentConfig();
  }

  /**
   * Get the best quote for a WETH → HLG swap across available fee tiers
   * 
   * This method checks multiple fee tiers to find the best execution price:
   * - If REQUIRED_FEE_TIER is set, only checks that tier (for specific pool targeting)
   * - If PREFER_FEE_TIER is set, checks that tier first (for preference with fallback)
   * - Otherwise checks all tiers: 500, 3000, 10000 basis points
   * 
   * @param ethAmount - Amount of WETH to swap (in wei)
   * @returns Promise<UniswapQuoteResult> - Best quote with amount out and optimal fee tier
   */
  async getOptimalQuote(ethAmount: bigint): Promise<UniswapQuoteResult> {
    const { requiredFeeTier, preferFeeTier, networkAddresses } = this.config;
    
    // Determine fee tiers to check based on environment configuration
    const baseFees = [500, 3000, 10000];
    let feesToCheck: number[];
    
    if (requiredFeeTier !== undefined) {
      // Force specific fee tier (useful for testing specific pools)
      if (!validateFeeTier(requiredFeeTier)) {
        throw new UniswapQuoteError(`Invalid required fee tier: ${requiredFeeTier}`);
      }
      feesToCheck = [requiredFeeTier];
    } else if (preferFeeTier !== undefined) {
      // Prefer specific fee tier but fallback to others
      if (!validateFeeTier(preferFeeTier)) {
        throw new UniswapQuoteError(`Invalid preferred fee tier: ${preferFeeTier}`);
      }
      feesToCheck = [preferFeeTier, ...baseFees.filter(f => f !== preferFeeTier)];
    } else {
      // Check all fee tiers for best price
      feesToCheck = baseFees;
    }

    let bestQuote: UniswapQuoteResult = { amountOut: 0n, fee: feesToCheck[0] || 3000 };
    const quotes: { fee: number; amountOut: bigint; valid: boolean }[] = [];

    console.log(`🔍 Checking ${feesToCheck.length} fee tier(s) for optimal quote...`);

    for (const fee of feesToCheck) {
      try {
        const quote = await this.getQuoteForFeeTier(ethAmount, fee);
        
        console.log(`   ${FEE_TIERS[fee]?.description || `${fee} bps`}: ${formatCompactEther(quote.amountOut)} HLG`);
        
        quotes.push({ fee, amountOut: quote.amountOut, valid: true });
        
        if (quote.amountOut > bestQuote.amountOut) {
          bestQuote = quote;
        }
      } catch (error) {
        console.log(`   ${FEE_TIERS[fee]?.description || `${fee} bps`}: No liquidity or error`);
        quotes.push({ fee, amountOut: 0n, valid: false });
      }
    }

    if (bestQuote.amountOut === 0n) {
      throw new UniswapQuoteError("No liquidity available in any fee tier");
    }

    const selectedTier = FEE_TIERS[bestQuote.fee];
    console.log(`✅ Best quote: ${selectedTier?.description || `${bestQuote.fee} bps`} (${formatCompactEther(bestQuote.amountOut)} HLG)`);

    return bestQuote;
  }


  /**
   * Get quote for a specific fee tier
   * 
   * @param ethAmount - Amount of WETH to swap
   * @param fee - Fee tier (500, 3000, or 10000)
   * @returns Promise<UniswapQuoteResult> - Quote for this specific fee tier
   */
  async getQuoteForFeeTier(ethAmount: bigint, fee: number): Promise<UniswapQuoteResult> {
    if (!validateFeeTier(fee)) {
      throw new UniswapQuoteError(`Invalid fee tier: ${fee}`);
    }

    const { networkAddresses } = this.config;

    try {
      const result = await this.client.readContract({
        address: networkAddresses.QUOTER_V2 as `0x${string}`,
        abi: parseAbi([
          "function quoteExactInputSingle((address tokenIn, address tokenOut, uint256 amountIn, uint24 fee, uint160 sqrtPriceLimitX96)) returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate)",
        ]),
        functionName: "quoteExactInputSingle",
        args: [
          {
            tokenIn: networkAddresses.WETH as `0x${string}`,
            tokenOut: networkAddresses.HLG as `0x${string}`,
            amountIn: ethAmount,
            fee,
            sqrtPriceLimitX96: 0n,
          },
        ],
      }) as [bigint, bigint, number, bigint];

      const amountOut = result[0];
      return { amountOut, fee };
    } catch (error) {
      throw new UniswapQuoteError(`Failed to get quote for fee tier ${fee}`, error as Error);
    }
  }

  /**
   * Calculate price impact for a given swap
   * 
   * Price impact shows how much the trade will move the pool price.
   * Higher impact means worse execution for large trades.
   * 
   * @param ethAmount - Amount of WETH to swap
   * @param fee - Fee tier to check
   * @returns Promise<number> - Price impact as a percentage (0-100)
   */
  async calculatePriceImpact(ethAmount: bigint, fee: number): Promise<number> {
    try {
      // Get quote for 1 WETH to establish baseline price
      const baselineQuote = await this.getQuoteForFeeTier(1n * 10n ** 18n, fee);
      const baselinePrice = Number(baselineQuote.amountOut) / (1e18); // HLG per WETH

      // Get quote for actual trade amount
      const tradeQuote = await this.getQuoteForFeeTier(ethAmount, fee);
      const tradePrice = Number(tradeQuote.amountOut) / Number(ethAmount); // HLG per wei of WETH

      // Calculate price impact percentage
      const priceImpact = ((baselinePrice - tradePrice) / baselinePrice) * 100;
      return Math.max(0, priceImpact); // Ensure non-negative
    } catch {
      return 0; // Return 0 if calculation fails
    }
  }

  /**
   * Get detailed information about available fee tiers
   * 
   * This method provides educational information about Uniswap V3 fee tiers
   * in the context of our HLG/WETH operations.
   * 
   * @returns Record of fee tier information with trading context
   */
  getFeeTierInfo(): typeof FEE_TIERS {
    return FEE_TIERS;
  }

  /**
   * Explain fee tier selection strategy
   * 
   * Educational method that explains when to use each fee tier
   * based on market conditions and trading patterns.
   */
  explainFeeTierStrategy(): string {
    return `
🎓 Uniswap V3 Fee Tier Strategy for HLG/WETH:

📊 **0.05% (500 basis points)**
   • Tick spacing: 10 (highest precision)
   • Best for: Stable pairs with consistent arbitrage
   • Use when: HLG price is stable relative to ETH
   • Liquidity providers: Earn fees from tight spreads

📈 **0.3% (3000 basis points)** 
   • Tick spacing: 60 (standard precision)
   • Best for: Most token pairs (default choice)
   • Use when: Normal volatility, moderate volume
   • Liquidity providers: Balance between fees and IL protection

🚀 **1% (10000 basis points)**
   • Tick spacing: 200 (lower precision)
   • Best for: Exotic or high-volatility pairs
   • Use when: HLG experiences high volatility vs ETH
   • Liquidity providers: Higher fees compensate for IL risk

💡 **For our batch operations:**
   - Set PREFER_FEE_TIER=3000 for reliable execution
   - Set REQUIRED_FEE_TIER=500 to force specific pool
   - Leave unset to automatically find best price
    `;
  }

  /**
   * Get network addresses for current configuration
   */
  getNetworkAddresses() {
    return this.config.networkAddresses;
  }
}