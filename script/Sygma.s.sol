// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/*
 * Sygma Multi-Chain Deployment Script
 *
 * This script deploys Sygma contracts across multiple chains:
 * - Arbitrum Sepolia (Chain ID: 421614): SygmaValidateReceived contract
 * - Base Sepolia (Chain ID: 84532): SygmaState, SygmaInsure, SygmaClaim contracts
 *
 * Usage:
 *
 * 1. Deploy on Arbitrum Sepolia:
 *    forge script script/Sygma.s.sol:SygmaScript --rpc-url <arbitrum_sepolia_rpc> --broadcast --verify
 *
 * 2. Deploy on Base Sepolia:
 *    forge script script/Sygma.s.sol:SygmaScript --rpc-url <base_sepolia_rpc> --broadcast --verify
 *
 * Environment Variables Required:
 * - ENDPOINT_ADDRESS: LayerZero Endpoint address for the target chain
 * - OWNER_ADDRESS: Address that will own the contracts
 *
 * Chain-specific endpoints:
 * - Arbitrum Sepolia: 0x6EDCE65403992e310A62460808c4b910D972f10f
 * - Base Sepolia: 0x6EDCE65403992e310A62460808c4b910D972f10f
 */

import {Script, console} from "forge-std/Script.sol";

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {ReadLibConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/readlib/ReadLibBase.sol";

import {SygmaInsure} from "../src/SygmaInsure.sol";
import {SygmaTypes} from "../src/SygmaTypes.sol";
import {SygmaClaim} from "../src/SygmaClaim.sol";
import {SygmaValidateReceived} from "../src/SygmaValidateReceived.sol";

import {SygmaState} from "../src/SygmaState.sol";

contract SygmaScript is Script {
    using OptionsBuilder for bytes;

    SygmaInsure public insure;
    SygmaClaim public sygmaClaim;
    SygmaValidateReceived public sygmaValidateReceived;

    SygmaState public sygmaState;

    // Chain IDs for LayerZero
    uint32 constant ARBITRUM_SEPOLIA_EID = 40231;
    uint32 constant BASE_SEPOLIA_EID = 40245;

    function setUp() public {}

    function run() public {
        // Get the current chain ID to determine which deployment to run
        uint256 chainId = block.chainid;

        console.log("Deploying on chain ID:", chainId);

        if (chainId == 421614) {
            // Arbitrum Sepolia
            deployArbitrumSepolia();
        } else if (chainId == 84532) {
            // Base Sepolia
            deployBaseSepolia();
        } else {
            revert("Unsupported chain ID");
        }
    }

    function deployArbitrumSepolia() public {
        console.log("Deploying SygmaValidateReceived on Arbitrum Sepolia");

        vm.startBroadcast();

        // Deploy SygmaValidateReceived on Arbitrum Sepolia
        sygmaValidateReceived = new SygmaValidateReceived();

        console.log(
            "SygmaValidateReceived deployed at:",
            address(sygmaValidateReceived)
        );

        vm.stopBroadcast();
    }

    function deployBaseSepolia() public {
        console.log("Deploying core contracts on Base Sepolia");

        address endpoint = vm.envAddress("ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");

        // LayerZero read channel ID for Base Sepolia
        uint32 READ_CHANNEL = ARBITRUM_SEPOLIA_EID; // Read from Arbitrum Sepolia

        vm.startBroadcast();

        // Deploy core contracts on Base Sepolia
        sygmaState = new SygmaState();
        console.log("SygmaState deployed at:", address(sygmaState));

        insure = new SygmaInsure(address(sygmaState));
        console.log("SygmaInsure deployed at:", address(insure));

        sygmaClaim = new SygmaClaim(
            address(sygmaState),
            endpoint,
            owner,
            READ_CHANNEL
        );
        console.log("SygmaClaim deployed at:", address(sygmaClaim));

        vm.stopBroadcast();
    }

    function configureLayerZero() public {
        // This function contains the old LayerZero configuration logic
        // Currently commented out as it needs proper setup
        /*
        address endpoint = vm.envAddress("ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");

        address oappAddress = vm.envAddress("OAPP_ADDRESS");
        address readLib1002Address = vm.envAddress("READ_LIB_1002_ADDRESS");
        address readCompatibleDVN = vm.envAddress("READ_COMPATIBLE_DVN");

        address[] memory optionalDNVs = new address[](0);

        // LayerZero read channel ID.
        uint32 READ_CHANNEL = 0;

        // Step 1: Create ReadLibConfig
        ReadLibConfig memory readConfig = ReadLibConfig({
            executor: executorAddress, // Required!
            requiredDVNCount: 1,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: [readCompatibleDVN],
            optionalDVNs: new address[](0)
        });

        // Step 2: Wrap in SetConfigParam
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({
            eid: READ_CHANNEL,
            configType: 2, // ULN_CONFIG_TYPE
            config: abi.encode(readConfig)
        });

        // Step 3: Configure via endpoint
        endpoint.setConfig(oappAddress, readLibAddress, params);
        endpoint.setSendLibrary(oappAddress, READ_CHANNEL, readLibAddress);

        // Set the OApp options
        bytes memory options = OptionsBuilder.newOptions();
        options.addExecutorLzReceiveOption(200000, 0);
        */
    }

    // Utility function to help configure the SygmaClaim contract after deployment
    function configurePostDeployment() public pure {
        console.log("\n=== Post-Deployment Configuration ===");
        console.log("After deploying both chains, you need to:");
        console.log(
            "1. Set the Arbitrum Sepolia SygmaValidateReceived address in Base Sepolia SygmaState"
        );
        console.log(
            "2. Configure LayerZero options for cross-chain communication"
        );
        console.log("3. Set up proper access controls");

        // Example configuration (uncomment and modify as needed):
        /*
        address arbitrumValidateReceived = 0x...; // Address from Arbitrum deployment
        
        vm.startBroadcast();
        
        // Set the chain receiver checker to point to Arbitrum Sepolia
        sygmaState.setChainReceiverChecker(
            ARBITRUM_SEPOLIA_EID, 
            arbitrumValidateReceived
        );
        
        // Configure LayerZero options for the SygmaClaim contract
        bytes memory options = OptionsBuilder.newOptions()
            .addExecutorLzReadOption(300000, 32, 0);
        
        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](1);
        enforcedOptions[0] = EnforcedOptionParam({
            eid: ARBITRUM_SEPOLIA_EID,
            msgType: 1, // READ_TYPE
            options: options
        });
        
        sygmaClaim.setEnforcedOptions(enforcedOptions);
        
        vm.stopBroadcast();
        */
    }

    function getDeploymentInfo() public view {
        console.log("\n=== Chain Information ===");
        console.log("Current Chain ID:", block.chainid);
        console.log("Arbitrum Sepolia Chain ID: 421614");
        console.log("Base Sepolia Chain ID: 84532");
        console.log("Arbitrum Sepolia LayerZero EID:", ARBITRUM_SEPOLIA_EID);
        console.log("Base Sepolia LayerZero EID:", BASE_SEPOLIA_EID);
    }
}
