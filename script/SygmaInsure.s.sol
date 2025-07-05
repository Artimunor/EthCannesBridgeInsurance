// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {SygmaInsure} from "../src/SygmaInsure.sol";

contract SygmaInsureScript is Script {
    SygmaInsure public insure;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        insure = new SygmaInsure(
            address(0x1234567890123456789012345678901234567890) // Mock state address
        );

        vm.stopBroadcast();
    }
}
