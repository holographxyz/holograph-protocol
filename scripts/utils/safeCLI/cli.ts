import 'dotenv/config';

import { Command } from 'commander';
import { prompts } from 'prompts';
import 'colors';

import SafeApiKit from '@safe-global/api-kit';
import Safe from '@safe-global/protocol-kit';
import { MetaTransactionData, OperationType } from '@safe-global/safe-core-sdk-types';

const program = new Command();

program.name('ts-utils-cli').version('1.0.0').description('A TypeScript CLI utility');

program
  .command('safeTx')
  .description('Create a Safe transaction')
  .option('--silent', 'Run the command without printing output', false)
  .option('--chain <uint>', 'Specify the chain ID', undefined)
  .option('--to <address>', 'The target contract', undefined)
  .option('--value <uint>', 'The transaction value', '0')
  .option('--calldata <bytes>', 'The transaction calldata', undefined)
  .option('--safe <address>', 'The safe wallet address', undefined)
  .action(async (options) => {
    // Command arguments
    const chainId = options.chain;
    const calldata = options.calldata;
    const silent = options.silent;
    const safeAddress = options.safe;
    const to = options.to;
    const value = options.value;

    if (!chainId) throw new Error('Chain ID is not defined');
    if (!calldata) throw new Error('Calldata is not defined');
    if (!safeAddress) throw new Error('SAFE_ADDRESS is not defined');
    if (!to) throw new Error('Target address is not defined');

    // Environment variables
    const RPC_URL = process.env.RPC_URL;
    const OWNER_ADDRESS = process.env.SAFE_OWNER;
    const OWNER_PRIVATE_KEY = process.env.SAFE_OWNER_PRIVATE_KEY;

    if (!RPC_URL) throw new Error('RPC_URL is not defined');
    if (!OWNER_ADDRESS) throw new Error('SAFE_OWNER is not defined');
    if (!OWNER_PRIVATE_KEY) throw new Error('SAFE_OWNER_PRIVATE_KEY is not defined');

    const apiKit = new SafeApiKit({
      chainId: chainId,
    });

    if (!silent) {
      // Log all data and primpt the user if they want to proceed
      console.log('RPC_URL:'.blue, RPC_URL);
      console.log('CHAIN_ID:'.blue, chainId);
      console.log('\n');
      console.log('OWNER_ADDRESS:'.cyan, OWNER_ADDRESS.magenta);
      console.log(
        'OWNER_PRIVATE_KEY:'.cyan,
        (OWNER_PRIVATE_KEY.slice(0, 6) + '...' + OWNER_PRIVATE_KEY.slice(-4)).magenta
      );
      console.log('SAFE_ADDRESS:'.cyan, safeAddress.magenta);
      console.log('\n');
      console.log('CALLDATA:'.green, calldata.yellow);
      console.log('TARGET_ADDRESS:'.green, to.yellow);
      console.log('VALUE:'.green, value.yellow);
      console.log('\n');

      const proceed = Boolean(
        await prompts.confirm({
          message: 'Do you want to proceed?',
          type: 'toggle',
          name: 'proceed',
        })
      );

      if (proceed != true) {
        console.log('Aborted');
        return;
      }
    }

    const protocolKit = await Safe.init({
      provider: RPC_URL,
      signer: OWNER_PRIVATE_KEY,
      safeAddress: safeAddress,
    });
    // Create transaction
    const safeTransactionData: MetaTransactionData = {
      to: to,
      value: value,
      data: calldata,
      operation: OperationType.Call,
    };

    const safeTransaction = await protocolKit.createTransaction({
      transactions: [safeTransactionData],
    });

    const safeTxHash = await protocolKit.getTransactionHash(safeTransaction);
    const signature = await protocolKit.signHash(safeTxHash);

    // Propose transaction to the service
    await apiKit.proposeTransaction({
      safeAddress: safeAddress,
      safeTransactionData: safeTransaction.data,
      safeTxHash,
      senderAddress: OWNER_ADDRESS,
      senderSignature: signature.data,
    });

    console.log('Transaction queued in the Safe wallet'.green);
  });

program.parse(process.argv);
