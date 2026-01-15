# Deployment Scripts

This directory contains scripts for deploying the SignedDepositVault contracts.

## Scripts

### Deployment Scripts

1. **DeploySignedDepositVault.s.sol** - Deploy to production/testnet
   - Requires: `PRIVATE_KEY` environment variable
   - Deploys: ERC20Mock asset, implementation, and ERC1967Proxy
   - Asset token: "ezUSD Token" (ezUSD)
   - Vault name: "ezUSD Vault" (ezUSDV)

2. **DeploySignedDepositVaultLocal.s.sol** - Deploy to localhost/anvil
   - Requires: `LOCAL_PRIVATE_KEY` environment variable
   - Deploys: ERC20Mock asset, implementation, and ERC1967Proxy
   - Asset token: "ezUSD Token" (ezUSD)
   - Vault name: "ezUSD Vault" (ezUSDV)

### Helper Library

3. **DeploySignedDepositVaultHelper.sol** - Reusable deployment library
   - Library for deploying SignedDepositVault with a mock ERC20 asset
   - Can be used in both deployment scripts and tests
   - Provides `deploy()` function that returns `DeploymentResult` struct

## Usage Examples

### Deploy (Production/Testnet)
```bash
export PRIVATE_KEY=0x... # Your private key
forge script script/DeploySignedDepositVault.s.sol:DeploySignedDepositVault \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify
```

### Deploy (Localhost/Anvil)
```bash
export LOCAL_PRIVATE_KEY=0x... # Your local private key (e.g., anvil account)
forge script script/DeploySignedDepositVaultLocal.s.sol:DeploySignedDepositVaultLocal \
    --rpc-url http://localhost:8545 \
    --broadcast
```

## Important Notes

1. **Deployment Structure:**
   - Each deployment creates three contracts:
     - ERC20Mock asset token (used as the underlying asset)
     - SignedDepositVault implementation contract
     - ERC1967Proxy pointing to the implementation
   - The proxy address is the actual vault address users interact with

2. **Initialization:**
   - The vault is initialized via the proxy constructor with:
     - Name: "ezUSD Vault"
     - Symbol: "ezUSDV"
     - Asset: The deployed ERC20Mock token
   - The deployer becomes the owner of the vault

3. **EIP712 Configuration:**
   - Uses EIP712 version "1"
   - Domain name: "SignedDepositVault"
   - Supports `depositWithSig()` and `mintWithSig()` for meta-transactions

4. **Proxy Pattern:**
   - Uses UUPS (Universal Upgradeable Proxy Standard) pattern
   - The implementation can be upgraded by the owner
   - Storage is preserved in the proxy, not the implementation

5. **Environment Variables:**
   - `PRIVATE_KEY`: Required for production/testnet deployments
   - `LOCAL_PRIVATE_KEY`: Required for localhost/anvil deployments
   - Both scripts use the same deployment logic, only the key source differs
