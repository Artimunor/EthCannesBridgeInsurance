// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/*
 * Sygma Claim Transaction Script
 *
 * This script demonstrates the full flow of the Sygma insurance system:
 * 1. Creates an insurance policy using SygmaInsure
 * 2. Executes a claim using SygmaClaim (which triggers cross-chain validation)
 *
 * Prerequisites:
 * - Contracts must be deployed on both Arbitrum Sepolia and Base Sepolia
 * - Cross-chain configuration must be completed (run SygmaConfig.s.sol first)
 * - Ensure you have enough ETH for LayerZero fees
 *
 * Usage:
 * 1. Update the contract addresses below
 * 2. Run on Base Sepolia:
 *    forge script script/SygmaClaimDemo.s.sol:SygmaClaimDemoScript --rpc-url base-sepolia --broadcast -vvv
 */

import {Script, console} from "forge-std/Script.sol";
import {SygmaInsure} from "../src/SygmaInsure.sol";
import {SygmaClaim} from "../src/SygmaClaim.sol";
import {SygmaState} from "../src/SygmaState.sol";
import {SygmaTypes} from "../src/SygmaTypes.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

contract SygmaClaimDemoScript is Script {
    // *** UPDATE THESE ADDRESSES AFTER DEPLOYMENT ***
    address constant BASE_SYGMA_STATE =
        address(0x25a1F84EC10f312E308C7C5B527a5748B4f19D67); // SygmaState on Base Sepolia
    address constant BASE_SYGMA_INSURE =
        address(0x6626395ABDF09c48B16fC85D730f61FB71904AC2); // SygmaInsure on Base Sepolia
    address constant BASE_SYGMA_CLAIM =
        address(0xebE0566d1b002D6a31cBC52294Ca681c0510d5a9); // SygmaClaim on Base Sepolia
    address constant ARBITRUM_VALIDATE_RECEIVED =
        address(0x97BB8A7c8c89D57AfF66c843BB013a11DB449625); // SygmaValidateReceived on Arbitrum Sepolia

    // Chain IDs
    uint32 constant ARBITRUM_SEPOLIA_EID = 40231;
    uint32 constant BASE_SEPOLIA_EID = 40245;

    // Demo transaction data
    bytes32 constant DEMO_TRANSACTION_GUID =
        keccak256("demo_bridge_transaction_2025");

    function run() public {
        // Verify addresses are set
        require(
            BASE_SYGMA_STATE != address(0),
            "Update BASE_SYGMA_STATE address"
        );
        require(
            BASE_SYGMA_INSURE != address(0),
            "Update BASE_SYGMA_INSURE address"
        );
        require(
            BASE_SYGMA_CLAIM != address(0),
            "Update BASE_SYGMA_CLAIM address"
        );
        require(
            ARBITRUM_VALIDATE_RECEIVED != address(0),
            "Update ARBITRUM_VALIDATE_RECEIVED address"
        );

        console.log("=== Sygma Claim Demo ===");
        console.log("Transaction GUID:", vm.toString(DEMO_TRANSACTION_GUID));

        // Get contract instances
        SygmaInsure sygmaInsure = SygmaInsure(BASE_SYGMA_INSURE);
        SygmaClaim sygmaClaim = SygmaClaim(BASE_SYGMA_CLAIM);
        SygmaState sygmaState = SygmaState(BASE_SYGMA_STATE);

        vm.startBroadcast();

        // Step 1: Create a demo insurance policy
        console.log("\n--- Step 1: Creating Insurance Policy ---");
        createDemoInsurance(sygmaInsure);

        // Step 2: Verify the insurance was created
        console.log("\n--- Step 2: Verifying Insurance Creation ---");
        verifyInsurance(sygmaState);

        // Step 3: Estimate and execute the claim
        console.log("\n--- Step 3: Executing Claim ---");
        executeClaim(sygmaClaim);

        vm.stopBroadcast();

        console.log("\n=== Demo Complete ===");
        console.log(
            "The claim has been submitted and will trigger cross-chain validation."
        );
        console.log(
            "Check the transaction logs for LayerZero message details."
        );
    }

    function createDemoInsurance(SygmaInsure sygmaInsure) internal {
        console.log("Creating insurance for transaction...");
        console.log("- Amount: 1000 USDC");
        console.log("- Premium: 10 USD");
        console.log("- From:", vm.toString(msg.sender));
        console.log(
            "- To:",
            vm.toString(0x742D35cC6634c0532925a3B8d76A3BA7D62B3b1C)
        );

        // Create the insurance policy using the correct function signature
        sygmaInsure.insure(
            DEMO_TRANSACTION_GUID, // transactionGuid
            1000 * 1e18, // usdAmount
            10 * 1e18, // premium
            "LayerZero", // bridge
            msg.sender, // insuree (fromAddress)
            8453, // sourceChain
            0x742D35cC6634c0532925a3B8d76A3BA7D62B3b1C, // toAddress
            uint16(ARBITRUM_SEPOLIA_EID), // toChain (destinationChain)
            0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // fromToken
            0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d // toToken
        );

        console.log("[OK] Insurance policy created successfully");
    }

    function verifyInsurance(SygmaState sygmaState) internal view {
        SygmaTypes.SygmaInsurance memory storedInsurance = sygmaState
            .getInsurance(DEMO_TRANSACTION_GUID);

        require(storedInsurance.usdAmount > 0, "Insurance not found");

        console.log("Insurance verification:");
        console.log("- USD Amount:", storedInsurance.usdAmount / 1e18, "USD");
        console.log("- Premium:", storedInsurance.premium / 1e18, "USD");
        console.log("- Bridge:", storedInsurance.transaction.bridge);
        console.log(
            "- Destination Chain:",
            storedInsurance.transaction.destinationChain
        );

        // Verify chain receiver checker is configured
        address checker = sygmaState.getChainReceiverChecker(
            ARBITRUM_SEPOLIA_EID
        );
        require(
            checker == ARBITRUM_VALIDATE_RECEIVED,
            "Chain receiver checker not configured"
        );
        console.log("[OK] Chain receiver checker configured correctly");
    }

    function executeClaim(SygmaClaim sygmaClaim) internal {
        // Estimate the LayerZero fee for the claim
        console.log("Estimating LayerZero fees...");
        MessagingFee memory fee = sygmaClaim.quoteReadFee(
            DEMO_TRANSACTION_GUID
        );

        console.log("LayerZero Fee Estimate:");
        console.log("- Native Fee:", fee.nativeFee / 1e18, "ETH");
        console.log("- LZ Token Fee:", fee.lzTokenFee);

        // Ensure we have enough ETH
        require(
            address(this).balance >= fee.nativeFee,
            "Insufficient ETH for LayerZero fees"
        );
        require(
            msg.sender.balance >= fee.nativeFee,
            "Sender has insufficient ETH for LayerZero fees"
        );

        console.log("Executing claim transaction...");
        console.log("- Transaction GUID:", vm.toString(DEMO_TRANSACTION_GUID));
        console.log("- Paying LayerZero fee:", fee.nativeFee / 1e18, "ETH");

        // Execute the claim - this will trigger cross-chain validation
        sygmaClaim.claim{value: fee.nativeFee}(DEMO_TRANSACTION_GUID);

        console.log("[OK] Claim executed successfully!");
        console.log(
            "The claim will now be validated on Arbitrum Sepolia via LayerZero."
        );
    }

    // Helper function to check if contracts are properly configured
    function checkConfiguration() public view {
        console.log("\n=== Configuration Check ===");

        if (BASE_SYGMA_STATE != address(0)) {
            SygmaState sygmaState = SygmaState(BASE_SYGMA_STATE);
            address checker = sygmaState.getChainReceiverChecker(
                ARBITRUM_SEPOLIA_EID
            );

            if (checker == ARBITRUM_VALIDATE_RECEIVED) {
                console.log("[OK] Cross-chain configuration is correct");
            } else {
                console.log("[ERROR] Cross-chain configuration missing");
                console.log(
                    "Expected:",
                    vm.toString(ARBITRUM_VALIDATE_RECEIVED)
                );
                console.log("Actual:", vm.toString(checker));
            }
        } else {
            console.log("[ERROR] Contract addresses not configured");
        }
    }

    // Function to simulate a received transaction on Arbitrum (for testing)
    function simulateReceivedTransaction() public pure {
        console.log("\n=== Simulating Received Transaction ===");
        console.log(
            "This would register the transaction as received on Arbitrum Sepolia"
        );
        console.log(
            "In production, this would happen automatically when the bridge completes"
        );

        /*
        // This would be called on Arbitrum Sepolia to register the transaction
        SygmaValidateReceived validator = SygmaValidateReceived(ARBITRUM_VALIDATE_RECEIVED);
        
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: DEMO_TRANSACTION_GUID,
            fromAddress: msg.sender,
            toAddress: 0x742d35Cc6634C0532925a3b8D76A3ba7d62b3b1c,
            amount: 1000 * 1e18,
            sourceChain: 8453,
            destinationChain: ARBITRUM_SEPOLIA_EID,
            fromToken: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            toToken: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
        });
        
        validator.registerReceivedTransaction(transaction);
        */
    }

    receive() external payable {}
}
