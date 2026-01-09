# Deployment Instructions for SignedDepositVaultV1

This guide explains how to deploy the `SignedDepositVaultV1` contract to localhost (Anvil) or other networks.

## Prerequisites

1. **Start Anvil** (for localhost deployment):
   ```bash
   anvil
   ```
   This will start a local blockchain on `http://127.0.0.1:8545` with 10 pre-funded accounts.

## Deployment Scripts

Two deployment scripts are available:

### 1. `DeploySignedDepositVaultLocal.s.sol` (Recommended for Localhost/Anvil)

This script uses the default Anvil account (no environment variables needed).

**Deploy to localhost:**
```bash
forge script script/DeploySignedDepositVaultLocal.s.sol:DeploySignedDepositVaultLocal --rpc-url http://localhost:8545 --broadcast
```

**Simulate deployment (dry-run):**
```bash
forge script script/DeploySignedDepositVaultLocal.s.sol:DeploySignedDepositVaultLocal --rpc-url http://localhost:8545
```

**Note:** The script uses the default Anvil account automatically. If you want to use a different account, you can use the `--sender` flag:
```bash
forge script script/DeploySignedDepositVaultLocal.s.sol:DeploySignedDepositVaultLocal \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

### 2. `DeploySignedDepositVault.s.sol` (For Testnets/Mainnet)

This script requires environment variables for deployment and verification.

#### Setup Environment Variables

1. **Create a `.env` file** in the project root:
   ```bash
   # Create .env file
   touch .env
   ```

2. **Add the following content to `.env`** (replace with your actual values):
   ```bash
   # Private key of the deployer account (without 0x prefix)
   PRIVATE_KEY=your_private_key_here

   # RPC URL for the network you're deploying to
   # Examples:
   #   Ethereum Sepolia: https://sepolia.infura.io/v3/YOUR_INFURA_KEY
   #   Ethereum Mainnet: https://mainnet.infura.io/v3/YOUR_INFURA_KEY
   #   Polygon Mumbai: https://polygon-mumbai.infura.io/v3/YOUR_INFURA_KEY
   #   Arbitrum Sepolia: https://sepolia-rollup.arbitrum.io/rpc
   RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY

   # Etherscan API Key for contract verification
   # Get your API key from: https://etherscan.io/apis
   # For other networks, use the appropriate explorer API key:
   #   - Polygon: POLYGONSCAN_API_KEY
   #   - Arbitrum: ARBISCAN_API_KEY
   #   - Optimism: OPTIMISTIC_ETHERSCAN_API_KEY
   #   - Base: BASESCAN_API_KEY
   ETHERSCAN_API_KEY=your_etherscan_api_key_here

   # Chain ID (optional, Foundry can auto-detect from RPC)
   # Examples:
   #   Ethereum Mainnet: 1
   #   Ethereum Sepolia: 11155111
   #   Polygon Mumbai: 80001
   #   Arbitrum Sepolia: 421614
   CHAIN_ID=11155111
   ```

3. **Foundry automatically loads `.env` files**, so you don't need to manually source them. However, if you prefer to use environment variables directly:
   ```bash
   export PRIVATE_KEY=your_private_key_here
   export RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
   export ETHERSCAN_API_KEY=your_etherscan_api_key_here
   ```

#### Required Environment Variables

- **`PRIVATE_KEY`**: Your deployer account's private key (without `0x` prefix)
- **`ETHERSCAN_API_KEY`**: API key from Etherscan (or chain-specific explorer)
  - Get it from: https://etherscan.io/apis
  - For other chains, use: `POLYGONSCAN_API_KEY`, `ARBISCAN_API_KEY`, `OPTIMISTIC_ETHERSCAN_API_KEY`, `BASESCAN_API_KEY`, etc.

#### Optional Environment Variables

- **`RPC_URL`**: Can be passed via `--rpc-url` flag instead
- **`CHAIN_ID`**: Foundry can auto-detect from RPC, but you can set it explicitly

#### Deployment Commands

**Deploy with verification (Recommended):**
```bash
forge script script/DeploySignedDepositVault.s.sol:DeploySignedDepositVault \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**Or use environment variables directly (Foundry auto-loads .env):**
```bash
forge script script/DeploySignedDepositVault.s.sol:DeploySignedDepositVault \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

**Note:** If you configure verification settings in `foundry.toml`, you can omit the `--etherscan-api-key` flag:
```bash
forge script script/DeploySignedDepositVault.s.sol:DeploySignedDepositVault \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

