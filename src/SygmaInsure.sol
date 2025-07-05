// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SygmaTypes} from "./SygmaTypes.sol";
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
        // Implement payment logic here, e.g., transfer premium from insuree to contract
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes
            .SygmaTransaction({
                bridge: bridge,
                transactionGuid: transactionGuid,
                fromAddress: insuree,
                toAddress: toAddress,
                amount: usdAmount,
                sourceChain: sourceChain,
                destinationChain: toChain,
                fromToken: fromToken,
                toToken: toToken
            });

        SygmaTypes.SygmaInsurance memory insurance = SygmaTypes.SygmaInsurance({
            usdAmount: usdAmount,
            premium: premium,
            transaction: transaction
        });

        state.addInsurance(transactionGuid, insurance);
    }
}
