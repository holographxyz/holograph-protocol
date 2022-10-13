# Setup Overview


## Requirements

1. `node` version 16.14.2 or greater
2. `yarn` version 1.22.18 or greater

Using `npm` will work but we use `yarn`. If you have `asdf` installed, then you can run `asdf install` and you will have the required versions.

## Installing dependencies

1. `yarn install` or `npm install`


### Building types

If you are going to write tests or use modify any scripts locally, then we recommend running `yarn typechain` to generate the `typechains-type` folder.

### Compiling (IMPORTANT)

We compile the code from the `/src` folder into the `/contracts` folder. As a reviewer you only need to worry about the files in the `/contracts` folder. They have already been compiled and working as expected. But if you do modify the contracts in the `/src` folder, you will have to do this step and then call `yarn build` command afterwards.

### Building

To build the project you can run `yarn build`. This will look at the `/contracts` folder and generate all the necessary artifacts. 


## Running tests

To run the tests you have to have 2 terminal windows open. One window will launch 2 instances of ganache. While the other terminal you will run the test.


1. Terminal window 1: `yarn ganache-x2`
2. Terminal window 2: `yarn test`


### Test Specifics

We run two instances of ganache to simulate the two chains. To do the heavy lifting, we run the setup command in the `/tests/utils/index.ts` file by importing it `import setup from './utils';`. From there we can get access to chain 1 and chain 2 viea:

1. Chain 1: `l1 = await setup();`
2. Chain 2: `l2 = await setup(true);`

Within any tests you will have access to the contracts by calling `l1.registry` for example.





