// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Insure} from "../src/Insure.sol";

contract InsureTest is Test {
    Insure public insure;

    function setUp() public {
        insure = new Insure();
    }

    function test_Insure() public {
        // insure.insure(1);
        // assertEq(insure.number(), 1);
    }
}
