// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {ReadLibConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/readlib/ReadLibBase.sol";

import {SygmaInsure} from "../src/SygmaInsure.sol";
import {SygmaTypes} from "../src/SygmaTypes.sol";
import {SygmaClaim} from "../src/SygmaClaim.sol";
import {SygmaValidateReceived} from "../src/SygmaValidateReceived.sol";
import {SygmaValidateSent} from "../src/SygmaValidateSent.sol";
import {SygmaState} from "../src/SygmaState.sol";

contract SygmaScript is Script {
    using OptionsBuilder for bytes;
    SygmaInsure public insure;
    SygmaClaim public sygmaClaim;
    SygmaValidateReceived public sygmaValidateReceived;
    SygmaValidateSent public sygmaValidateSent;
    SygmaState public sygmaState;

    function setUp() public {}

    function run() public {
        address endpoint = vm.envAddress("ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");

        address oappAddress = vm.envAddress("OAPP_ADDRESS");
        address readLib1002Address = vm.envAddress("READ_LIB_1002_ADDRESS");
        address readCompatibleDVN = vm.envAddress("READ_COMPATIBLE_DVN");

        address[] memory optionalDNVs = new address[](0);

        // LayerZero read channel ID.
        uint32 READ_CHANNEL = 0;

        EnforcedOptionParam[] memory params = new EnforcedOptionParam[](1);
        // params[0] = EnforcedOptionParam({
        //     eid: READ_CHANNEL,
        //     configType: 2, // ULN_CONFIG_TYPE
        //     config: abi.encode(
        //         ReadLibConfig({
        //             requiredDVNCount: 1,
        //             optionalDVNCount: 0,
        //             optionalDVNThreshold: 0,
        //             requiredDVNs: [readCompatibleDVN], // Must support your target chains
        //             optionalDVNs: optionalDNVs
        //         })
        //     )
        // });
        // endpoint.setConfig(oappAddress, readLib1002Address, params);

        // Set the OApp options
        bytes memory options = OptionsBuilder.newOptions();
        options.addExecutorLzReceiveOption(200000, 0);
        //endpoint.setOAppOptions(oappAddress, readLib1002Address, options);

        //endpoint.setSendLibrary(oappAddress, READ_CHANNEL, readLib1002Address);
        // endpoint.setReceiveLibrary(
        //     oappAddress,
        //     READ_CHANNEL,
        //     readLib1002Address,
        //     0
        // );

        vm.startBroadcast();

        sygmaState = new SygmaState();

        insure = new SygmaInsure(address(sygmaState));

        sygmaClaim = new SygmaClaim(
            address(sygmaState),
            endpoint,
            owner,
            READ_CHANNEL
        );

        sygmaValidateReceived = new SygmaValidateReceived();

        sygmaValidateSent = new SygmaValidateSent();

        vm.stopBroadcast();
    }
}
