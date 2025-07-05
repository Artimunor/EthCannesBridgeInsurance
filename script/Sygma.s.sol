// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {SygmaInsure} from "../src/SygmaInsure.sol";
import {SygmaTypes} from "../src/SygmaTypes.sol";
import {SygmaClaim} from "../src/SygmaClaim.sol";
import {SygmaValidateReceive} from "../src/SygmaValidateReceive.sol";
import {SygmaValidateSent} from "../src/SygmaValidateSent.sol";
import {SygmaState} from "../src/SygmaState.sol";

contract SygmaScript is Script {
    SygmaInsure public insure;
    SygmaClaim public sygmaClaim;
    SygmaValidateReceive public sygmaValidateReceive;
    SygmaValidateSent public sygmaValidateSent;
    SygmaState public sygmaState;

    function setUp() public {}

    function run() public {
        address endpoint = vm.envAddress("ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");

        vm.startBroadcast();

        sygmaState = new SygmaState();

        insure = new SygmaInsure(address(sygmaState));

        sygmaClaim = new SygmaClaim(address(sygmaState), endpoint, owner, 0);

        sygmaValidateReceive = new SygmaValidateReceive();

        sygmaValidateSent = new SygmaValidateSent();

        vm.stopBroadcast();
    }
}
