# SignedDepositVault

An ERC4626 vault implementation with EIP-712 signed deposit and mint operations, supporting meta-transactions for gasless deposits.

## Overview

`SignedDepositVault` extends the ERC4626 standard to support meta-transactions via EIP-712 signatures. Users can sign deposit/mint intents off-chain and have them executed by any relayer, enabling gasless transactions.

### Features

- **ERC4626 Compliant**: Full implementation of the ERC4626 tokenized vault standard
- **EIP-712 Signed Operations**: Support for `depositWithSig()` and `mintWithSig()` meta-transactions
- **UUPS Upgradeable**: Uses Universal Upgradeable Proxy Standard for upgradeability
- **Access Control**: Ownable2Step for secure ownership management
- **Reentrancy Protection**: ReentrancyGuard for secure operations
- **Nonce Management**: Per-user nonces prevent replay attacks
- **Deadline Support**: Time-bound signatures for enhanced security

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast, anvil)

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd erc4626

# Install dependencies
forge install
```

## Testing

Run all tests:
```bash
forge test
```

Run tests with verbosity:
```bash
forge test -vvv
```

Run specific test file:
```bash
forge test --match-path test/SignedDepositVaultV1.t.sol
```

Run tests with gas reporting:
```bash
forge test --gas-report
```

## Code Coverage

### Basic Coverage Report

View coverage for key contracts:
```bash
forge coverage --include-libs | grep -E "SignedDepositVaultV1.sol|ERC4626Upgradeable|EIP712Upgradeable|Ownable2StepUpgradeable|UUPSUpgradeable|ReentrancyGuard"
```

### Generate LCOV Report

Generate an LCOV coverage report:
```bash
forge coverage --include-libs --report lcov
```

This generates `lcov.info` which can be viewed with tools like:
- [lcov](https://github.com/linux-test-project/lcov)
- [Coverage Gutters](https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters) (VS Code extension)

### View Coverage in Browser

After generating the LCOV report, you can generate an HTML report:
```bash
# Install lcov (if not already installed)
# On Ubuntu/Debian: sudo apt-get install lcov
# On macOS: brew install lcov

# Generate HTML report
genhtml lcov.info -o coverage-html

## Deployment

For detailed deployment instructions, see:
- [DEPLOY.md](./DEPLOY.md) - Production deployment guide
- [script/README.md](./script/README.md) - Deployment scripts documentation

### Quick Deploy (Local)

Deploy to local Anvil instance:
```bash
# Start Anvil in another terminal
anvil

# Deploy locally
export LOCAL_PRIVATE_KEY=0x...
forge script script/DeploySignedDepositVaultLocal.s.sol:DeploySignedDepositVaultLocal \
    --rpc-url http://localhost:8545 \
    --broadcast
```

### Deploy to Testnet

```bash
export PRIVATE_KEY=0x...
export RPC_URL=your_rpc_url
export ETHERSCAN_API_KEY=your_api_key

forge script script/DeploySignedDepositVault.s.sol:DeploySignedDepositVault \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

## Project Structure

```
erc4626/
├── src/                          # Source contracts
│   └── SignedDepositVaultV1.sol # Main vault implementation
├── test/                         # Test files
│   ├── SignedDepositVaultBase.t.sol
│   └── SignedDepositVaultV1.t.sol
├── script/                       # Deployment scripts
│   ├── DeploySignedDepositVault.s.sol
│   ├── DeploySignedDepositVaultLocal.s.sol
│   └── DeploySignedDepositVaultHelper.sol
└── foundry.toml                  # Foundry configuration
```

## Key Contracts

### SignedDepositVaultV1

The main vault contract that implements:
- `ERC4626Upgradeable`: Tokenized vault standard
- `EIP712Upgradeable`: EIP-712 signature verification
- `Ownable2StepUpgradeable`: Two-step ownership transfer
- `UUPSUpgradeable`: Upgradeable proxy pattern
- `ReentrancyGuard`: Reentrancy protection

## Development

### Format Code

```bash
forge fmt
```

### Lint Code

```bash
forge fmt --check
```

### Build

```bash
forge build
```

### Gas Snapshots

Generate gas snapshots:
```bash
forge snapshot
```

Compare snapshots:
```bash
forge snapshot --diff
```

## License

MIT
