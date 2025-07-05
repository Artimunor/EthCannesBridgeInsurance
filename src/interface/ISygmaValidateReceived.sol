// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SygmaTypes} from "../SygmaTypes.sol";

interface ISygmaValidateReceived {
    // Main validation function
    function validateReceived(
        SygmaTypes.SygmaTransaction memory transaction
    ) external returns (uint256);

    // Enhanced validation with detailed results
    function validateReceivedDetailed(
        SygmaTypes.SygmaTransaction memory transaction
    )
        external
        view
        returns (
            uint256 validationResult,
            bool exists,
            bool isClaimed,
            bool isExpired,
            bool recipientMatches,
            bool tokenMatches,
            bool amountSufficient,
            bool chainMatches
        );

    // Transaction status functions
    function isTransactionReceived(
        bytes32 transactionGuid
    ) external view returns (bool);

    function isTransactionValidated(
        bytes32 transactionGuid
    ) external view returns (bool);

    function isTransactionClaimed(
        bytes32 transactionGuid
    ) external view returns (bool);

    // Admin functions
    function registerReceivedTransaction(
        bytes32 transactionGuid,
        address recipient,
        uint256 amount,
        address token,
        uint16 sourceChain
    ) external;

    function markTransactionClaimed(bytes32 transactionGuid) external;

    // Utility functions
    function getValidationResultDescription(
        uint256 result
    ) external pure returns (string memory);

    // Events
    event TransactionReceived(
        bytes32 indexed transactionGuid,
        address indexed recipient,
        uint256 amount,
        address token,
        uint16 sourceChain,
        uint256 timestamp
    );

    event TransactionValidated(
        bytes32 indexed transactionGuid,
        bool isValid,
        uint256 timestamp
    );
}
