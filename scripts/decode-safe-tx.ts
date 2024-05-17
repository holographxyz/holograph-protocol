import { ethers } from 'ethers';
import * as https from 'https';

// Define types for OpenChain API response
interface OpenChainResponse {
  result: Array<{ text_signature: string }>;
}

// Transaction payload (shortened for brevity)
const txData =
  '0x6a76120200000000000000000000000040a2accbd92bca938b02010e17a5b8929b49130d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000056000000000000000000000000000000000000000000000000000000000000003e48d80ff0a0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000038b00b2ce9fcce6f0d89d286cad4b6f21dd26482f18a400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044a9059cbb0000000000000000000000008406bd8c3fabd48fe833d2e95d011ae0cd1ad61800000000000000000000000000000000000000000000003635c9adc5dea0000000d85b5e176a30edd1915d6728faebd25669b60d8b000000000000000000000000000000000000000000000000016345785d8a00000000000000000000000000000000000000000000000000000000000000000124e55856660000000000000000000000000000000000000000000000000000000000000003000000000000000000000000b2ce9fcce6f0d89d286cad4b6f21dd26482f18a4000000000000000000000000000000000000000000000000000000000003d09000000000000000000000000000000000000000000000000000000004a817c80000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000060000000000000000000000000a3296c84b0b11f184f819adbc3b22f20b5ce96b40000000000000000000000008406bd8c3fabd48fe833d2e95d011ae0cd1ad61800000000000000000000000000000000000000000000003635c9adc5dea0000000d85b5e176a30edd1915d6728faebd25669b60d8b000000000000000000000000000000000000000000000000016345785d8a00000000000000000000000000000000000000000000000000000000000000000124e55856660000000000000000000000000000000000000000000000000000000000000004000000000000000000000000b2ce9fcce6f0d89d286cad4b6f21dd26482f18a4000000000000000000000000000000000000000000000000000000000003d0900000000000000000000000000000000000000000000000000000000ba43b740000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000060000000000000000000000000a3296c84b0b11f184f819adbc3b22f20b5ce96b40000000000000000000000008406bd8c3fabd48fe833d2e95d011ae0cd1ad61800000000000000000000000000000000000000000000003635c9adc5dea00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000145b733afe9928578307b5c6bc1abd8207afac155fe9f4238936f6543f8b3da86ab59d593f6af1922467b9c9e06611b07a3a3a36db2457384c595bdfd7b8355e37a1c0000000000000000000000003a6e8e08f18d48d7057d5930efe569870bd8d6990000000000000000000000000000000000000000000000000000000000000000012833ebf01a731ce8290de26b19132d515eaa8af89404258e08b54d66351e380131de3abd049e443377e198b8740b7b998da81b262a51183c664cd16cf037252620e64a6efe4236035fe2aba1e9fdebf1811e64f0adeeba17c9686b806a5a50bf6333542b80a1f01377e30709cb1e759371665e77e29bb3729fe985e79830ae23421b8bf65c11d628a636dce63307c985db3700d5917278b3de1447937025dd6f470b7d6fbe0874c27d4ded86ac9d3bb4703d46423c82e1a628e421640be80f0fdcfd1f000000000000000000000000000000000000000000000000000000';

// ABI for execTransaction function
const abi = ['function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)'];

// Decode the transaction
const iface = new ethers.utils.Interface(abi);
const decodedTx = iface.decodeFunctionData('execTransaction', txData);

// Extract the arguments
const [to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, signatures] = decodedTx;

// Display the arguments
console.log('To:', to);
console.log('Value:', value.toString());
console.log('Data:', data);
console.log('Operation:', operation);
console.log('SafeTxGas:', safeTxGas.toString());
console.log('BaseGas:', baseGas.toString());
console.log('GasPrice:', gasPrice.toString());
console.log('GasToken:', gasToken);
console.log('RefundReceiver:', refundReceiver);
console.log('Signatures:', signatures);

// Decode the multiSend data
const multiSendAbi = ['function multiSend(bytes)'];
const multiSendIface = new ethers.utils.Interface(multiSendAbi);
const decodedMultiSend = multiSendIface.decodeFunctionData('multiSend', data);
const multiSendData = decodedMultiSend[0];

// Helper function to decode individual transactions
function decodeInnerTx(innerTx: string) {
  const txTo = '0x' + innerTx.slice(0, 40);
  const txValue = ethers.BigNumber.from('0x' + innerTx.slice(40, 104)).toString();
  const txDataLength = parseInt(innerTx.slice(104, 108), 16) * 2;
  const txData = '0x' + innerTx.slice(106, 106 + txDataLength);
  return { txTo, txValue, txData };
}

// Helper function to decode nested multiSend transactions
function decodeMultiSendData(data: string) {
  let offset = 2; // start after "0x"
  const innerTxs = [];
  while (offset < data.length) {
    const innerTxLength = parseInt(data.slice(offset, offset + 64), 16) * 2;
    const innerTx = data.slice(offset + 64, offset + 64 + innerTxLength);
    innerTxs.push(decodeInnerTx(innerTx));
    offset += 64 + innerTxLength;
  }
  return innerTxs;
}

// Helper function to get function signature from OpenChain
async function getFunctionSignature(selector: string): Promise<string> {
  return new Promise((resolve, reject) => {
    console.log(`Fetching function signature for selector: ${selector}`);
    https
      .get(`https://api.openchain.xyz/signature-database/v1/lookup?function=${selector}`, (res) => {
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          try {
            console.log('OpenChain Response:', data);
            const json: OpenChainResponse = JSON.parse(data);

            resolve(json.result[0]?.text_signature || 'Unknown function');
          } catch (error) {
            reject('Error parsing response from OpenChain');
          }
        });
      })
      .on('error', (e) => {
        reject(`Error fetching data from OpenChain: ${e.message}`);
      });
  });
}

// Decode each transaction in the multiSend data
async function decodeTransactions() {
  const innerTxs = decodeMultiSendData(multiSendData);

  for (const [index, tx] of innerTxs.entries()) {
    console.log(`Inner Transaction ${index + 1}:`);
    console.log('  To:', tx.txTo);
    console.log('  Value:', tx.txValue);
    console.log('  Data:', tx.txData);

    // Check if the inner transaction is also a multiSend
    if (tx.txData.startsWith('0x8d80ff0a')) {
      console.log('  Decoding nested multiSend:');
      const nestedDecodedMultiSend = multiSendIface.decodeFunctionData('multiSend', tx.txData);
      const nestedMultiSendData = nestedDecodedMultiSend[0];
      const nestedInnerTxs = decodeMultiSendData(nestedMultiSendData);

      nestedInnerTxs.forEach((nestedTx, nestedIndex) => {
        console.log(`  Nested Inner Transaction ${nestedIndex + 1}:`);
        console.log('    To:', nestedTx.txTo);
        console.log('    Value:', nestedTx.txValue);
        console.log('    Data:', nestedTx.txData);
      });
    } else {
      // Decode other function calls
      const functionSelector = tx.txData.slice(0, 10);
      const functionSignature = await getFunctionSignature(functionSelector);
      console.log('  Function Signature:', functionSignature);

      // Decode the function call if we have the ABI
      try {
        const functionIface = new ethers.utils.Interface([`function ${functionSignature}`]);
        const decodedFunctionCall = functionIface.decodeFunctionData(functionSignature, tx.txData);
        console.log('  Decoded Function Call:', decodedFunctionCall);
      } catch (error) {
        console.log('  Could not decode function call');
      }
    }
  }
}

// Run the decoding
decodeTransactions().catch(console.error);
