// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

library SygmaTypes {
    struct SygmaInsurance {
        uint256 usdAmount;
        uint256 premium;
        SygmaTransaction transaction;
    }

    struct SygmaTransaction {
        string bridge;
        bytes32 transactionGuid;
        address fromAddress; // insuree's address
        address toAddress;
        uint256 amount;
        uint16 sourceChain;
        uint16 destinationChain;
        address fromToken;
        address toToken;
    }

    struct SygmaClaim {
        bytes32 transactionGuid;
        address claimer;
        uint256 claimAmount;
        uint256 claimTime;
        bool isClaimed;
    }
}
