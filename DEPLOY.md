# Deployment Instructions for SignedDepositVaultV1

This guide explains how to deploy the `SignedDepositVaultV1` contract to Base Sepolia testnet.

## Prerequisites

1. **Environment Variables**: Create a `.env` file in the project root:
   ```bash
   PRIVATE_KEY=your_private_key_here
   RPC_URL=https://sepolia.base.org
   ETHERSCAN_API_KEY=your_basescan_api_key_here
   ```

2. **Get API Key**: Get your BaseScan API key from https://basescan.org/apis

## Deployment

**Option 1: Deploy and verify in one command (Recommended):**
```bash
forge script script/DeploySignedDepositVault.s.sol:DeploySignedDepositVault \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**Option 2: Deploy only (verify separately later):**
```bash
forge script script/DeploySignedDepositVault.s.sol:DeploySignedDepositVault \
  --rpc-url $RPC_URL \
  --broadcast
```

The script will deploy:
- ERC20Mock (asset token)
- SignedDepositVaultV1 (implementation)
- ERC1967Proxy (proxy vault)

When using `--verify`, all contracts will be automatically verified on BaseScan after deployment.

## Verification (Manual)

**If you deployed without `--verify`, you can verify contracts manually:**
```bash
# Verify ERC20Mock
forge verify-contract <ERC20Mock_ADDRESS> \
  script/DeploySignedDepositVault.s.sol:ERC20Mock \
  --chain-id 84532 \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(string,string)" "ezUSD Token" "ezUSD")

# Verify SignedDepositVaultV1 implementation
forge verify-contract <IMPLEMENTATION_ADDRESS> \
  src/SignedDepositVaultV1.sol:SignedDepositVaultV1 \
  --chain-id 84532 \
  --etherscan-api-key $ETHERSCAN_API_KEY

# Verify ERC1967Proxy
forge verify-contract <PROXY_ADDRESS> \
  @openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  --chain-id 84532 \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,bytes)" <IMPLEMENTATION_ADDRESS> <INIT_DATA>)
```

Replace `<ERC20Mock_ADDRESS>`, `<IMPLEMENTATION_ADDRESS>`, `<PROXY_ADDRESS>`, and `<INIT_DATA>` with the actual addresses and initialization data from your deployment output.

## What Gets Deployed

1. **ERC20Mock** - Mock ERC20 token ("ezUSD Token", "ezUSD")
2. **SignedDepositVaultV1** - Implementation contract
3. **ERC1967Proxy** - UUPS proxy initialized with:
   - Name: "ezUSD Vault"
   - Symbol: "ezUSDV"
   - Asset: The deployed ERC20Mock address
   - Owner: The deployer address

## Viewing Proxy Contract on Basescan

When you view the `ERC1967Proxy` contract on Basescan, you may see "no available Contract ABI methods to read". This is expected because the proxy contract itself doesn't expose the implementation's ABI.

**To view the proxy contract with the correct ABI:**

1. **Get the implementation address:**
   ```bash
   # Option 1: From deployment logs (check the deployment output)
   # The implementation address is logged during deployment
   
   # Option 2: Read from proxy storage using cast
   cast storage <PROXY_ADDRESS> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $RPC_URL
   
   # Option 3: Use the helper script
   PROXY_ADDRESS=<your_proxy_address> forge script script/GetProxyImplementation.s.sol:GetProxyImplementation --rpc-url $RPC_URL
   ```

2. **On Basescan:**
   - Go to your proxy contract page
   - Click on the **"Contract"** tab
   - Click **"More Options"** → **"Is this a proxy?"**
   - Enter the implementation contract address
   - Basescan will now display the proxy using the implementation contract's ABI

3. **Alternative: Read directly from storage slot**
   The implementation address is stored at ERC-1967 storage slot:
   ```
   0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
   ```
   You can read it using:
   ```bash
   cast storage <PROXY_ADDRESS> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $RPC_URL
   ```

**Important:** Make sure the implementation contract is verified on Basescan for the proxy to display correctly.

## Notes

- The vault uses the UUPS (Universal Upgradeable Proxy Standard) pattern
- The deployer becomes the owner and can call `accureYield()` and `slashYield()`
- The vault supports EIP-712 signed deposits and mints
- Each user has a nonce that increments with each signed transaction
- The proxy contract delegates all calls to the implementation contract
