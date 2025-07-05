// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SygmaTypes} from "./SygmaTypes.sol";
import {OAppRead} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SygmaState} from "./SygmaState.sol";

import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {ReadCodecV1, EVMCallRequestV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SygmaValidateReceived is Ownable {
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

    // Validation result codes
    uint256 public constant VALIDATION_SUCCESS = 1;
    uint256 public constant VALIDATION_FAILED_NOT_RECEIVED = 2;
    uint256 public constant VALIDATION_FAILED_INSUFFICIENT_AMOUNT = 3;
    uint256 public constant VALIDATION_FAILED_WRONG_RECIPIENT = 4;
    uint256 public constant VALIDATION_FAILED_WRONG_TOKEN = 5;
    uint256 public constant VALIDATION_FAILED_EXPIRED = 6;
    uint256 public constant VALIDATION_FAILED_ALREADY_CLAIMED = 7;

    // Struct to track received transactions
    struct ReceivedTransaction {
        bytes32 transactionGuid;
        address recipient;
        uint256 amount;
        address token;
        uint16 sourceChain;
        uint256 timestamp;
        bool exists;
        bool isClaimed;
    }

    // Mapping to track received transactions
    mapping(bytes32 => ReceivedTransaction) public receivedTransactions;

    // Mapping to track validated transactions
    mapping(bytes32 => bool) public validatedTransactions;

    // Mapping to track claimed transactions
    mapping(bytes32 => bool) public claimedTransactions;

    // Validation settings
    uint256 public validationTimeout = 24 hours; // Transaction expires after 24 hours
    uint256 public minimumAmount = 0; // Minimum amount to be considered valid

    // Authorized bridge contracts that can register transactions
    mapping(address => bool) public authorizedBridges;

    constructor() Ownable(msg.sender) {}

    // Admin functions
    function setValidationTimeout(uint256 _timeout) external onlyOwner {
        validationTimeout = _timeout;
    }

    function setMinimumAmount(uint256 _amount) external onlyOwner {
        minimumAmount = _amount;
    }

    function setAuthorizedBridge(
        address _bridge,
        bool _authorized
    ) external onlyOwner {
        authorizedBridges[_bridge] = _authorized;
    }

    // Function to register a received transaction (called by bridge contracts)
    function registerReceivedTransaction(
        bytes32 transactionGuid,
        address recipient,
        uint256 amount,
        address token,
        uint16 sourceChain
    ) external {
        require(
            authorizedBridges[msg.sender],
            "SygmaValidateReceived: Unauthorized bridge"
        );
        require(
            !receivedTransactions[transactionGuid].exists,
            "SygmaValidateReceived: Transaction already registered"
        );

        receivedTransactions[transactionGuid] = ReceivedTransaction({
            transactionGuid: transactionGuid,
            recipient: recipient,
            amount: amount,
            token: token,
            sourceChain: sourceChain,
            timestamp: block.timestamp,
            exists: true,
            isClaimed: false
        });

        emit TransactionReceived(
            transactionGuid,
            recipient,
            amount,
            token,
            sourceChain,
            block.timestamp
        );
    }

    // Function to mark a transaction as claimed
    function markTransactionClaimed(bytes32 transactionGuid) external {
        require(
            authorizedBridges[msg.sender],
            "SygmaValidateReceived: Unauthorized bridge"
        );
        require(
            receivedTransactions[transactionGuid].exists,
            "SygmaValidateReceived: Transaction not found"
        );

        receivedTransactions[transactionGuid].isClaimed = true;
        claimedTransactions[transactionGuid] = true;
    }

    // Main validation function - checks if a bridging transaction was actually received
    function validateReceived(
        SygmaTypes.SygmaTransaction memory transaction
    ) public returns (uint256) {
        bytes32 transactionGuid = transaction.transactionGuid;

        // Check if transaction exists in our records
        ReceivedTransaction memory receivedTx = receivedTransactions[
            transactionGuid
        ];
        if (!receivedTx.exists) {
            emit TransactionValidated(transactionGuid, false, block.timestamp);
            return VALIDATION_FAILED_NOT_RECEIVED;
        }

        // Check if transaction has already been claimed
        if (receivedTx.isClaimed) {
            emit TransactionValidated(transactionGuid, false, block.timestamp);
            return VALIDATION_FAILED_ALREADY_CLAIMED;
        }

        // Check if transaction has expired
        if (block.timestamp > receivedTx.timestamp + validationTimeout) {
            emit TransactionValidated(transactionGuid, false, block.timestamp);
            return VALIDATION_FAILED_EXPIRED;
        }

        // Validate recipient matches
        if (receivedTx.recipient != transaction.toAddress) {
            emit TransactionValidated(transactionGuid, false, block.timestamp);
            return VALIDATION_FAILED_WRONG_RECIPIENT;
        }

        // Validate token matches
        if (receivedTx.token != transaction.toToken) {
            emit TransactionValidated(transactionGuid, false, block.timestamp);
            return VALIDATION_FAILED_WRONG_TOKEN;
        }

        // Validate amount is sufficient
        if (
            receivedTx.amount < transaction.amount ||
            receivedTx.amount < minimumAmount
        ) {
            emit TransactionValidated(transactionGuid, false, block.timestamp);
            return VALIDATION_FAILED_INSUFFICIENT_AMOUNT;
        }

        // Validate source chain matches
        if (receivedTx.sourceChain != transaction.sourceChain) {
            emit TransactionValidated(transactionGuid, false, block.timestamp);
            return VALIDATION_FAILED_WRONG_RECIPIENT; // Reusing code for chain mismatch
        }

        // All validations passed
        validatedTransactions[transactionGuid] = true;
        emit TransactionValidated(transactionGuid, true, block.timestamp);
        return VALIDATION_SUCCESS;
    }

    // Enhanced validation with detailed checks
    function validateReceivedDetailed(
        SygmaTypes.SygmaTransaction memory transaction
    )
        public
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
        )
    {
        bytes32 transactionGuid = transaction.transactionGuid;
        ReceivedTransaction memory receivedTx = receivedTransactions[
            transactionGuid
        ];

        exists = receivedTx.exists;
        isClaimed = receivedTx.isClaimed;
        isExpired = block.timestamp > receivedTx.timestamp + validationTimeout;
        recipientMatches = receivedTx.recipient == transaction.toAddress;
        tokenMatches = receivedTx.token == transaction.toToken;
        amountSufficient =
            receivedTx.amount >= transaction.amount &&
            receivedTx.amount >= minimumAmount;
        chainMatches = receivedTx.sourceChain == transaction.sourceChain;

        // Determine validation result
        if (!exists) {
            validationResult = VALIDATION_FAILED_NOT_RECEIVED;
        } else if (isClaimed) {
            validationResult = VALIDATION_FAILED_ALREADY_CLAIMED;
        } else if (isExpired) {
            validationResult = VALIDATION_FAILED_EXPIRED;
        } else if (!recipientMatches) {
            validationResult = VALIDATION_FAILED_WRONG_RECIPIENT;
        } else if (!tokenMatches) {
            validationResult = VALIDATION_FAILED_WRONG_TOKEN;
        } else if (!amountSufficient) {
            validationResult = VALIDATION_FAILED_INSUFFICIENT_AMOUNT;
        } else if (!chainMatches) {
            validationResult = VALIDATION_FAILED_WRONG_RECIPIENT; // Reusing for chain mismatch
        } else {
            validationResult = VALIDATION_SUCCESS;
        }
    }

    // Check if a transaction was received
    function isTransactionReceived(
        bytes32 transactionGuid
    ) external view returns (bool) {
        return receivedTransactions[transactionGuid].exists;
    }

    // Check if a transaction was validated
    function isTransactionValidated(
        bytes32 transactionGuid
    ) external view returns (bool) {
        return validatedTransactions[transactionGuid];
    }

    // Check if a transaction was claimed
    function isTransactionClaimed(
        bytes32 transactionGuid
    ) external view returns (bool) {
        return claimedTransactions[transactionGuid];
    }

    // Get received transaction details
    function getReceivedTransaction(
        bytes32 transactionGuid
    ) external view returns (ReceivedTransaction memory) {
        return receivedTransactions[transactionGuid];
    }

    // Simulate receiving a transaction for testing purposes
    function simulateReceivedTransaction(
        bytes32 transactionGuid,
        address recipient,
        uint256 amount,
        address token,
        uint16 sourceChain
    ) external onlyOwner {
        receivedTransactions[transactionGuid] = ReceivedTransaction({
            transactionGuid: transactionGuid,
            recipient: recipient,
            amount: amount,
            token: token,
            sourceChain: sourceChain,
            timestamp: block.timestamp,
            exists: true,
            isClaimed: false
        });

        emit TransactionReceived(
            transactionGuid,
            recipient,
            amount,
            token,
            sourceChain,
            block.timestamp
        );
    }

    // Get validation result description
    function getValidationResultDescription(
        uint256 result
    ) external pure returns (string memory) {
        if (result == VALIDATION_SUCCESS)
            return "Transaction validated successfully";
        if (result == VALIDATION_FAILED_NOT_RECEIVED)
            return "Transaction not received";
        if (result == VALIDATION_FAILED_INSUFFICIENT_AMOUNT)
            return "Insufficient amount received";
        if (result == VALIDATION_FAILED_WRONG_RECIPIENT)
            return "Wrong recipient or chain";
        if (result == VALIDATION_FAILED_WRONG_TOKEN)
            return "Wrong token received";
        if (result == VALIDATION_FAILED_EXPIRED) return "Transaction expired";
        if (result == VALIDATION_FAILED_ALREADY_CLAIMED)
            return "Transaction already claimed";
        return "Unknown validation result";
    }
}
