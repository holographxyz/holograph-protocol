declare var global: any;
import { formatUnits } from '@ethersproject/units';
import { BigNumber } from '@ethersproject/bignumber';
import { NetworkKeys, networks } from '@holographxyz/networks';
import { Block, BlockWithTransactions, TransactionResponse } from '@ethersproject/abstract-provider';
import { WebSocketProvider, JsonRpcProvider, Web3Provider } from '@ethersproject/providers';
import { GasPricing, initializeGasPricing, updateGasPricing } from './gas';

const ZERO = BigNumber.from('0');
const TWO = BigNumber.from('2');

const LOCALHOST = 'localhost';
const LOCALHOST2 = 'localhost2';

export type BlockParams = {
  network: string;
  blockNumber: number;
  tags?: (string | number)[];
  attempts?: number;
  canFail?: boolean;
  interval?: number;
};

export class GasService {
  network!: string;
  gasPrice!: GasPricing;
  provider!: JsonRpcProvider | WebSocketProvider | Web3Provider;
  ready: boolean = false;
  lastBlockNumber: number = 0;
  verbose: boolean = true;

  constructor(network: string, provider: JsonRpcProvider | WebSocketProvider | Web3Provider, verbose: boolean = false) {
    this.network = network;
    this.provider = provider;
    this.verbose = verbose;
  }

  structuredLog(network: string, msg: string, tags: string | number | (string | number)[] = []): void {
    if (!Array.isArray(tags)) {
      tags = [tags];
    }

    if (this.verbose) {
      process.stdout.write(`${JSON.stringify({ network, msg, tags })}\n`);
    }
  }

  wait = async (seconds: number): Promise<void> => {
    process.stdout.write('.');
    return new Promise<void>(async (resolve, reject) => {
      setTimeout(resolve, seconds * 1000);
    });
  };

  async init(): Promise<void> {
    try {
      this.gasPrice = await initializeGasPricing(this.network, this.provider);
      this.setGlobalGasPrice(this.gasPrice);

      this.provider.on('block', async (blockNumber: string) => {
        try {
          const block = Number.parseInt(blockNumber, 10);
          this.structuredLog(this.network, `New block mined ${block}`, undefined);
          await this.processBlock(this.network, block);
          this.setGlobalGasPrice(this.gasPrice);
          if (this.lastBlockNumber !== 0) {
            this.ready = true;
          }
          this.lastBlockNumber = block;
        } catch (error: any) {
          this.structuredLog(this.network, `Error processing block: ${error.message}`, undefined);
        }
      });

      if ([LOCALHOST, LOCALHOST2].includes(this.network)) {
        this.ready = true;
      }

      while (!this.ready) {
        await this.wait(1);
      }
    } catch (error: any) {
      this.structuredLog(this.network, `Initialization error: ${error.message}`, undefined);
    }
  }

  // Added a separate function to handle the global assignment for clarity and to avoid direct manipulation in the init.
  private setGlobalGasPrice(price: any): void {
    global.__gasPrice = price;
    global.__gasService = this;
  }

  extractGasData(network: string, block: Block | BlockWithTransactions, tx: TransactionResponse): void {
    if (this.gasPrice.isEip1559) {
      this.handleEIP1559Transaction(block, tx);
    } else if (tx.gasPrice && tx.gasPrice.gt(ZERO)) {
      this.handleLegacyTransaction(tx);
    }

    if (this.isLocalNetwork(network)) {
      this.resetGasPriceForLocalNetwork();
    }
  }

  private handleEIP1559Transaction(block: Block | BlockWithTransactions, tx: TransactionResponse): void {
    const priorityFee = this.calculatePriorityFee(block, tx);

    if (this.gasPrice.nextPriorityFee === null) {
      this.gasPrice.nextPriorityFee = priorityFee;
    } else {
      this.gasPrice.nextPriorityFee = this.gasPrice.nextPriorityFee.add(priorityFee).div(TWO);
    }

    // Ensure non-negative by comparing with ZERO
    if (this.gasPrice.nextPriorityFee.lt(ZERO)) {
      this.gasPrice.nextPriorityFee = ZERO;
    }

    this.structuredLog('EIP-1559', `Handled EIP-1559 transaction with priority fee: ${priorityFee.toString()}`);
  }

