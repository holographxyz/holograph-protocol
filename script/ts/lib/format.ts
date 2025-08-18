/**
 * Formatting utilities for human-readable display of numbers and values
 * 
 * This module provides consistent formatting across the CLI for:
 * - ETH/HLG amounts (converts from wei to ether)
 * - Large numbers (compacts to K/M/B notation)
 * - Gas values (adds thousands separators)
 * - Hex values (shortens for display)
 */

import { formatEther, formatUnits } from "viem";

/**
 * Format a bigint wei value to human-readable ether with compact notation
 * 
 * @param value - Value in wei (10^18)
 * @param decimals - Number of decimals to show (default: 2)
 * @returns Formatted string like "1.5K", "333.5M", "0.01"
 * 
 * @example
 * formatCompactEther(parseEther("333545.427")) // "333.5K"
 * formatCompactEther(parseEther("0.001"))      // "0.001"
 * formatCompactEther(parseEther("1500000"))    // "1.5M"
 */
export function formatCompactEther(value: bigint, decimals: number = 2): string {
  const eth = Number(formatEther(value));
  
  if (eth >= 1_000_000_000) {
    return `${(eth / 1_000_000_000).toFixed(decimals)}B`;
  }
  if (eth >= 1_000_000) {
    return `${(eth / 1_000_000).toFixed(decimals)}M`;
  }
  if (eth >= 1_000) {
    return `${(eth / 1_000).toFixed(decimals)}K`;
  }
  
  // For very small values, show a human-readable format
  if (eth < 0.000001 && eth > 0) {
    return "< 0.000001"; // Less than 1 millionth
  }
  if (eth < 0.01 && eth > 0) {
    // Show more decimal places for small values
    return eth.toFixed(6).replace(/\.?0+$/, ''); // Remove trailing zeros
  }
  
  return eth.toFixed(decimals);
}

/**
 * Format a bigint value with custom decimals to human-readable format
 * 
 * @param value - Raw bigint value  
 * @param decimals - Token decimals (default: 18)
 * @param displayDecimals - Number of decimals to show (default: 2)
 * @returns Formatted string with compact notation
 */
export function formatCompactUnits(
  value: bigint, 
  decimals: number = 18,
  displayDecimals: number = 2
): string {
  const formatted = Number(formatUnits(value, decimals));
  
  if (formatted >= 1_000_000_000) {
    return `${(formatted / 1_000_000_000).toFixed(displayDecimals)}B`;
  }
  if (formatted >= 1_000_000) {
    return `${(formatted / 1_000_000).toFixed(displayDecimals)}M`;
  }
  if (formatted >= 1_000) {
    return `${(formatted / 1_000).toFixed(displayDecimals)}K`;
  }
  
  // For very small values, show a human-readable format
  if (formatted < 0.000001 && formatted > 0) {
    return "< 0.000001";
  }
  if (formatted < 0.01 && formatted > 0) {
    return formatted.toFixed(6).replace(/\.?0+$/, '');
  }
  
  return formatted.toFixed(displayDecimals);
}

/**
 * Format a number with thousands separators
 * 
 * @param value - Number or bigint to format
 * @returns String with commas as thousands separators
 * 
 * @example
 * formatWithCommas(1234567)   // "1,234,567"
 * formatWithCommas(3000000n)  // "3,000,000"
 */
export function formatWithCommas(value: number | bigint): string {
  return value.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

/**
 * Format gas value for display
 * 
 * @param gas - Gas value as number or bigint
 * @returns Formatted gas string
 * 
 * @example
 * formatGas(3000000)  // "3,000,000"
 * formatGas(150000)   // "150,000"
 */
export function formatGas(gas: number | bigint): string {
  return formatWithCommas(gas);
}

/**
 * Format a hex string for display (shortens long values)
 * 
 * @param hex - Hex string to format
 * @param showBytes - Number of bytes to show at start/end (default: 3)
 * @returns Shortened hex string
 * 
 * @example
 * formatHex("0x0000000000000000000000000000000000000004") // "0x000...004"
 * formatHex("0x1234567890abcdef", 4)                        // "0x1234...cdef"
 */
export function formatHex(hex: string, showBytes: number = 3): string {
  if (hex.length <= 10) return hex;
  
  const start = hex.slice(0, 2 + showBytes * 2);
  const end = hex.slice(-showBytes * 2);
  
  return `${start}...${end}`;
}

/**
 * Format a percentage value
 * 
 * @param value - Value to format (0-100 or 0-10000 basis points)
 * @param isBasisPoints - Whether value is in basis points (default: false)
 * @returns Formatted percentage string
 * 
 * @example
 * formatPercent(50)        // "50%"
 * formatPercent(5000, true) // "50%"
 * formatPercent(0.5)       // "0.5%"
 */
export function formatPercent(value: number, isBasisPoints: boolean = false): string {
  const percent = isBasisPoints ? value / 100 : value;
  return `${percent}%`;
}

/**
 * Format ETH and HLG amounts consistently
 * 
 * @param value - Value in wei
 * @param symbol - Currency symbol (default: "")
 * @param compact - Use compact notation for large numbers (default: true)
 * @returns Formatted amount string
 * 
 * @example
 * formatAmount(parseEther("0.1"), "ETH")        // "0.10 ETH"
 * formatAmount(parseEther("333545"), "HLG")     // "333.5K HLG"
 * formatAmount(parseEther("1.5"), "ETH", false) // "1.50 ETH"
 */
export function formatAmount(
  value: bigint, 
  symbol: string = "",
  compact: boolean = true
): string {
  const formatted = compact ? formatCompactEther(value) : formatEther(value);
  return symbol ? `${formatted} ${symbol}` : formatted;
}