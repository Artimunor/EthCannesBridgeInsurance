// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {SygmaValidateReceived} from "../src/SygmaValidateReceived.sol";
import {SygmaTypes} from "../src/SygmaTypes.sol";

contract SygmaValidateReceivedTest is Test {
    SygmaValidateReceived public validator;

    address public owner = address(this);
    address public bridge1 = address(0x1111111111111111111111111111111111111111);
    address public bridge2 = address(0x2222222222222222222222222222222222222222);
    address public user = address(0x3333333333333333333333333333333333333333);
    address public token = address(0x4444444444444444444444444444444444444444);

    bytes32 public constant TRANSACTION_GUID = keccak256("test_transaction");
    bytes32 public constant TRANSACTION_GUID_2 = keccak256("test_transaction_2");

    function setUp() public {
        validator = new SygmaValidateReceived();

        // Set up authorized bridge
        validator.setAuthorizedBridge(bridge1, true);
        validator.setAuthorizedBridge(bridge2, true);
    }

    function test_InitialState() public view {
        assertEq(validator.owner(), owner);
        assertEq(validator.validationTimeout(), 24 hours);
        assertEq(validator.minimumAmount(), 0);
        assertTrue(validator.authorizedBridges(bridge1));
        assertTrue(validator.authorizedBridges(bridge2));
    }

    function test_RegisterReceivedTransaction() public {
        vm.prank(bridge1);
        validator.registerReceivedTransaction(TRANSACTION_GUID, user, 1000e18, token, 1);

        assertTrue(validator.isTransactionReceived(TRANSACTION_GUID));

        SygmaValidateReceived.ReceivedTransaction memory receivedTx = validator.getReceivedTransaction(TRANSACTION_GUID);
        assertEq(receivedTx.transactionGuid, TRANSACTION_GUID);
        assertEq(receivedTx.recipient, user);
        assertEq(receivedTx.amount, 1000e18);
        assertEq(receivedTx.token, token);
        assertEq(receivedTx.sourceChain, 1);
        assertTrue(receivedTx.exists);
        assertFalse(receivedTx.isClaimed);
    }

    function test_RegisterReceivedTransactionUnauthorized() public {
        vm.prank(user); // Not an authorized bridge
        vm.expectRevert("SygmaValidateReceived: Unauthorized bridge");
        validator.registerReceivedTransaction(TRANSACTION_GUID, user, 1000e18, token, 1);
    }

    function test_RegisterDuplicateTransaction() public {
        // Register first transaction
        vm.prank(bridge1);
        validator.registerReceivedTransaction(TRANSACTION_GUID, user, 1000e18, token, 1);

        // Try to register same transaction again
        vm.prank(bridge1);
        vm.expectRevert("SygmaValidateReceived: Transaction already registered");
        validator.registerReceivedTransaction(TRANSACTION_GUID, user, 1000e18, token, 1);
    }

    function test_ValidateReceivedSuccess() public {
        // Register received transaction
        vm.prank(bridge1);
        validator.registerReceivedTransaction(TRANSACTION_GUID, user, 1000e18, token, 1);

        // Create matching transaction to validate
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: TRANSACTION_GUID,
            fromAddress: address(0x5555),
            toAddress: user,
            amount: 1000e18,
            sourceChain: 1,
            destinationChain: 2,
            fromToken: address(0x6666),
            toToken: token
        });

        uint256 result = validator.validateReceived(transaction);
        assertEq(result, validator.VALIDATION_SUCCESS());
        assertTrue(validator.isTransactionValidated(TRANSACTION_GUID));
    }

    function test_ValidateReceivedNotReceived() public {
        // Create transaction that was never received
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: TRANSACTION_GUID,
            fromAddress: address(0x5555),
            toAddress: user,
            amount: 1000e18,
            sourceChain: 1,
            destinationChain: 2,
            fromToken: address(0x6666),
            toToken: token
        });

        uint256 result = validator.validateReceived(transaction);
        assertEq(result, validator.VALIDATION_FAILED_NOT_RECEIVED());
        assertFalse(validator.isTransactionValidated(TRANSACTION_GUID));
    }

    function test_ValidateReceivedWrongRecipient() public {
        // Register received transaction
        vm.prank(bridge1);
        validator.registerReceivedTransaction(TRANSACTION_GUID, user, 1000e18, token, 1);

        // Create transaction with wrong recipient
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: TRANSACTION_GUID,
            fromAddress: address(0x5555),
            toAddress: address(0x9999), // Wrong recipient
            amount: 1000e18,
            sourceChain: 1,
            destinationChain: 2,
            fromToken: address(0x6666),
            toToken: token
        });

        uint256 result = validator.validateReceived(transaction);
        assertEq(result, validator.VALIDATION_FAILED_WRONG_RECIPIENT());
        assertFalse(validator.isTransactionValidated(TRANSACTION_GUID));
    }

    function test_ValidateReceivedWrongToken() public {
        // Register received transaction
        vm.prank(bridge1);
        validator.registerReceivedTransaction(TRANSACTION_GUID, user, 1000e18, token, 1);

        // Create transaction with wrong token
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: TRANSACTION_GUID,
            fromAddress: address(0x5555),
            toAddress: user,
            amount: 1000e18,
            sourceChain: 1,
            destinationChain: 2,
            fromToken: address(0x6666),
            toToken: address(0x9999) // Wrong token
        });

        uint256 result = validator.validateReceived(transaction);
        assertEq(result, validator.VALIDATION_FAILED_WRONG_TOKEN());
        assertFalse(validator.isTransactionValidated(TRANSACTION_GUID));
    }

    function test_ValidateReceivedInsufficientAmount() public {
        // Register received transaction
        vm.prank(bridge1);
        validator.registerReceivedTransaction(
            TRANSACTION_GUID,
            user,
            500e18, // Received less
            token,
            1
        );

        // Create transaction expecting more
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: TRANSACTION_GUID,
            fromAddress: address(0x5555),
            toAddress: user,
            amount: 1000e18, // Expecting more
            sourceChain: 1,
            destinationChain: 2,
            fromToken: address(0x6666),
            toToken: token
        });

        uint256 result = validator.validateReceived(transaction);
        assertEq(result, validator.VALIDATION_FAILED_INSUFFICIENT_AMOUNT());
        assertFalse(validator.isTransactionValidated(TRANSACTION_GUID));
    }

    function test_ValidateReceivedAlreadyClaimed() public {
        // Register received transaction
        vm.prank(bridge1);
        validator.registerReceivedTransaction(TRANSACTION_GUID, user, 1000e18, token, 1);

        // Mark as claimed
        vm.prank(bridge1);
        validator.markTransactionClaimed(TRANSACTION_GUID);

        // Try to validate claimed transaction
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: TRANSACTION_GUID,
            fromAddress: address(0x5555),
            toAddress: user,
            amount: 1000e18,
            sourceChain: 1,
            destinationChain: 2,
            fromToken: address(0x6666),
            toToken: token
        });

        uint256 result = validator.validateReceived(transaction);
        assertEq(result, validator.VALIDATION_FAILED_ALREADY_CLAIMED());
        assertFalse(validator.isTransactionValidated(TRANSACTION_GUID));
        assertTrue(validator.isTransactionClaimed(TRANSACTION_GUID));
    }

    function test_ValidateReceivedExpired() public {
        // Register received transaction
        vm.prank(bridge1);
        validator.registerReceivedTransaction(TRANSACTION_GUID, user, 1000e18, token, 1);

        // Fast forward past timeout
        vm.warp(block.timestamp + 25 hours);

        // Try to validate expired transaction
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: TRANSACTION_GUID,
            fromAddress: address(0x5555),
            toAddress: user,
            amount: 1000e18,
            sourceChain: 1,
            destinationChain: 2,
            fromToken: address(0x6666),
            toToken: token
        });

        uint256 result = validator.validateReceived(transaction);
        assertEq(result, validator.VALIDATION_FAILED_EXPIRED());
        assertFalse(validator.isTransactionValidated(TRANSACTION_GUID));
    }

    function test_ValidateReceivedDetailed() public {
        // Register received transaction
        vm.prank(bridge1);
        validator.registerReceivedTransaction(TRANSACTION_GUID, user, 1000e18, token, 1);

        // Create matching transaction
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: TRANSACTION_GUID,
            fromAddress: address(0x5555),
            toAddress: user,
            amount: 1000e18,
            sourceChain: 1,
            destinationChain: 2,
            fromToken: address(0x6666),
            toToken: token
        });

        (
            uint256 validationResult,
            bool exists,
            bool isClaimed,
            bool isExpired,
            bool recipientMatches,
            bool tokenMatches,
            bool amountSufficient,
            bool chainMatches
        ) = validator.validateReceivedDetailed(transaction);

        assertEq(validationResult, validator.VALIDATION_SUCCESS());
        assertTrue(exists);
        assertFalse(isClaimed);
        assertFalse(isExpired);
        assertTrue(recipientMatches);
        assertTrue(tokenMatches);
        assertTrue(amountSufficient);
        assertTrue(chainMatches);
    }

    function test_SetValidationTimeout() public {
        validator.setValidationTimeout(48 hours);
        assertEq(validator.validationTimeout(), 48 hours);

        // Non-owner should not be able to set timeout
        vm.prank(user);
        vm.expectRevert(); // Should revert with Ownable unauthorized error
        validator.setValidationTimeout(12 hours);
    }

    function test_SetMinimumAmount() public {
        validator.setMinimumAmount(100e18);
        assertEq(validator.minimumAmount(), 100e18);

        // Non-owner should not be able to set minimum amount
        vm.prank(user);
        vm.expectRevert(); // Should revert with Ownable unauthorized error
        validator.setMinimumAmount(50e18);
    }

    function test_SetAuthorizedBridge() public {
        address newBridge = address(0x7777777777777777777777777777777777777777);

        validator.setAuthorizedBridge(newBridge, true);
        assertTrue(validator.authorizedBridges(newBridge));

        validator.setAuthorizedBridge(newBridge, false);
        assertFalse(validator.authorizedBridges(newBridge));

        // Non-owner should not be able to set authorized bridge
        vm.prank(user);
        vm.expectRevert(); // Should revert with Ownable unauthorized error
        validator.setAuthorizedBridge(newBridge, true);
    }

    function test_SimulateReceivedTransaction() public {
        validator.simulateReceivedTransaction(TRANSACTION_GUID, user, 1000e18, token, 1);

        assertTrue(validator.isTransactionReceived(TRANSACTION_GUID));

        SygmaValidateReceived.ReceivedTransaction memory receivedTx = validator.getReceivedTransaction(TRANSACTION_GUID);
        assertEq(receivedTx.amount, 1000e18);
        assertEq(receivedTx.recipient, user);
    }

    function test_GetValidationResultDescription() public view {
        assertEq(
            validator.getValidationResultDescription(validator.VALIDATION_SUCCESS()),
            "Transaction validated successfully"
        );
        assertEq(
            validator.getValidationResultDescription(validator.VALIDATION_FAILED_NOT_RECEIVED()),
            "Transaction not received"
        );
        assertEq(
            validator.getValidationResultDescription(validator.VALIDATION_FAILED_INSUFFICIENT_AMOUNT()),
            "Insufficient amount received"
        );
        assertEq(
            validator.getValidationResultDescription(validator.VALIDATION_FAILED_WRONG_RECIPIENT()),
            "Wrong recipient or chain"
        );
        assertEq(
            validator.getValidationResultDescription(validator.VALIDATION_FAILED_WRONG_TOKEN()), "Wrong token received"
        );
        assertEq(validator.getValidationResultDescription(validator.VALIDATION_FAILED_EXPIRED()), "Transaction expired");
        assertEq(
            validator.getValidationResultDescription(validator.VALIDATION_FAILED_ALREADY_CLAIMED()),
            "Transaction already claimed"
        );
        assertEq(validator.getValidationResultDescription(999), "Unknown validation result");
    }

    function test_EventsEmitted() public {
        vm.expectEmit(true, true, false, true);
        emit SygmaValidateReceived.TransactionReceived(TRANSACTION_GUID, user, 1000e18, token, 1, block.timestamp);

        vm.prank(bridge1);
        validator.registerReceivedTransaction(TRANSACTION_GUID, user, 1000e18, token, 1);

        // Test validation event
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: TRANSACTION_GUID,
            fromAddress: address(0x5555),
            toAddress: user,
            amount: 1000e18,
            sourceChain: 1,
            destinationChain: 2,
            fromToken: address(0x6666),
            toToken: token
        });

        vm.expectEmit(true, false, false, true);
        emit SygmaValidateReceived.TransactionValidated(TRANSACTION_GUID, true, block.timestamp);

        validator.validateReceived(transaction);
    }

    function testFuzz_ValidateReceived(uint256 amount, uint16 sourceChain, address recipient, address tokenAddr)
        public
    {
        vm.assume(amount > 0);
        vm.assume(recipient != address(0));
        vm.assume(tokenAddr != address(0));

        bytes32 randomGuid = keccak256(abi.encodePacked(block.timestamp, amount, recipient));

        // Register received transaction
        vm.prank(bridge1);
        validator.registerReceivedTransaction(randomGuid, recipient, amount, tokenAddr, sourceChain);

        // Create matching transaction
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "TestBridge",
            transactionGuid: randomGuid,
            fromAddress: address(0x5555),
            toAddress: recipient,
            amount: amount,
            sourceChain: sourceChain,
            destinationChain: 2,
            fromToken: address(0x6666),
            toToken: tokenAddr
        });

        uint256 result = validator.validateReceived(transaction);
        assertEq(result, validator.VALIDATION_SUCCESS());
        assertTrue(validator.isTransactionValidated(randomGuid));
    }
}
