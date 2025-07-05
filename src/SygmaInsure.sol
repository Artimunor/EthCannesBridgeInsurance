// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {SygmaTypes} from "../lib/SygmaTypes.sol";
import {SygmaState} from "./SygmaState.sol";

contract SygmaInsure {
    SygmaState public state;

    constructor(address _stateAddress) {
        state = SygmaState(_stateAddress);
    }

    function insure(
        bytes32 transactionGuid,
        uint256 usdAmount,
        uint256 premium,
        string memory bridge,
        address insuree,
        uint16 sourceChain,
        address toAddress,
        uint16 toChain,
        address fromToken,
        address toToken
    ) public {
        SygmaTypes.SygmaInsurance memory insurance = SygmaTypes.SygmaInsurance({
            usdAmount: usdAmount,
            premium: premium,
            bridge: bridge,
            insuree: insuree,
            sourceChain: sourceChain,
            toAddress: toAddress,
            toChain: toChain,
            fromToken: fromToken,
            toToken: toToken
        });

        state.addInsurance(transactionGuid, insurance);
    }
}
