// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {SygmaTypes} from "../lib/SygmaTypes.sol";
import {OAppRead} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import {SygmaState} from "./SygmaState.sol";

contract SygmaClaim {
    SygmaState public state;

    constructor(address _stateAddress) {
        state = SygmaState(_stateAddress);
    }

    function claim(bytes32 transactionGuid) public {
        SygmaTypes.SygmaInsurance memory insurance = state.getInsurance(
            transactionGuid
        );

        // Implement claim logic here
    }
}
