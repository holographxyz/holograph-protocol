const { extendConfig } = require('hardhat/config');

require('./tasks/compile.js');
require('./tasks/inject_holograph_address.js');

extendConfig(function (config, userConfig) {
  config.holographAddressInjector = Object.assign(
    {
      verbose: false,
      runOnCompile: false,
    },
    userConfig.holographAddressInjector
  );
});
