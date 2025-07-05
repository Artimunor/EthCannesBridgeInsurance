// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {SygmaState} from "../src/SygmaState.sol";
import {SygmaTypes} from "../src/SygmaTypes.sol";

contract SygmaStateTest is Test {
    SygmaState public state;

    address public owner = address(this);
    address public nonOwner = address(0x1111111111111111111111111111111111111111);
    address public mockChecker1 = address(0x2222222222222222222222222222222222222222);
    address public mockChecker2 = address(0x3333333333333333333333333333333333333333);

    bytes32 public constant MOCK_TRANSACTION_GUID = keccak256("test_transaction");
    bytes32 public constant MOCK_TRANSACTION_GUID_2 = keccak256("test_transaction_2");

    uint32 public constant CHAIN_ID_1 = 1; // Ethereum
    uint32 public constant CHAIN_ID_2 = 137; // Polygon
    uint32 public constant CHAIN_ID_3 = 56; // BSC

    function setUp() public {
        state = new SygmaState();
    }

    function test_Constructor() public view {
        assertEq(state.owner(), owner);
    }

    function test_AddInsurance() public {
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: MOCK_TRANSACTION_GUID,
            fromAddress: address(0x1234),
            toAddress: address(0x5678),
            amount: 1000e18,
            sourceChain: 1,
            destinationChain: 137,
            fromToken: address(0xABCD),
            toToken: address(0xEF12)
        });

        SygmaTypes.SygmaInsurance memory insurance =
            SygmaTypes.SygmaInsurance({usdAmount: 1000e18, premium: 10e18, transaction: transaction});

        state.addInsurance(MOCK_TRANSACTION_GUID, insurance);

        SygmaTypes.SygmaInsurance memory storedInsurance = state.getInsurance(MOCK_TRANSACTION_GUID);

        assertEq(storedInsurance.usdAmount, 1000e18);
        assertEq(storedInsurance.premium, 10e18);
        assertEq(storedInsurance.transaction.bridge, "LayerZero");
        assertEq(storedInsurance.transaction.transactionGuid, MOCK_TRANSACTION_GUID);
        assertEq(storedInsurance.transaction.fromAddress, address(0x1234));
        assertEq(storedInsurance.transaction.toAddress, address(0x5678));
        assertEq(storedInsurance.transaction.amount, 1000e18);
        assertEq(storedInsurance.transaction.sourceChain, 1);
        assertEq(storedInsurance.transaction.destinationChain, 137);
        assertEq(storedInsurance.transaction.fromToken, address(0xABCD));
        assertEq(storedInsurance.transaction.toToken, address(0xEF12));
    }

    function test_AddInsuranceFromNonOwner() public {
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "Wormhole",
            transactionGuid: MOCK_TRANSACTION_GUID,
            fromAddress: nonOwner,
            toAddress: address(0x5678),
            amount: 500e18,
            sourceChain: 56,
            destinationChain: 43114,
            fromToken: address(0xABCD),
            toToken: address(0xEF12)
        });

        SygmaTypes.SygmaInsurance memory insurance =
            SygmaTypes.SygmaInsurance({usdAmount: 500e18, premium: 5e18, transaction: transaction});

        // Anyone can add insurance, not just the owner
        vm.prank(nonOwner);
        state.addInsurance(MOCK_TRANSACTION_GUID, insurance);

        SygmaTypes.SygmaInsurance memory storedInsurance = state.getInsurance(MOCK_TRANSACTION_GUID);
        assertEq(storedInsurance.usdAmount, 500e18);
        assertEq(storedInsurance.premium, 5e18);
        assertEq(storedInsurance.transaction.bridge, "Wormhole");
    }

    function test_GetInsuranceNonExistent() public view {
        bytes32 nonExistentGuid = keccak256("non_existent");
        SygmaTypes.SygmaInsurance memory insurance = state.getInsurance(nonExistentGuid);

        // Should return empty/default values
        assertEq(insurance.usdAmount, 0);
        assertEq(insurance.premium, 0);
        assertEq(insurance.transaction.bridge, "");
        assertEq(insurance.transaction.transactionGuid, bytes32(0));
        assertEq(insurance.transaction.fromAddress, address(0));
        assertEq(insurance.transaction.toAddress, address(0));
        assertEq(insurance.transaction.amount, 0);
        assertEq(insurance.transaction.sourceChain, 0);
        assertEq(insurance.transaction.destinationChain, 0);
        assertEq(insurance.transaction.fromToken, address(0));
        assertEq(insurance.transaction.toToken, address(0));
    }

    function test_OverwriteInsurance() public {
        // Add initial insurance
        SygmaTypes.SygmaTransaction memory transaction1 = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: MOCK_TRANSACTION_GUID,
            fromAddress: address(0x1234),
            toAddress: address(0x5678),
            amount: 1000e18,
            sourceChain: 1,
            destinationChain: 137,
            fromToken: address(0xABCD),
            toToken: address(0xEF12)
        });

        SygmaTypes.SygmaInsurance memory insurance1 =
            SygmaTypes.SygmaInsurance({usdAmount: 1000e18, premium: 10e18, transaction: transaction1});

        state.addInsurance(MOCK_TRANSACTION_GUID, insurance1);

        // Overwrite with new insurance
        SygmaTypes.SygmaTransaction memory transaction2 = SygmaTypes.SygmaTransaction({
            bridge: "Wormhole",
            transactionGuid: MOCK_TRANSACTION_GUID,
            fromAddress: address(0x9999),
            toAddress: address(0x8888),
            amount: 2000e18,
            sourceChain: 56,
            destinationChain: 43114,
            fromToken: address(0x7777),
            toToken: address(0x6666)
        });

        SygmaTypes.SygmaInsurance memory insurance2 =
            SygmaTypes.SygmaInsurance({usdAmount: 2000e18, premium: 20e18, transaction: transaction2});

        state.addInsurance(MOCK_TRANSACTION_GUID, insurance2);

        SygmaTypes.SygmaInsurance memory storedInsurance = state.getInsurance(MOCK_TRANSACTION_GUID);

        // Should have new values
        assertEq(storedInsurance.usdAmount, 2000e18);
        assertEq(storedInsurance.premium, 20e18);
        assertEq(storedInsurance.transaction.bridge, "Wormhole");
        assertEq(storedInsurance.transaction.fromAddress, address(0x9999));
        assertEq(storedInsurance.transaction.toAddress, address(0x8888));
        assertEq(storedInsurance.transaction.amount, 2000e18);
        assertEq(storedInsurance.transaction.sourceChain, 56);
        assertEq(storedInsurance.transaction.destinationChain, 43114);
        assertEq(storedInsurance.transaction.fromToken, address(0x7777));
        assertEq(storedInsurance.transaction.toToken, address(0x6666));
    }

    function test_AddMultipleInsurances() public {
        // Add first insurance
        SygmaTypes.SygmaTransaction memory transaction1 = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: MOCK_TRANSACTION_GUID,
            fromAddress: address(0x1111),
            toAddress: address(0x2222),
            amount: 1000e18,
            sourceChain: 1,
            destinationChain: 137,
            fromToken: address(0x3333),
            toToken: address(0x4444)
        });

        SygmaTypes.SygmaInsurance memory insurance1 =
            SygmaTypes.SygmaInsurance({usdAmount: 1000e18, premium: 10e18, transaction: transaction1});

        // Add second insurance
        SygmaTypes.SygmaTransaction memory transaction2 = SygmaTypes.SygmaTransaction({
            bridge: "Wormhole",
            transactionGuid: MOCK_TRANSACTION_GUID_2,
            fromAddress: address(0x5555),
            toAddress: address(0x6666),
            amount: 2000e18,
            sourceChain: 56,
            destinationChain: 43114,
            fromToken: address(0x7777),
            toToken: address(0x8888)
        });

        SygmaTypes.SygmaInsurance memory insurance2 =
            SygmaTypes.SygmaInsurance({usdAmount: 2000e18, premium: 20e18, transaction: transaction2});

        state.addInsurance(MOCK_TRANSACTION_GUID, insurance1);
        state.addInsurance(MOCK_TRANSACTION_GUID_2, insurance2);

        // Verify both insurances are stored correctly
        SygmaTypes.SygmaInsurance memory storedInsurance1 = state.getInsurance(MOCK_TRANSACTION_GUID);
        SygmaTypes.SygmaInsurance memory storedInsurance2 = state.getInsurance(MOCK_TRANSACTION_GUID_2);

        assertEq(storedInsurance1.usdAmount, 1000e18);
        assertEq(storedInsurance1.premium, 10e18);
        assertEq(storedInsurance1.transaction.bridge, "LayerZero");

        assertEq(storedInsurance2.usdAmount, 2000e18);
        assertEq(storedInsurance2.premium, 20e18);
        assertEq(storedInsurance2.transaction.bridge, "Wormhole");
    }

    function test_SetChainReceiverChecker() public {
        state.setChainReceiverChecker(CHAIN_ID_1, mockChecker1);

        assertEq(state.getChainReceiverChecker(CHAIN_ID_1), mockChecker1);
        assertEq(state.chainReceiverCheckers(CHAIN_ID_1), mockChecker1);
    }

    function test_SetChainReceiverCheckerOnlyOwner() public {
        // Owner can set checker
        state.setChainReceiverChecker(CHAIN_ID_1, mockChecker1);
        assertEq(state.getChainReceiverChecker(CHAIN_ID_1), mockChecker1);

        // Non-owner cannot set checker
        vm.prank(nonOwner);
        vm.expectRevert(); // Should revert with Ownable unauthorized error
        state.setChainReceiverChecker(CHAIN_ID_2, mockChecker2);
    }

    function test_GetChainReceiverCheckerNonExistent() public view {
        address checker = state.getChainReceiverChecker(999);
        assertEq(checker, address(0));
    }

    function test_UpdateChainReceiverChecker() public {
        // Set initial checker
        state.setChainReceiverChecker(CHAIN_ID_1, mockChecker1);
        assertEq(state.getChainReceiverChecker(CHAIN_ID_1), mockChecker1);

        // Update checker
        state.setChainReceiverChecker(CHAIN_ID_1, mockChecker2);
        assertEq(state.getChainReceiverChecker(CHAIN_ID_1), mockChecker2);
    }

    function test_SetMultipleChainReceiverCheckers() public {
        state.setChainReceiverChecker(CHAIN_ID_1, mockChecker1);
        state.setChainReceiverChecker(CHAIN_ID_2, mockChecker2);
        state.setChainReceiverChecker(CHAIN_ID_3, mockChecker1); // Same checker for different chain

        assertEq(state.getChainReceiverChecker(CHAIN_ID_1), mockChecker1);
        assertEq(state.getChainReceiverChecker(CHAIN_ID_2), mockChecker2);
        assertEq(state.getChainReceiverChecker(CHAIN_ID_3), mockChecker1);
    }

    function test_SetChainReceiverCheckerToZeroAddress() public {
        // Set checker to zero address (should be allowed)
        state.setChainReceiverChecker(CHAIN_ID_1, address(0));
        assertEq(state.getChainReceiverChecker(CHAIN_ID_1), address(0));
    }

    function test_InsurancePublicMapping() public {
        // Test that the public mapping works correctly
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "TestBridge",
            transactionGuid: MOCK_TRANSACTION_GUID,
            fromAddress: address(0x1234),
            toAddress: address(0x5678),
            amount: 1000e18,
            sourceChain: 1,
            destinationChain: 137,
            fromToken: address(0xABCD),
            toToken: address(0xEF12)
        });

        SygmaTypes.SygmaInsurance memory insurance =
            SygmaTypes.SygmaInsurance({usdAmount: 1000e18, premium: 10e18, transaction: transaction});

        state.addInsurance(MOCK_TRANSACTION_GUID, insurance);

        // Access via public getter function instead of mapping
        SygmaTypes.SygmaInsurance memory publicInsurance = state.getInsurance(MOCK_TRANSACTION_GUID);

        assertEq(publicInsurance.usdAmount, 1000e18);
        assertEq(publicInsurance.premium, 10e18);
        assertEq(publicInsurance.transaction.bridge, "TestBridge");
    }

    function test_ChainReceiverCheckersPublicMapping() public {
        state.setChainReceiverChecker(CHAIN_ID_1, mockChecker1);

        // Access via public mapping
        address publicChecker = state.chainReceiverCheckers(CHAIN_ID_1);
        assertEq(publicChecker, mockChecker1);
    }

    function testFuzz_AddInsuranceWithRandomValues(
        uint256 usdAmount,
        uint256 premium,
        uint256 amount,
        uint16 sourceChain,
        uint16 destinationChain,
        address fromAddress,
        address toAddress,
        address fromToken,
        address toToken
    ) public {
        bytes32 randomGuid = keccak256(abi.encodePacked(block.timestamp, msg.sender, usdAmount));

        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "FuzzBridge",
            transactionGuid: randomGuid,
            fromAddress: fromAddress,
            toAddress: toAddress,
            amount: amount,
            sourceChain: sourceChain,
            destinationChain: destinationChain,
            fromToken: fromToken,
            toToken: toToken
        });

        SygmaTypes.SygmaInsurance memory insurance =
            SygmaTypes.SygmaInsurance({usdAmount: usdAmount, premium: premium, transaction: transaction});

        state.addInsurance(randomGuid, insurance);

        SygmaTypes.SygmaInsurance memory storedInsurance = state.getInsurance(randomGuid);

        assertEq(storedInsurance.usdAmount, usdAmount);
        assertEq(storedInsurance.premium, premium);
        assertEq(storedInsurance.transaction.bridge, "FuzzBridge");
        assertEq(storedInsurance.transaction.transactionGuid, randomGuid);
        assertEq(storedInsurance.transaction.fromAddress, fromAddress);
        assertEq(storedInsurance.transaction.toAddress, toAddress);
        assertEq(storedInsurance.transaction.amount, amount);
        assertEq(storedInsurance.transaction.sourceChain, sourceChain);
        assertEq(storedInsurance.transaction.destinationChain, destinationChain);
        assertEq(storedInsurance.transaction.fromToken, fromToken);
        assertEq(storedInsurance.transaction.toToken, toToken);
    }

    function testFuzz_SetChainReceiverChecker(uint32 chainId, address checker) public {
        state.setChainReceiverChecker(chainId, checker);
        assertEq(state.getChainReceiverChecker(chainId), checker);
    }

    function test_OwnershipTransfer() public {
        address newOwner = address(0x9999999999999999999999999999999999999999);

        // Transfer ownership
        state.transferOwnership(newOwner);

        // New owner should be able to set chain receiver checker
        vm.prank(newOwner);
        state.setChainReceiverChecker(CHAIN_ID_1, mockChecker1);

        assertEq(state.getChainReceiverChecker(CHAIN_ID_1), mockChecker1);

        // Old owner should not be able to set chain receiver checker
        vm.expectRevert(); // Should revert with Ownable unauthorized error
        state.setChainReceiverChecker(CHAIN_ID_2, mockChecker2);
    }

    function test_AddInsuranceWithEmptyValues() public {
        bytes32 emptyGuid = keccak256("empty_transaction");

        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "",
            transactionGuid: bytes32(0),
            fromAddress: address(0),
            toAddress: address(0),
            amount: 0,
            sourceChain: 0,
            destinationChain: 0,
            fromToken: address(0),
            toToken: address(0)
        });

        SygmaTypes.SygmaInsurance memory insurance =
            SygmaTypes.SygmaInsurance({usdAmount: 0, premium: 0, transaction: transaction});

        state.addInsurance(emptyGuid, insurance);

        SygmaTypes.SygmaInsurance memory storedInsurance = state.getInsurance(emptyGuid);

        assertEq(storedInsurance.usdAmount, 0);
        assertEq(storedInsurance.premium, 0);
        assertEq(storedInsurance.transaction.bridge, "");
        assertEq(storedInsurance.transaction.transactionGuid, bytes32(0));
        assertEq(storedInsurance.transaction.fromAddress, address(0));
        assertEq(storedInsurance.transaction.toAddress, address(0));
        assertEq(storedInsurance.transaction.amount, 0);
        assertEq(storedInsurance.transaction.sourceChain, 0);
        assertEq(storedInsurance.transaction.destinationChain, 0);
        assertEq(storedInsurance.transaction.fromToken, address(0));
        assertEq(storedInsurance.transaction.toToken, address(0));
    }
}
