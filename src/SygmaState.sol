// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {SygmaTypes} from "../lib/SygmaTypes.sol";
import {OAppRead} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";

contract SygmaState {
    mapping(bytes32 => SygmaTypes.SygmaInsurance) public insurance;

    function addInsurance(
        bytes32 _transactionGuid,
        SygmaTypes.SygmaInsurance memory _insurance
    ) public {
        insurance[_transactionGuid] = _insurance;
    }

    function getInsurance(
        bytes32 _transactionGuid
    ) public view returns (SygmaTypes.SygmaInsurance memory) {
        return insurance[_transactionGuid];
    }
}
