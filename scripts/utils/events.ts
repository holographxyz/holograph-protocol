/*
export enum HolographERC20Event {
  bridgeIn = 0,
  bridgeOut = 1,
  afterApprove = 2,
  beforeApprove = 3,
  afterOnERC20Received = 4,
  beforeOnERC20Received = 5,
  afterBurn = 6,
  beforeBurn = 7,
  afterMint = 8,
  beforeMint = 9,
  afterSafeTransfer = 10,
  beforeSafeTransfer = 11,
  afterTransfer = 12,
  beforeTransfer = 13,
}

export enum HolographERC721Event {
  bridgeIn = 0,
  bridgeOut = 1,
  afterApprove = 2,
  beforeApprove = 3,
  afterApprovalAll = 4,
  beforeApprovalAll = 5,
  afterBurn = 6,
  beforeBurn = 7,
  afterMint = 8,
  beforeMint = 9,
  afterSafeTransfer = 10,
  beforeSafeTransfer = 11,
  afterTransfer = 12,
  beforeTransfer = 13,
  beforeOnERC721Received = 14,
  afterOnERC721Received = 15,
}
*/

export enum HolographERC20Event {
  bridgeIn = 1,
  bridgeOut = 2,
  afterApprove = 3,
  beforeApprove = 4,
  afterOnERC20Received = 5,
  beforeOnERC20Received = 6,
  afterBurn = 7,
  beforeBurn = 8,
  afterMint = 9,
  beforeMint = 10,
  afterSafeTransfer = 11,
  beforeSafeTransfer = 12,
  afterTransfer = 13,
  beforeTransfer = 14,
}

export enum HolographERC721Event {
  bridgeIn = 1,
  bridgeOut = 2,
  afterApprove = 3,
  beforeApprove = 4,
  afterApprovalAll = 5,
  beforeApprovalAll = 6,
  afterBurn = 7,
  beforeBurn = 8,
  afterMint = 9,
  beforeMint = 10,
  afterSafeTransfer = 11,
  beforeSafeTransfer = 12,
  afterTransfer = 13,
  beforeTransfer = 14,
  beforeOnERC721Received = 15,
  afterOnERC721Received = 16,
}

export enum HolographERC1155Event {}

export function ConfigureEvents(
  config: HolographERC20Event[] | HolographERC721Event[] | HolographERC1155Event[]
): string {
  let binary: string = '0'.repeat(256);
  for (let i = 0, l = config.length; i < l; i++) {
    let num: number = config[i];
    binary = binary.replace(new RegExp('(.{' + num + '}).{1}(.*)', 'gi'), '$11$2');
  }
  binary = binary.split('').reverse().join('');
  let byteArray: string[] = binary.match(/.{8}/g) || [];
  let hex: string = '0x';
  for (let i = 0, l = byteArray.length; i < l; i++) {
    hex += parseInt(byteArray[i], 2).toString(16).padStart(2, '0');
  }
  return hex;
}
