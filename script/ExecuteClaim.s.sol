// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/*
 * Execute Sygma Claim Script
 *
 * This script executes a SygmaClaim.claim transaction on deployed contracts.
 * The claim transaction triggers cross-chain validation via LayerZero.
 *
 * Prerequisites:
 * - Contracts must be deployed on both Arbitrum Sepolia and Base Sepolia
 * - Cross-chain configuration must be completed (run SygmaConfig.s.sol first)
 * - Insurance policy must exist for the transaction GUID
 * - Ensure you have enough ETH for LayerZero fees
 *
 * Usage:
 * 1. Update the contract addresses and transaction GUID below
 * 2. Run on Base Sepolia:
 *    forge script script/ExecuteClaim.s.sol:ExecuteClaimScript --rpc-url base-sepolia --broadcast -vvv
 *
 * Environment Variables:
 * - PRIVATE_KEY: Your wallet private key for signing transactions
 * - BASE_SEPOLIA_RPC_URL: RPC URL for Base Sepolia
 */

import {Script, console} from "forge-std/Script.sol";
import {SygmaClaim} from "../src/SygmaClaim.sol";
import {SygmaState} from "../src/SygmaState.sol";
import {SygmaTypes} from "../src/SygmaTypes.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

contract ExecuteClaimScript is Script {
    // *** UPDATE THESE ADDRESSES AFTER DEPLOYMENT ***
    address constant BASE_SYGMA_STATE =
        address(0x25a1F84EC10f312E308C7C5B527a5748B4f19D67); // SygmaState on Base Sepolia
    address constant BASE_SYGMA_INSURE =
        address(0x6626395ABDF09c48B16fC85D730f61FB71904AC2); // SygmaInsure on Base Sepolia
    address constant BASE_SYGMA_CLAIM =
        address(0xebE0566d1b002D6a31cBC52294Ca681c0510d5a9); // SygmaClaim on Base Sepolia
    address constant ARBITRUM_VALIDATE_RECEIVED =
        address(0x97BB8A7c8c89D57AfF66c843BB013a11DB449625); // SygmaValidateReceived on Arbitrum Sepolia

    // *** UPDATE THIS TRANSACTION GUID ***
    // Use the GUID of an existing insurance policy you want to claim
    bytes32 constant TRANSACTION_GUID = keccak256("your_transaction_guid_here");

    // Chain IDs
    uint32 constant ARBITRUM_SEPOLIA_EID = 40231;

    function run() public {
        // Verify addresses are set
        require(
            BASE_SYGMA_STATE != address(0),
            "Update BASE_SYGMA_STATE address"
        );
        require(
            BASE_SYGMA_CLAIM != address(0),
            "Update BASE_SYGMA_CLAIM address"
        );
        require(
            ARBITRUM_VALIDATE_RECEIVED != address(0),
            "Update ARBITRUM_VALIDATE_RECEIVED address"
        );

        console.log("=== Executing Sygma Claim ===");
        console.log("Transaction GUID:", vm.toString(TRANSACTION_GUID));
        console.log("Claim Contract:", vm.toString(BASE_SYGMA_CLAIM));

        // Get contract instances
        SygmaClaim sygmaClaim = SygmaClaim(BASE_SYGMA_CLAIM);
        SygmaState sygmaState = SygmaState(BASE_SYGMA_STATE);

        // Pre-flight checks
        console.log("\n--- Pre-flight Checks ---");
        performPreflightChecks(sygmaState, sygmaClaim);

        vm.startBroadcast();

        // Execute the claim
        console.log("\n--- Executing Claim ---");
        executeClaim(sygmaClaim);

        vm.stopBroadcast();

        console.log("\n=== Claim Executed Successfully ===");
        console.log(
            "The claim has been submitted and will trigger cross-chain validation."
        );
        console.log(
            "Monitor the transaction logs for LayerZero message details."
        );
        console.log(
            "The validation result will be sent back from Arbitrum Sepolia."
        );
    }

    function performPreflightChecks(
        SygmaState sygmaState,
        SygmaClaim sygmaClaim
    ) internal view {
        console.log("Performing pre-flight checks...");

        // Check if insurance exists
        SygmaTypes.SygmaInsurance memory insurance = sygmaState.getInsurance(
            TRANSACTION_GUID
        );
        require(
            insurance.usdAmount > 0,
            "Insurance policy not found for this transaction GUID"
        );

        console.log("Insurance found:");
        console.log("- USD Amount:", insurance.usdAmount / 1e18, "USD");
        console.log("- Premium:", insurance.premium / 1e18, "USD");
        console.log("- Bridge:", insurance.transaction.bridge);
        console.log(
            "- Destination Chain:",
            insurance.transaction.destinationChain
        );

        // Check if cross-chain configuration is correct
        address checker = sygmaState.getChainReceiverChecker(
            ARBITRUM_SEPOLIA_EID
        );
        require(
            checker == ARBITRUM_VALIDATE_RECEIVED,
            "Chain receiver checker not configured correctly"
        );
        console.log("[OK] Cross-chain configuration verified");

        // Estimate LayerZero fees
        MessagingFee memory fee = sygmaClaim.quoteReadFee(TRANSACTION_GUID);
        console.log("LayerZero Fee Estimate:");
        console.log("- Native Fee:", fee.nativeFee / 1e18, "ETH");
        console.log("- LZ Token Fee:", fee.lzTokenFee);

        // Check if sender has enough ETH
        require(
            msg.sender.balance >= fee.nativeFee,
            "Insufficient ETH for LayerZero fees"
        );
        console.log("[OK] Sufficient ETH for LayerZero fees");

        console.log("[OK] All pre-flight checks passed");
    }

    function executeClaim(SygmaClaim sygmaClaim) internal {
        // Get the LayerZero fee
        MessagingFee memory fee = sygmaClaim.quoteReadFee(TRANSACTION_GUID);

        console.log("Executing claim transaction...");
        console.log("- Transaction GUID:", vm.toString(TRANSACTION_GUID));
        console.log("- LayerZero fee:", fee.nativeFee / 1e18, "ETH");
        console.log("- Sender:", vm.toString(msg.sender));

        // Execute the claim - this will trigger cross-chain validation
        sygmaClaim.claim{value: fee.nativeFee}(TRANSACTION_GUID);

        console.log("[OK] Claim executed successfully!");
        console.log("Cross-chain validation request sent to Arbitrum Sepolia");
    }

    // Utility function to check claim status (call this separately after claim)
    function checkClaimStatus() public view {
        console.log("\n=== Checking Claim Status ===");

        if (BASE_SYGMA_STATE != address(0)) {
            SygmaState sygmaState = SygmaState(BASE_SYGMA_STATE);

            // Check if insurance exists
            SygmaTypes.SygmaInsurance memory insurance = sygmaState
                .getInsurance(TRANSACTION_GUID);
            if (insurance.usdAmount > 0) {
                console.log("Insurance Policy Status:");
                console.log("- USD Amount:", insurance.usdAmount / 1e18, "USD");
                console.log("- Premium:", insurance.premium / 1e18, "USD");
                console.log("- Bridge:", insurance.transaction.bridge);
                console.log(
                    "- Source Chain:",
                    insurance.transaction.sourceChain
                );
                console.log(
                    "- Destination Chain:",
                    insurance.transaction.destinationChain
                );

                // Note: In a real implementation, you might want to add claim status tracking
                console.log(
                    "- Claim Status: Check transaction logs for LayerZero message status"
                );
            } else {
                console.log(
                    "No insurance found for GUID:",
                    vm.toString(TRANSACTION_GUID)
                );
            }
        } else {
            console.log("Contract addresses not configured");
        }
    }

    // Utility function to estimate fees without executing
    function estimateFees() public view {
        console.log("\n=== Fee Estimation ===");

        if (BASE_SYGMA_CLAIM != address(0)) {
            SygmaClaim sygmaClaim = SygmaClaim(BASE_SYGMA_CLAIM);

            try sygmaClaim.quoteReadFee(TRANSACTION_GUID) returns (
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
