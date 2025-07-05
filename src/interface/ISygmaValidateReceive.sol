// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SygmaTypes} from "../SygmaTypes.sol";

interface ISygmaValidateReceive {
    function validateReceive(
        bytes32 transactionGuid,
        SygmaTypes.SygmaInsurance memory insurance
    ) external;
}
