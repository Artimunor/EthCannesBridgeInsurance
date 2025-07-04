// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {SygmaTypes} from "../lib/SygmaTypes.sol";

contract Insure {
    uint256 public number;

    mapping(bytes => SygmaTypes.SygmaInsurance) public insurance;

    function insure(
        bytes memory id,
        uint256 usdAmount,
        uint256 premium,
        string memory bridge,
        address insuree,
        string memory sourceChain,
        address toAddress,
        string memory toChain,
        address fromToken,
        address toToken
    ) public {
        insurance[id] = SygmaTypes.SygmaInsurance({
            usdAmount: usdAmount,
            premium: premium,
            bridge: bridge,
            insuree: insuree,
            sourceChain: sourceChain,
            toChain: toChain,
            toAddress: toAddress,
            fromToken: fromToken,
            toToken: toToken
        });
    }
}
