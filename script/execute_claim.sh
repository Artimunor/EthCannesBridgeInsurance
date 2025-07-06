#!/bin/bash

# Sygma Claim Execution Example Script
# This script demonstrates how to execute a claim on the Sygma insurance system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Sygma Claim Execution Example ===${NC}"
echo ""

# Check if required environment variables are set
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: PRIVATE_KEY environment variable is not set${NC}"
    echo "Please set your private key: export PRIVATE_KEY=your_private_key_here"
    exit 1
fi

if [ -z "$BASE_SEPOLIA_RPC_URL" ]; then
    echo -e "${YELLOW}Warning: BASE_SEPOLIA_RPC_URL not set, using default${NC}"
    export BASE_SEPOLIA_RPC_URL="https://sepolia.base.org"
fi

echo -e "${GREEN}Environment variables configured:${NC}"
echo "- Private key: ${PRIVATE_KEY:0:10}..."
echo "- Base Sepolia RPC: $BASE_SEPOLIA_RPC_URL"
echo ""

# Check if foundry is installed
if ! command -v forge &> /dev/null; then
    echo -e "${RED}Error: Foundry is not installed${NC}"
    echo "Please install Foundry: https://book.getfoundry.sh/getting-started/installation"
    exit 1
fi

echo -e "${GREEN}Step 1: Compile contracts${NC}"
forge build

echo ""
echo -e "${GREEN}Step 2: Choose execution method${NC}"
echo "1. Execute claim on existing insurance policy (ExecuteClaim.s.sol)"
echo "2. Full flow: Create insurance + Execute claim (FullClaimFlow.s.sol)"
echo "3. Run demo with predefined values (SygmaClaimDemo.s.sol)"
echo ""

read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        echo -e "${YELLOW}Executing claim on existing insurance policy...${NC}"
        echo ""
        echo -e "${YELLOW}Note: Make sure you have updated the contract addresses and transaction GUID in ExecuteClaim.s.sol${NC}"
        echo ""
        read -p "Have you updated the contract addresses and transaction GUID? (y/n): " confirmed
        if [ "$confirmed" != "y" ]; then
            echo "Please update the contract addresses and transaction GUID in script/ExecuteClaim.s.sol"
            exit 1
        fi
        
        # Estimate fees first
        echo -e "${GREEN}Estimating fees...${NC}"
        forge script script/ExecuteClaim.s.sol:ExecuteClaimScript \
          --rpc-url $BASE_SEPOLIA_RPC_URL \
          --sig "estimateFees()" -vvv
        
        echo ""
        read -p "Proceed with claim execution? (y/n): " proceed
        if [ "$proceed" == "y" ]; then
            forge script script/ExecuteClaim.s.sol:ExecuteClaimScript \
              --rpc-url $BASE_SEPOLIA_RPC_URL \
              --broadcast -vvv
        fi
        ;;
    2)
        echo -e "${YELLOW}Running full flow: Create insurance + Execute claim...${NC}"
        echo ""
        echo -e "${YELLOW}Note: Make sure you have updated the contract addresses in FullClaimFlow.s.sol${NC}"
        echo ""
        read -p "Have you updated the contract addresses? (y/n): " confirmed
        if [ "$confirmed" != "y" ]; then
            echo "Please update the contract addresses in script/FullClaimFlow.s.sol"
            exit 1
        fi
        
        # Estimate fees first
        echo -e "${GREEN}Estimating fees...${NC}"
        forge script script/FullClaimFlow.s.sol:FullClaimFlowScript \
          --rpc-url $BASE_SEPOLIA_RPC_URL \
          --sig "estimateClaimFees(bytes32)" \
          --sig-args $(cast keccak "demo_transaction") -vvv
        
        echo ""
        read -p "Proceed with full flow execution? (y/n): " proceed
        if [ "$proceed" == "y" ]; then
            forge script script/FullClaimFlow.s.sol:FullClaimFlowScript \
              --rpc-url $BASE_SEPOLIA_RPC_URL \
              --broadcast -vvv
        fi
        ;;
    3)
        echo -e "${YELLOW}Running demo with predefined values...${NC}"
        echo ""
        echo -e "${YELLOW}Note: Make sure you have updated the contract addresses in SygmaClaimDemo.s.sol${NC}"
        echo ""
        read -p "Have you updated the contract addresses? (y/n): " confirmed
        if [ "$confirmed" != "y" ]; then
            echo "Please update the contract addresses in script/SygmaClaimDemo.s.sol"
            exit 1
        fi
        
        # Run configuration check first
        echo -e "${GREEN}Checking configuration...${NC}"
        forge script script/SygmaClaimDemo.s.sol:SygmaClaimDemoScript \
          --rpc-url $BASE_SEPOLIA_RPC_URL \
          --sig "checkConfiguration()" -vvv
        
        echo ""
        read -p "Proceed with demo execution? (y/n): " proceed
        if [ "$proceed" == "y" ]; then
            forge script script/SygmaClaimDemo.s.sol:SygmaClaimDemoScript \
              --rpc-url $BASE_SEPOLIA_RPC_URL \
              --broadcast -vvv
        fi
        ;;
    *)
        echo -e "${RED}Invalid choice. Please run the script again and choose 1, 2, or 3.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}=== Execution Complete ===${NC}"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Check the transaction logs for LayerZero message details"
echo "2. Monitor LayerZero's cross-chain message delivery"
echo "3. Verify validation was received on Arbitrum Sepolia"
echo "4. Check if validation response was sent back to Base Sepolia"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "- Check claim status: forge script script/ExecuteClaim.s.sol:ExecuteClaimScript --rpc-url $BASE_SEPOLIA_RPC_URL --sig \"checkClaimStatus()\" -vvv"
echo "- Estimate fees: forge script script/ExecuteClaim.s.sol:ExecuteClaimScript --rpc-url $BASE_SEPOLIA_RPC_URL --sig \"estimateFees()\" -vvv"
echo ""
echo -e "${GREEN}Happy claiming! 🎉${NC}"