**Deploy without verification (for testing):**
```bash
forge script script/DeploySignedDepositVault.s.sol:DeploySignedDepositVault \
  --rpc-url $RPC_URL \
  --broadcast
```

**Simulate deployment (dry-run):**
```bash
forge script script/DeploySignedDepositVault.s.sol:DeploySignedDepositVault \
  --rpc-url $RPC_URL
```

#### Additional Options

**For different networks, specify the appropriate explorer API key:**

- **Polygon/Mumbai:**
  ```bash
  forge script script/DeploySignedDepositVault.s.sol:DeploySignedDepositVault \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    --verifier-url https://api.polygonscan.com/api \
    --etherscan-api-key $POLYGONSCAN_API_KEY
  ```

- **Arbitrum:**
  ```bash
  forge script script/DeploySignedDepositVault.s.sol:DeploySignedDepositVault \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    --verifier-url https://api.arbiscan.io/api \
    --etherscan-api-key $ARBISCAN_API_KEY
  ```

**Other useful flags:**
- `--slow`: Use slower, more reliable RPC calls (recommended for mainnet)
- `--gas-estimate-multiplier 200`: Increase gas estimate by 200% (useful for unpredictable gas)
- `--legacy`: Use legacy transaction type (if EIP-1559 not supported)
- `--with-gas-price <PRICE>`: Set a specific gas price
- `--sender <ADDRESS>`: Override the sender address
- `--resume`: Resume a previous deployment that was interrupted

#### Contract Verification

The `--verify` flag enables automatic contract verification on Etherscan (or the appropriate explorer for your network). This will verify:

1. **ERC20Mock** - The mock asset token
2. **SignedDepositVaultV1** - The implementation contract
3. **ERC1967Proxy** - The proxy contract

**Important Notes:**
- Verification happens automatically after deployment when using `--verify`
- Make sure your `ETHERSCAN_API_KEY` (or chain-specific API key) is set correctly
- For proxy contracts, Foundry will verify both the proxy and implementation
- If verification fails, you can manually verify using the contract addresses from the deployment output

#### Example: Complete Testnet Deployment (Ethereum Sepolia)

```bash
# 1. Create and configure .env file (see Setup Environment Variables above)

# 2. Deploy with verification
forge script script/DeploySignedDepositVault.s.sol:DeploySignedDepositVault \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --slow

# The script will:
# - Deploy ERC20Mock
# - Deploy SignedDepositVaultV1 implementation
# - Deploy ERC1967Proxy
# - Initialize the proxy
# - Verify all contracts on Etherscan
# - Output deployment addresses and details
```

## What Gets Deployed

1. **ERC20Mock** - A mock ERC20 token used as the vault's underlying asset
   - Name: "ezUSD Token"
   - Symbol: "ezUSD"

2. **SignedDepositVaultV1** (Implementation) - The implementation contract

3. **ERC1967Proxy** - The UUPS proxy pointing to the implementation
   - Initialized with:
     - Name: "ezUSD Vault"
     - Symbol: "ezUSDV"
     - Asset: The deployed ERC20Mock address
     - Owner: The deployer address

## Example: Full Localhost Deployment

```bash
# Terminal 1: Start Anvil (if not already running)
anvil

# Terminal 2: Deploy the contract
forge script script/DeploySignedDepositVaultLocal.s.sol:DeploySignedDepositVaultLocal \
  --rpc-url http://localhost:8545 \
  --broadcast
```

The script will automatically use the default Anvil account (`0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`) with private key `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`.

The script will output:
- Asset Token address
- Implementation address
- Proxy (Vault) address
- Vault configuration details

## Interacting with the Deployed Vault

After deployment, you can interact with the vault using Foundry's `cast` command or by writing a script.

**Example: Check vault name**
```bash
cast call <VAULT_ADDRESS> "name()(string)" --rpc-url http://localhost:8545
```

**Example: Get domain separator**
```bash
cast call <VAULT_ADDRESS> "DOMAIN_SEPARATOR()(bytes32)" --rpc-url http://localhost:8545
```

## Notes

- The vault uses the UUPS (Universal Upgradeable Proxy Standard) pattern
- The deployer becomes the owner and can call `accureYield()` and `slashYield()`
- The vault supports EIP-712 signed deposits and mints
- Each user has a nonce that increments with each signed transaction

