// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {SygmaInsure} from "../src/SygmaInsure.sol";

contract SygmaInsureTest is Test {
    SygmaInsure public insure;

    function setUp() public {
        insure = new SygmaInsure(
            address(0x1234567890123456789012345678901234567890) // Mock state address
        );
    }

    function test_Insure() public {
        // insure.insure(1);
        // assertEq(insure.number(), 1);
    }
}
