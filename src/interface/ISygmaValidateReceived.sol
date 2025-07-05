// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SygmaTypes} from "../SygmaTypes.sol";

interface ISygmaValidateReceived {
    function validateReceived(bytes32 transactionGuid, SygmaTypes.SygmaInsurance memory insurance) external;
}
