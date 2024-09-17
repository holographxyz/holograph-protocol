# ts-utils-cli

## Table of Contents
- [Introduction](#introduction)
- [Usage](#usage)
  - [Basic Commands](#basic-commands)
  - [Options](#options)
  - [Examples](#examples)
  - [Command Arguments](#command-arguments)
- [Contributing](#contributing)
- [License](#license)

## Introduction
`ts-utils-cli` is a TypeScript CLI utility that facilitates the creation of Safe wallet transactions. This CLI tool leverages the Safe Global protocol to enable publishing signed transaction proposal in a Safe wallet.

## Usage
`ts-utils-cli` provides a single of commands to create Safe transactions. Below you will find details on how to use these commands, including available options and examples.

You can use the `--help` option to get more information about the available commands and options.

```sh
npx ts-node cli.ts --help
```

### Basic Commands
- `safeTx`: Create a Safe transaction.

### Options
#### Global Options
- `-h, --help`: Show help information.
- `-v, --version`: Show the version of the CLI tool.

#### `safeTx` Command Options
- `--silent`: Run the command without printing output (default: false).
- `--chain <uint>`: Specify the chain ID.
- `--to <address>`: The target contract address.
- `--value <uint>`: The transaction value (default: "0").
- `--calldata <bytes>`: The transaction calldata.
- `--safe <address>`: The Safe wallet address.

### Examples
Create a Safe transaction on chain ID 1, with specified target address, value, calldata, and Safe address:
```sh
npx ts-node cli.ts safeTx --chain 1 --to 0xTargetAddress --value 1000 --calldata 0xCalldata --safe 0xSafeAddress
```

Run the command silently without printing output:
```sh
npx ts-node cli.ts safeTx --chain 1 --to 0xTargetAddress --value 1000 --calldata 0xCalldata --safe 0xSafeAddress --silent
```

### Command Arguments
#### `safeTx` Command
The `safeTx` command allows you to create a Safe transaction with the following arguments:

- `--silent`: When set, the command runs without printing output. Default is `false`.
- `--chain <uint>`: This argument specifies the chain ID where the transaction will be created. This is a required argument.
- `--to <address>`: The address of the target contract where the transaction will be sent. This is a required argument.
- `--value <uint>`: The value to be transferred in the transaction. Default is `"0"`.
- `--calldata <bytes>`: The calldata for the transaction. This is a required argument.
- `--safe <address>`: The address of the Safe wallet from which the transaction will be sent. This is a required argument.

## Contributing

### Install dependencies
Run the following command to install dependencies.
```bash
npm i
```

### Build the CLI to executables
Run the following command to build the CLI to executables.
```bash
npm run build
```

## License

TODO