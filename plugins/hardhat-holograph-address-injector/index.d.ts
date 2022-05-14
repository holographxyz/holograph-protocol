import 'hardhat/types/config';

declare module 'hardhat/types/config' {
  interface HardhatUserConfig {
    holographAddressInjector?: {
      verbose?: boolean,
      runOnCompile?: boolean,
    }
  }

  interface HardhatConfig {
    holographAddressInjector: {
      verbose: boolean,
      runOnCompile: boolean,
    }
  }
}
