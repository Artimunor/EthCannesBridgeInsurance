// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

library SygmaTypes {
    struct SygmaInsurance {
        uint256 usdAmount;
        uint256 premium;
        string bridge;
        address insuree;
        uint16 sourceChain;
        address toAddress;
        uint16 toChain;
        address fromToken;
        address toToken;
    }
}
