// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {SygmaTypes} from "../../lib/SygmaTypes.sol";

interface ISygmaValidateReceive {
    function validateReceive(
        bytes32 transactionGuid,
        SygmaTypes.SygmaInsurance memory insurance
    ) external;
}
