// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/*
 * Full Claim Flow Script
 *
 * This script provides a complete flow for the Sygma insurance system:
 * 1. Creates an insurance policy (if it doesn't exist)
 * 2. Executes a claim transaction
 * 3. Monitors the cross-chain validation process
 *
 * Prerequisites:
 * - Contracts must be deployed on both Arbitrum Sepolia and Base Sepolia
 * - Cross-chain configuration must be completed (run SygmaConfig.s.sol first)
 * - Ensure you have enough ETH for LayerZero fees
 *
 * Usage:
 * 1. Update the contract addresses below
 * 2. Customize the transaction details in the script
 * 3. Run on Base Sepolia:
 *    forge script script/FullClaimFlow.s.sol:FullClaimFlowScript --rpc-url base-sepolia --broadcast -vvv
 *
 * Environment Variables:
 * - PRIVATE_KEY: Your wallet private key for signing transactions
 * - BASE_SEPOLIA_RPC_URL: RPC URL for Base Sepolia
 */

import {Script, console} from "forge-std/Script.sol";
import {SygmaInsure} from "../src/SygmaInsure.sol";
import {SygmaClaim} from "../src/SygmaClaim.sol";
import {SygmaState} from "../src/SygmaState.sol";
import {SygmaTypes} from "../src/SygmaTypes.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

contract FullClaimFlowScript is Script {
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

    // *** CUSTOMIZE THESE TRANSACTION DETAILS ***
    struct TransactionDetails {
        bytes32 transactionGuid;
        uint256 usdAmount; // Amount to insure (in USD with 18 decimals)
        uint256 premium; // Premium to pay (in USD with 18 decimals)
        string bridge; // Bridge name
        address fromAddress; // Source address
        uint256 sourceChain; // Source chain ID
        address toAddress; // Destination address
        uint16 destinationChain; // Destination chain ID
        address fromToken; // Source token address
        address toToken; // Destination token address
    }

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

        console.log("=== Full Sygma Claim Flow ===");

        // Define transaction details
        TransactionDetails memory txDetails = getTransactionDetails();

        console.log("Transaction Details:");
        console.log("- GUID:", vm.toString(txDetails.transactionGuid));
        console.log("- Amount:", txDetails.usdAmount / 1e18, "USD");
        console.log("- Premium:", txDetails.premium / 1e18, "USD");
        console.log("- Bridge:", txDetails.bridge);
        console.log("- From:", vm.toString(txDetails.fromAddress));
        console.log("- To:", vm.toString(txDetails.toAddress));
        console.log("- Source Chain:", txDetails.sourceChain);
        console.log("- Destination Chain:", txDetails.destinationChain);

        // Get contract instances
        SygmaInsure sygmaInsure = SygmaInsure(BASE_SYGMA_INSURE);
        SygmaClaim sygmaClaim = SygmaClaim(BASE_SYGMA_CLAIM);
        SygmaState sygmaState = SygmaState(BASE_SYGMA_STATE);

        // Pre-flight checks
        console.log("\n--- Pre-flight Checks ---");
        performPreflightChecks(sygmaState);

        vm.startBroadcast();

        // Step 1: Create insurance policy (if it doesn't exist)
        console.log("\n--- Step 1: Insurance Policy ---");
        ensureInsuranceExists(sygmaInsure, sygmaState, txDetails);

        // Step 2: Execute claim
        console.log("\n--- Step 2: Executing Claim ---");
        executeClaim(sygmaClaim, txDetails.transactionGuid);

        vm.stopBroadcast();

        console.log("\n=== Flow Complete ===");
        console.log(
            "The claim has been submitted and will trigger cross-chain validation."
        );
        console.log(
            "Monitor the transaction logs for LayerZero message details."
        );
    }

    function getTransactionDetails()
        internal
        view
        returns (TransactionDetails memory)
    {
        // Generate a unique transaction GUID based on current timestamp and sender
        bytes32 guid = keccak256(
            abi.encodePacked(block.timestamp, msg.sender, "sygma_claim")
        );

        return
            TransactionDetails({
                transactionGuid: guid,
                usdAmount: 1000 * 1e18, // $1000 USD
                premium: 10 * 1e18, // $10 USD premium
                bridge: "LayerZero",
                fromAddress: msg.sender,
                sourceChain: 8453, // Base Mainnet (for demo)
                toAddress: 0x742D35cC6634c0532925a3B8d76A3BA7D62B3b1C, // Example destination
                destinationChain: uint16(ARBITRUM_SEPOLIA_EID),
                fromToken: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // USDC on Base
                toToken: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d // USDC on Arbitrum
            });
    }

    function performPreflightChecks(SygmaState sygmaState) internal view {
        console.log("Performing pre-flight checks...");

        // Check if cross-chain configuration is correct
        address checker = sygmaState.getChainReceiverChecker(
            ARBITRUM_SEPOLIA_EID
        );
        require(
            checker == ARBITRUM_VALIDATE_RECEIVED,
            "Chain receiver checker not configured correctly"
        );
        console.log("[OK] Cross-chain configuration verified");

        // Check sender balance
        require(
            msg.sender.balance > 0.01 ether,
            "Insufficient ETH balance (need at least 0.01 ETH)"
        );
        console.log("[OK] Sufficient ETH balance");

        console.log("[OK] All pre-flight checks passed");
    }

    function ensureInsuranceExists(
        SygmaInsure sygmaInsure,
        SygmaState sygmaState,
        TransactionDetails memory txDetails
    ) internal {
        // Check if insurance already exists
        SygmaTypes.SygmaInsurance memory existingInsurance = sygmaState
            .getInsurance(txDetails.transactionGuid);

        if (existingInsurance.usdAmount > 0) {
            console.log("Insurance policy already exists:");
            console.log(
                "- USD Amount:",
                existingInsurance.usdAmount / 1e18,
                "USD"
            );
            console.log("- Premium:", existingInsurance.premium / 1e18, "USD");
            console.log("[OK] Using existing insurance policy");
        } else {
            console.log("Creating new insurance policy...");

            // Create the insurance policy
            sygmaInsure.insure(
                txDetails.transactionGuid,
                txDetails.usdAmount,
                txDetails.premium,
                txDetails.bridge,
                txDetails.fromAddress,
                uint16(txDetails.sourceChain),
                txDetails.toAddress,
                txDetails.destinationChain,
                txDetails.fromToken,
                txDetails.toToken
            );

            console.log("[OK] Insurance policy created successfully");

            // Verify the insurance was created
            SygmaTypes.SygmaInsurance memory newInsurance = sygmaState
                .getInsurance(txDetails.transactionGuid);
            require(newInsurance.usdAmount > 0, "Insurance creation failed");
            console.log("[OK] Insurance creation verified");
        }
    }

    function executeClaim(
        SygmaClaim sygmaClaim,
        bytes32 transactionGuid
    ) internal {
        // Estimate LayerZero fees
        MessagingFee memory fee = sygmaClaim.quoteReadFee(transactionGuid);

        console.log("LayerZero Fee Estimate:");
        console.log("- Native Fee:", fee.nativeFee / 1e18, "ETH");
        console.log("- LZ Token Fee:", fee.lzTokenFee);

        // Ensure we have enough ETH
        require(
            address(this).balance >= fee.nativeFee,
            "Insufficient ETH for LayerZero fees"
        );

        console.log("Executing claim transaction...");
        console.log("- Transaction GUID:", vm.toString(transactionGuid));
        console.log("- LayerZero fee:", fee.nativeFee / 1e18, "ETH");

        // Execute the claim - this will trigger cross-chain validation
        sygmaClaim.claim{value: fee.nativeFee}(transactionGuid);

        console.log("[OK] Claim executed successfully!");
        console.log("Cross-chain validation request sent to Arbitrum Sepolia");
    }

    // Utility function to check the status of a specific transaction
    function checkTransactionStatus(bytes32 transactionGuid) public view {
        console.log("\n=== Transaction Status Check ===");
        console.log("Transaction GUID:", vm.toString(transactionGuid));

        if (BASE_SYGMA_STATE != address(0)) {
            SygmaState sygmaState = SygmaState(BASE_SYGMA_STATE);

            SygmaTypes.SygmaInsurance memory insurance = sygmaState
                .getInsurance(transactionGuid);
            if (insurance.usdAmount > 0) {
                console.log("Insurance Policy Found:");
                console.log("- USD Amount:", insurance.usdAmount / 1e18, "USD");
                console.log("- Premium:", insurance.premium / 1e18, "USD");
                console.log("- Bridge:", insurance.transaction.bridge);
                console.log(
                    "- From:",
                    vm.toString(insurance.transaction.fromAddress)
                );
                console.log(
                    "- To:",
                    vm.toString(insurance.transaction.toAddress)
                );
                console.log(
                    "- Source Chain:",
                    insurance.transaction.sourceChain
                );
                console.log(
                    "- Destination Chain:",
                    insurance.transaction.destinationChain
                );
            } else {
                console.log("No insurance found for this transaction GUID");
            }
        } else {
            console.log("Contract addresses not configured");
        }
    }

    // Utility function to estimate fees for a specific transaction
    function estimateClaimFees(bytes32 transactionGuid) public view {
        console.log("\n=== Claim Fee Estimation ===");

        if (BASE_SYGMA_CLAIM != address(0)) {
            SygmaClaim sygmaClaim = SygmaClaim(BASE_SYGMA_CLAIM);

            try sygmaClaim.quoteReadFee(transactionGuid) returns (
                MessagingFee memory fee
            ) {
                console.log("LayerZero Fee Estimate:");
                console.log("- Native Fee:", fee.nativeFee / 1e18, "ETH");
                console.log("- LZ Token Fee:", fee.lzTokenFee);
                console.log(
                    "- Your ETH Balance:",
                    msg.sender.balance / 1e18,
                    "ETH"
                );

                if (msg.sender.balance >= fee.nativeFee) {
                    console.log("[OK] Sufficient funds for claim");
                } else {
                    console.log("[ERROR] Insufficient funds for claim");
                    console.log(
                        "Need additional:",
                        (fee.nativeFee - msg.sender.balance) / 1e18,
                        "ETH"
                    );
                }
            } catch {
                console.log(
                    "[ERROR] Could not estimate fees - check if insurance exists"
                );
            }
        } else {
            console.log("Contract addresses not configured");
        }
    }

    receive() external payable {}
}
