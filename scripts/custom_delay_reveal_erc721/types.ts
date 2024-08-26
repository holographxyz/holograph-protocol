export type Hex = `0x${string}`;

export type CustomERC721SalesConfiguration = {
  publicSalePrice: number;
  maxSalePurchasePerAddress: number;
};

export type LazyMintConfiguration = {
  amount: number; // The amount of tokens to lazy mint (basically the batch size)
  baseURIForTokens: string; // The base URI for the tokens in this batch
  data: Hex; // The data to be used to set the encrypted URI. A bytes containing a sub bytes and a bytes32 => abi.encode(bytes(0x00..0), bytes32(0x00..0));
};

export type CustomERC721Initializer = {
  startDate: number;
  initialMaxSupply: number;
  mintInterval: number; // Duration of each interval
  initialOwner: Hex;
  initialMinter: Hex;
  fundsRecipient: Hex;
  contractURI: string;
  salesConfiguration: CustomERC721SalesConfiguration;
  lazyMintsConfigurations: LazyMintConfiguration[];
};

export type HolographERC721InitConfig = {
  contractName: string;
  contractSymbol: string;
  contractBps: number;
  eventConfig: bigint;
  skipInit: boolean;
  encodedInitCode: Hex;
};

export type DeploymentConfig = {
  readonly contractType: Hex;
  readonly chainType: number;
  readonly salt: Hex;
  readonly byteCode: Hex;
  readonly initCode: Hex;
};

export type Signature = {
  readonly r: Hex;
  s: Hex;
  v: Hex | number;
};

export type DeploymentConfigSettings = {
  readonly config: DeploymentConfig;
  readonly signature: Signature;
  readonly signer: Hex;
};
