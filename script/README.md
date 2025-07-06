# Sygma Claim Execution Scripts

This directory contains scripts for executing claims on the Sygma insurance system. These scripts demonstrate how to interact with the deployed contracts to create insurance policies and execute claims that trigger cross-chain validation.

## Available Scripts

### 1. ExecuteClaim.s.sol

A focused script for executing a claim transaction on an existing insurance policy.

**Purpose**: Execute a claim on an existing insurance policy
**Prerequisites**: Insurance policy must already exist for the transaction GUID
**Usage**: Best for production scenarios where you have an existing policy

### 2. FullClaimFlow.s.sol

A comprehensive script that handles the complete flow from insurance creation to claim execution.

**Purpose**: Full end-to-end flow including insurance creation and claim execution
**Prerequisites**: Only requires contracts to be deployed and configured
**Usage**: Best for testing and demonstration scenarios

### 3. SygmaClaimDemo.s.sol

A demo script with predefined transaction details for testing purposes.

**Purpose**: Demo with fixed transaction details
**Prerequisites**: Contracts deployed and configured
**Usage**: Best for initial testing and verification

## Quick Start

### Step 1: Update Contract Addresses

Before running any script, update the contract addresses in the script files:

```solidity
// Update these addresses after deployment
address constant BASE_SYGMA_STATE = address(0x...);
address constant BASE_SYGMA_INSURE = address(0x...);
address constant BASE_SYGMA_CLAIM = address(0x...);
address constant ARBITRUM_VALIDATE_RECEIVED = address(0x...);
```

### Step 2: Set Environment Variables

```bash
export PRIVATE_KEY="your_private_key_here"
export BASE_SEPOLIA_RPC_URL="https://sepolia.base.org"
```

### Step 3: Run a Script

```bash
# For existing insurance policy
forge script script/ExecuteClaim.s.sol:ExecuteClaimScript \
  --rpc-url base-sepolia \
  --broadcast -vvv

# For full flow (creates insurance + executes claim)
forge script script/FullClaimFlow.s.sol:FullClaimFlowScript \
  --rpc-url base-sepolia \
  --broadcast -vvv
```

## Script Details

### ExecuteClaim.s.sol

**Key Features**:

- Pre-flight checks to verify insurance exists
- Cross-chain configuration validation
- LayerZero fee estimation
- Focused claim execution

**Configuration Required**:

- Update `BASE_SYGMA_STATE`, `BASE_SYGMA_CLAIM`, `ARBITRUM_VALIDATE_RECEIVED` addresses
- Update `TRANSACTION_GUID` with the GUID of your existing insurance policy

**Example Usage**:

```solidity
// Update the transaction GUID
bytes32 constant TRANSACTION_GUID = keccak256("your_transaction_guid_here");
```

### FullClaimFlow.s.sol

**Key Features**:

- Automatic insurance policy creation (if needed)
- Dynamic transaction GUID generation
- Complete flow from insurance to claim
- Comprehensive status checks

**Configuration Required**:

- Update all contract addresses
- Optionally customize transaction details in `getTransactionDetails()`

**Customization**:
The script generates a unique transaction GUID based on timestamp and sender, but you can customize the transaction details:

```solidity
function getTransactionDetails() internal view returns (TransactionDetails memory) {
    return TransactionDetails({
        transactionGuid: keccak256(abi.encodePacked(block.timestamp, msg.sender, "custom_id")),
        usdAmount: 1000 * 1e18,  // $1000 USD
        premium: 10 * 1e18,      // $10 USD premium
        bridge: "LayerZero",
        fromAddress: msg.sender,
        sourceChain: 8453,       // Base Mainnet
        toAddress: 0x742D35cC6634c0532925a3B8d76A3BA7D62B3b1C,
        destinationChain: uint16(ARBITRUM_SEPOLIA_EID),
        fromToken: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // USDC on Base
        toToken: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d   // USDC on Arbitrum
    });
}
```

## Utility Functions

Both scripts include utility functions you can call separately:

### Fee Estimation

```bash
# Estimate LayerZero fees without executing
forge script script/ExecuteClaim.s.sol:ExecuteClaimScript \
  --rpc-url base-sepolia \
  --sig "estimateFees()" -vvv
```

### Status Checking

```bash
# Check claim status
forge script script/ExecuteClaim.s.sol:ExecuteClaimScript \
  --rpc-url base-sepolia \
  --sig "checkClaimStatus()" -vvv
```

## Prerequisites

### 1. Contracts Deployed

- SygmaState, SygmaInsure, SygmaClaim on Base Sepolia
- SygmaValidateReceived on Arbitrum Sepolia

### 2. Cross-Chain Configuration

Run the configuration script first:

```bash
forge script script/SygmaConfig.s.sol:SygmaConfigScript \
  --rpc-url base-sepolia \
  --broadcast -vvv
```

### 3. Sufficient ETH

You need ETH for:

- Gas fees on Base Sepolia
- LayerZero cross-chain messaging fees (typically 0.001-0.01 ETH)

## Transaction Flow

When you execute a claim, the following happens:

1. **Pre-flight Checks**: Script verifies insurance exists and configuration is correct
2. **Fee Estimation**: LayerZero fees are calculated
3. **Claim Execution**: `SygmaClaim.claim()` is called with the transaction GUID
4. **Cross-Chain Message**: LayerZero sends validation request to Arbitrum Sepolia
5. **Validation**: SygmaValidateReceived on Arbitrum validates the transaction
6. **Response**: Validation result is sent back to Base Sepolia

## Monitoring

After executing a claim:

1. **Check Transaction Logs**: Look for LayerZero message events
2. **Monitor LayerZero**: Use LayerZero's scan tools to track message delivery
3. **Check Arbitrum**: Verify validation was received on Arbitrum Sepolia
4. **Final Status**: Check if validation response was received on Base Sepolia

## Common Issues

### "Insurance not found"

- Verify the transaction GUID is correct
- Make sure insurance was created successfully
- Check if you're using the right contract addresses

### "Insufficient ETH for LayerZero fees"

- Get more ETH for gas and LayerZero fees
- Typical requirement: 0.01-0.05 ETH depending on network conditions

### "Chain receiver checker not configured"

- Run the configuration script first
- Verify cross-chain setup is complete

### "Transaction reverted"

- Check gas limits
- Verify contract addresses are correct
- Ensure LayerZero endpoints are properly configured

## Testing

You can test the scripts on testnets:

```bash
# Test with dry run (no broadcast)
forge script script/FullClaimFlow.s.sol:FullClaimFlowScript \
  --rpc-url base-sepolia -vvv

# Test fee estimation
forge script script/ExecuteClaim.s.sol:ExecuteClaimScript \
  --rpc-url base-sepolia \
  --sig "estimateFees()" -vvv
```

## Security Notes

- Never commit private keys to version control
- Use environment variables for sensitive data
- Test on testnets before mainnet deployment
- Verify all contract addresses before execution
- Start with small amounts for initial testing

## Support

For issues:

1. Check the transaction logs for specific error messages
2. Verify all prerequisites are met
3. Test individual components (insurance creation, fee estimation) separately
4. Use the utility functions for debugging