  private calculatePriorityFee(block: Block | BlockWithTransactions, tx: TransactionResponse): BigNumber {
    let priorityFee: BigNumber = ZERO;

    if (!tx.maxFeePerGas || !tx.maxPriorityFeePerGas) {
      priorityFee = tx.gasPrice!.sub(block.baseFeePerGas!);
    } else {
      const remainder = tx.maxFeePerGas.sub(block.baseFeePerGas!);
      priorityFee = remainder.lt(tx.maxPriorityFeePerGas) ? remainder : tx.maxPriorityFeePerGas;
    }

    return priorityFee;
  }

  private handleLegacyTransaction(tx: TransactionResponse): void {
    if (this.gasPrice.gasPrice === null) {
      this.gasPrice.gasPrice = tx.gasPrice!;
    } else {
      this.gasPrice.gasPrice = this.gasPrice.gasPrice.add(tx.gasPrice!).div(TWO);
    }

    this.structuredLog('Legacy', `Handled legacy transaction with gas price: ${tx.gasPrice!.toString()}`);
  }

  private isLocalNetwork(network: string): boolean {
    return (
      network === networks['localhost' as NetworkKeys].key || network === networks['localhost2' as NetworkKeys].key
    );
  }

  private resetGasPriceForLocalNetwork(): void {
    this.gasPrice.nextBlockFee = ZERO;
    this.gasPrice.maxFeePerGas = ZERO;
    this.gasPrice.nextPriorityFee = ZERO;
    this.gasPrice.gasPrice = ZERO;
  }

  async getBlockWithTransactions({
    blockNumber,
    network,
    tags = [] as (string | number)[],
    attempts = 10,
    canFail = false,
    interval = 5000,
  }: BlockParams): Promise<BlockWithTransactions | null> {
    for (let attempt = 1; attempt <= attempts; attempt++) {
      try {
        const block = await this.provider.getBlockWithTransactions(blockNumber);

        if (block) {
          return block;
        }

        // If canFail is true and we've made all our attempts, return null
        if (canFail && attempt === attempts) {
          return null;
        }
      } catch (error: any) {
        // Only increment the attempt counter if the error isn't 'cannot query unfinalized data'
        if (error.message !== 'cannot query unfinalized data') {
          this.structuredLog(network, `Attempt ${attempt}: Failed retrieving block ${blockNumber}`, tags);

          if (canFail && attempt === attempts) {
            throw error;
          }
        }
      }

      // If we haven't reached our max attempts, wait for the interval duration before trying again
      if (attempt < attempts) {
        await new Promise((resolve) => setTimeout(resolve, interval));
      }
    }

    // If we get through all attempts without returning or throwing, return null
    return null;
  }

  async processBlock(network: string, blockNumber: number): Promise<void> {
    const block = await this.getBlockWithTransactions({
      network,
      blockNumber,
      attempts: 10,
      canFail: false,
    });

    if (!block || !('transactions' in block)) {
      this.structuredLog(network, 'Dropped block', blockNumber);
      return;
    }

    this.structuredLog(network, `Block retrieved`, blockNumber);
    this.structuredLog(network, `Calculating block gas`, blockNumber);

    if (this.gasPrice.isEip1559) {
      this.structuredLog(
        network,
        `Calculated block gas price was ${formatUnits(
          this.gasPrice.nextBlockFee!,
          'gwei'
        )} GWEI, and actual block gas price is ${formatUnits(block.baseFeePerGas!, 'gwei')} GWEI`,
        blockNumber
      );
    }

    this.gasPrice = updateGasPricing(network, block, this.gasPrice);
    const priorityFees = this.gasPrice.nextPriorityFee!;

    if (!block.transactions.length) {
      this.structuredLog(network, `Zero transactions in block`, blockNumber);
    }

    for (const tx of block.transactions) {
      this.extractGasData(network, block, tx);
    }

    this.gasPrice = updateGasPricing(network, block, this.gasPrice);

    if (this.gasPrice.isEip1559 && priorityFees) {
      this.structuredLog(
        network,
        `Calculated block priority fees was ${formatUnits(
          priorityFees,
          'gwei'
        )} GWEI, and actual block priority fees is ${formatUnits(this.gasPrice.nextPriorityFee!, 'gwei')} GWEI`,
        blockNumber
      );
    }
  }
}
