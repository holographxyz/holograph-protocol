// Format collection name and symbol as bytes32 left padded zero bytes
// Example: 0x0000000000000000000000000000000000436f6c6c656374696f6e206e616d65
// NOTE: Similar functionality can be accomplised with web3.utils.fromAscii or ethers.utils.toUtf8Bytes + hexlify
// But this handles prepending 0x and correct padding with zeros
// See: https://ethereum.stackexchange.com/questions/96884/string-to-hex-in-ethers-js
export function utf8ToBytes32(str: string) {
  return (
    '0x' +
    Array.from(str)
      .map((c) =>
        c.charCodeAt(0) < 128
          ? c.charCodeAt(0).toString(16)
          : encodeURIComponent(c).replace(/\%/g, '').toLowerCase()
      )
      .join('')
      .padStart(64, '0')
  );
}

export const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

export const remove0x = function (input: string) {
  if (input.startsWith('0x')) {
    return input.substring(2);
  } else {
    return input;
  }
};

import crypto from 'crypto';

export function sha256(x: string) {
  return (
    '0x' +
    crypto
      .createHash('sha256')
      .update(x, 'utf8')
      .digest('hex')
  );
};
