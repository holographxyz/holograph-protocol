# Holograph Bridge
The first draft of the Holograph Bridge smart contracts.
```
  ,,,,,,,,,,,
 [ HOLOGRAPH ]
  '''''''''''
  _____________________________________________________________
 |                                                             |
 |                            / ^ \                            |
 |                            ~~*~~            .               |
 |                         [ '<>:<>' ]         |=>             |
 |               __           _/"\_           _|               |
 |             .:[]:.          """          .:[]:.             |
 |           .'  []  '.        \_/        .'  []  '.           |
 |         .'|   []   |'.               .'|   []   |'.         |
 |       .'  |   []   |  '.           .'  |   []   |  '.       |
 |     .'|   |   []   |   |'.       .'|   |   []   |   |'.     |
 |   .'  |   |   []   |   |  '.   .'  |   |   []   |   |  '.   |
 |.:'|   |   |   []   |   |   |':'|   |   |   []   |   |   |':.|
 |___|___|___|___[]___|___|___|___|___|___|___[]___|___|___|___|
 |XxXxXxXxXxXxXxX[]XxXxXxXxXxXxXxXxXxXxXxXxXxX[]XxXxXxXxXxXxXxX|
 |^^^^^^^^^^^^^^^[]^^^^^^^^^^^^^^^^^^^^^^^^^^^[]^^^^^^^^^^^^^^^|
 |               []                           []               |
 |               []                           []               |
 |    ,          []     ,        ,'      *    []               |
 |~~~~~^~~~~~~~~/##\~~~^~~~~~~~~^^~~~~~~~~^~~/##\~~~~~~~^~~~~~~|
 |_____________________________________________________________|

             - one bridge, infinite possibilities -
```

The project is using [asdf](https://asdf-vm.com/) for tool versions management.

Run `asdf install` to have the correct version running for the project.

Install dependencies with `yarn install`.

Initialize the project with `yarn run init`, which will create the missing data dir and copy sample environment configs and shared mnemonic phrase for you.

In a separate terminal run two instances of ganache with `yarn run ganache-x2`. This will simultaneously run two instances for bridge testing.

Build and compile the latest version of the project with `yarn run build-compile`.

End to end testing can be done with `yarn run test`.

The test scripts will accomplish the following: deploy the entire protocol on both chains, create the same collection on each chain, set `.env $NETWORK` chain as original chain, mint sample NFTs on origin chain, and on foreign chain, test basic info validation, and simple functionality like `transferFrom`.

Once the tests have been done, multi-chain transfers can be tested with `npm run-script test-bridge`. This script tests `bridgeOut` and `bridgeIn` requests between `NETWORK` and `NETWORK2`.
