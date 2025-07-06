# Sygma Multi-Chain Deployment Guide

This guide explains how to deploy the Sygma insurance system across Arbitrum Sepolia and Base Sepolia.

## Architecture Overview

- **Arbitrum Sepolia**: `SygmaValidateReceived` contract (validates if bridging transactions were received)
- **Base Sepolia**: `SygmaState`, `SygmaInsure`, and `SygmaClaim` contracts (core insurance system)

## Prerequisites

1. **Environment Variables**:

   ```bash
   export ENDPOINT_ADDRESS="0x6EDCE65403992e310A62460808c4b910D972f10f"  # LayerZero endpoint (same for both chains)
   export OWNER_ADDRESS="<YOUR_WALLET_ADDRESS>"  # Contract owner address
   export PRIVATE_KEY="<YOUR_PRIVATE_KEY>"       # Or use --wallet-dir for hardware wallets
   ```

2. **RPC URLs**:

   - Arbitrum Sepolia: `https://sepolia-rollup.arbitrum.io/rpc`
   - Base Sepolia: `https://sepolia.base.org`

3. **Testnet ETH**:
   - Get Arbitrum Sepolia ETH from [Arbitrum faucet](https://faucet.triangleplatform.com/arbitrum/sepolia)
   - Get Base Sepolia ETH from [Base faucet](https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet)

## Deployment Steps

### Step 1: Deploy on Arbitrum Sepolia

Deploy the validation contract:

```bash
forge script script/Sygma.s.sol:SygmaScript \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc \
  --broadcast \
  --verify
```

**Expected Output**:

```
Deploying on chain ID: 421614
Deploying SygmaValidateReceived on Arbitrum Sepolia
SygmaValidateReceived deployed at: 0x...
```

**Save the `SygmaValidateReceived` address** - you'll need it for configuration.

### Step 2: Deploy on Base Sepolia

Deploy the core insurance contracts:

```bash
forge script script/Sygma.s.sol:SygmaScript \
  --rpc-url https://sepolia.base.org \
  --broadcast \
  --verify
```

**Expected Output**:

```
Deploying on chain ID: 84532
Deploying core contracts on Base Sepolia
SygmaState deployed at: 0x...
SygmaInsure deployed at: 0x...
SygmaClaim deployed at: 0x...
```

### Step 3: Configure Cross-Chain Communication

1. **Update Configuration Script**:
   Edit `script/SygmaConfig.s.sol` and update these addresses:

   ```solidity
   address constant BASE_SYGMA_STATE = 0x...;         // From Step 2
   address constant BASE_SYGMA_CLAIM = 0x...;         // From Step 2
   address constant ARBITRUM_VALIDATE_RECEIVED = 0x...; // From Step 1
   ```

2. **Run Configuration**:

   ```bash
   forge script script/SygmaConfig.s.sol:SygmaConfigScript \
     --rpc-url https://sepolia.base.org \
     --broadcast
   ```

3. **Verify Configuration**:
   ```bash
   forge script script/SygmaConfig.s.sol:SygmaConfigScript \
     --rpc-url https://sepolia.base.org \
     --sig "verify()"
   ```

## Chain Information

| Network          | Chain ID | LayerZero EID | Endpoint Address                           |
| ---------------- | -------- | ------------- | ------------------------------------------ |
| Arbitrum Sepolia | 421614   | 40231         | 0x6EDCE65403992e310A62460808c4b910D972f10f |
| Base Sepolia     | 84532    | 40245         | 0x6EDCE65403992e310A62460808c4b910D972f10f |

## Testing

After deployment, run the test suite to verify everything works:

```bash
forge test --match-contract SygmaClaimTest -v
```

## Contract Addresses (Update After Deployment)

### Arbitrum Sepolia

- `SygmaValidateReceived`: `0x...`

### Base Sepolia

- `SygmaState`: `0x...`
- `SygmaInsure`: `0x...`
- `SygmaClaim`: `0x...`

## Usage

1. **Create Insurance**: Call `SygmaInsure.insure()` on Base Sepolia
2. **Submit Claim**: Call `SygmaClaim.claim()` on Base Sepolia
3. **Validation**: The claim will automatically query Arbitrum Sepolia to validate the transaction

## Troubleshooting

### Common Issues

1. **"Unsupported chain ID"**: Make sure you're deploying on the correct networks (Arbitrum Sepolia: 421614, Base Sepolia: 84532)

2. **"Update address"**: The configuration script requires you to update contract addresses after deployment

3. **Insufficient gas**: LayerZero operations require higher gas limits. Increase `--gas-limit` if needed

4. **RPC issues**: Try alternative RPC endpoints if you encounter rate limiting

### Verification

If contract verification fails during deployment, you can verify manually:

```bash
# For Arbitrum Sepolia
forge verify-contract <CONTRACT_ADDRESS> SygmaValidateReceived \
  --chain arbitrum-sepolia \
  --constructor-args $(cast abi-encode "constructor()")

# For Base Sepolia
forge verify-contract <CONTRACT_ADDRESS> SygmaClaim \
  --chain base-sepolia \
  --constructor-args $(cast abi-encode "constructor(address,address,address,uint32)" <STATE_ADDR> <ENDPOINT_ADDR> <OWNER_ADDR> <CHANNEL_ID>)
```

## Security Notes

- Use a hardware wallet or secure key management for mainnet deployments
- Test thoroughly on testnets before mainnet deployment
- Consider multisig ownership for production contracts
- Monitor LayerZero gas costs and adjust options accordingly
