import Web3 from 'web3';
const web3 = new Web3();

const reservedNamespaces: string[] = [
  'HolographGeneric',
  'HolographERC20',
  'HolographERC721',
  'HolographDropERC721',
  'HolographDropERC721V2',
  'CustomERC721',
  'CountdownERC721',
  'HolographLegacyERC721',
  'HolographDropERC1155',
  'HolographERC1155',
  'CxipERC721',
  'CxipERC1155',
  'HolographRoyalties',
  'DropsPriceOracleProxy',
  'EditionsMetadataRendererProxy',
  'DropsMetadataRendererProxy',
  'hToken',
];

const reservedNamespaceHashes: string[] = reservedNamespaces.map((nameSpace: string) => {
  return '0x' + web3.utils.asciiToHex(nameSpace).substring(2).padStart(64, '0');
});

console.log(reservedNamespaces[6], reservedNamespaceHashes[6]);

export { reservedNamespaces, reservedNamespaceHashes };
