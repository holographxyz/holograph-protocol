export type Hex = `0x${string}`;

export type CustomERC721SalesConfiguration = {
  publicSalePrice: number;
  maxSalePurchasePerAddress: number; // Purchase mint limit per address (if set to 0 === unlimited mints)
};

export type CountdownERC721Initializer = {
  description: string; // The description of the token.
  imageURI: string; // The URI for the image associated with this contract.
  animationURI: string; // The URI for the animation associated with this contract.
  externalLink: string; // The URI for the external metadata associated with this contract.
  encryptedMediaURI: string; // The URI for the encrypted media associated with this contract.
  startDate: number; // The starting date for the countdown
  initialMaxSupply: number; // The theoretical initial maximum supply of tokens at the start of the countdown.
  mintInterval: number; // The interval between possible mints.
  initialOwner: Hex; // Address of the initial owner, who has administrative privileges.
  initialMinter: Hex; // Address of the initial minter, who can mint new tokens for those who purchase off-chain.
  fundsRecipient: Hex; // Address of the recipient for funds gathered from sales.
  contractURI: string; // URI for the metadata associated with this contract.
  salesConfiguration: CustomERC721SalesConfiguration; // Configuration of sales settings for this contract.
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

export type MetadataParams = {
  name: string;
  description: string;
  imageURI: string;
  animationURI: string;
  externalUrl: string;
  encryptedMediaUrl: string;
  decryptionKey: string;
  hash: string;
  decryptedMediaUrl: string;
  tokenOfEdition: number;
  editionSize: number;
};
