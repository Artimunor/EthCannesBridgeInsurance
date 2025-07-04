// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Insure} from "../src/Insure.sol";

contract InsureScript is Script {
    Insure public insure;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        insure = new Insure();

        vm.stopBroadcast();
    }
}
