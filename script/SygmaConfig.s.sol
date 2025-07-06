// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/*
 * Sygma Post-Deployment Configuration Script
 *
 * This script configures the Sygma contracts after they have been deployed
 * on both Arbitrum Sepolia and Base Sepolia.
 *
 * Usage:
 * 1. Deploy contracts using Sygma.s.sol on both chains
 * 2. Update the addresses below with your deployed contract addresses
 * 3. Run this script on Base Sepolia to configure cross-chain connections
 *
 * forge script script/SygmaConfig.s.sol:SygmaConfigScript --rpc-url <base_sepolia_rpc> --broadcast
 */

import {Script, console} from "forge-std/Script.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";

import {SygmaClaim} from "../src/SygmaClaim.sol";
import {SygmaState} from "../src/SygmaState.sol";

contract SygmaConfigScript is Script {
    using OptionsBuilder for bytes;

    // *** UPDATE THESE ADDRESSES AFTER DEPLOYMENT ***
    address constant BASE_SYGMA_STATE = address(0); // SygmaState on Base Sepolia
    address constant BASE_SYGMA_CLAIM = address(0); // SygmaClaim on Base Sepolia
    address constant ARBITRUM_VALIDATE_RECEIVED = address(0); // SygmaValidateReceived on Arbitrum Sepolia

    // LayerZero endpoint IDs
    uint32 constant ARBITRUM_SEPOLIA_EID = 40231;
    uint32 constant BASE_SEPOLIA_EID = 40245;

    function run() public {
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

        console.log("Configuring Sygma contracts...");
        console.log("Base SygmaState:", BASE_SYGMA_STATE);
        console.log("Base SygmaClaim:", BASE_SYGMA_CLAIM);
        console.log(
            "Arbitrum SygmaValidateReceived:",
            ARBITRUM_VALIDATE_RECEIVED
        );

        vm.startBroadcast();

        // 1. Configure SygmaState to know about the Arbitrum validator
        SygmaState sygmaState = SygmaState(BASE_SYGMA_STATE);
        sygmaState.setChainReceiverChecker(
            ARBITRUM_SEPOLIA_EID,
            ARBITRUM_VALIDATE_RECEIVED
        );
        console.log("[OK] Configured SygmaState chain receiver checker");

        // 2. Configure LayerZero options for SygmaClaim
        SygmaClaim sygmaClaim = SygmaClaim(BASE_SYGMA_CLAIM);

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReadOption(300000, 32, 0);

        EnforcedOptionParam[]
            memory enforcedOptions = new EnforcedOptionParam[](1);
        enforcedOptions[0] = EnforcedOptionParam({
            eid: ARBITRUM_SEPOLIA_EID,
            msgType: 1, // READ_TYPE
            options: options
        });

        sygmaClaim.setEnforcedOptions(enforcedOptions);
        console.log("[OK] Configured SygmaClaim LayerZero options");

        vm.stopBroadcast();

        console.log("\n=== Configuration Complete ===");
        console.log(
            "Your Sygma contracts are now configured for cross-chain operation!"
        );
        console.log(
            "- Base Sepolia contracts can now read validation data from Arbitrum Sepolia"
        );
        console.log("- LayerZero options are set for optimal gas usage");
    }

    function verify() public view {
        console.log("\n=== Verification ===");

        if (BASE_SYGMA_STATE != address(0)) {
            SygmaState sygmaState = SygmaState(BASE_SYGMA_STATE);
            address checker = sygmaState.getChainReceiverChecker(
                ARBITRUM_SEPOLIA_EID
            );
            console.log("Chain receiver checker for Arbitrum:", checker);

            if (checker == ARBITRUM_VALIDATE_RECEIVED) {
                console.log("[OK] Chain receiver checker correctly configured");
            } else {
                console.log("[ERROR] Chain receiver checker NOT configured");
            }
        }
    }
}
