import Web3 from 'web3';

const generateInitCode = function (vars: string[], vals: any[]): string {
  const web3 = new Web3();
  return web3.eth.abi.encodeParameters(vars, vals);
}

const generateDeployCode = function (salt: string, byteCode: string, initCode: string): string {
  const web3 = new Web3();
  return web3.eth.abi.encodeFunctionCall(
    {
      name: 'deploy',
      type: 'function',
      inputs: [
        {
          type: 'bytes12',
          name: 'saltHash'
        },
        {
          type: 'bytes',
          name: 'sourceCode'
        },
        {
          type: 'bytes',
          name: 'initCode'
        },
      ]
    },
    [
      salt, // bytes12 sourceCode
      byteCode, // bytes memory sourceCode
      initCode, // bytes memory initCode
    ]
  );
}

export default { generateInitCode, generateDeployCode };
