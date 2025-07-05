// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {SygmaInsure} from "../src/SygmaInsure.sol";
import {SygmaState} from "../src/SygmaState.sol";
import {SygmaTypes} from "../src/SygmaTypes.sol";

contract SygmaInsureTest is Test {
    SygmaInsure public insure;
    SygmaState public state;

    address public mockInsuree = address(0x1111111111111111111111111111111111111111);
    address public mockToAddress = address(0x2222222222222222222222222222222222222222);
    address public mockFromToken = address(0x3333333333333333333333333333333333333333);
    address public mockToToken = address(0x4444444444444444444444444444444444444444);

    bytes32 public constant MOCK_TRANSACTION_GUID = keccak256("test_transaction");
    uint256 public constant MOCK_USD_AMOUNT = 1000e18; // 1000 USD
    uint256 public constant MOCK_PREMIUM = 10e18; // 10 USD premium
    string public constant MOCK_BRIDGE = "LayerZero";
    uint16 public constant MOCK_SOURCE_CHAIN = 1; // Ethereum
    uint16 public constant MOCK_TO_CHAIN = 137; // Polygon

    function setUp() public {
        // Deploy SygmaState first
        state = new SygmaState();

        // Deploy SygmaInsure with the state contract address
        insure = new SygmaInsure(address(state));
    }

    function test_Constructor() public view {
        assertEq(address(insure.state()), address(state));
    }

    function test_InsureBasic() public {
        // Test basic insurance creation
        insure.insure(
            MOCK_TRANSACTION_GUID,
            MOCK_USD_AMOUNT,
            MOCK_PREMIUM,
            MOCK_BRIDGE,
            mockInsuree,
            MOCK_SOURCE_CHAIN,
            mockToAddress,
            MOCK_TO_CHAIN,
            mockFromToken,
            mockToToken
        );

        // Verify insurance was stored in state
        SygmaTypes.SygmaInsurance memory storedInsurance = state.getInsurance(MOCK_TRANSACTION_GUID);

        assertEq(storedInsurance.usdAmount, MOCK_USD_AMOUNT);
        assertEq(storedInsurance.premium, MOCK_PREMIUM);
        assertEq(storedInsurance.transaction.bridge, MOCK_BRIDGE);
        assertEq(storedInsurance.transaction.transactionGuid, MOCK_TRANSACTION_GUID);
        assertEq(storedInsurance.transaction.fromAddress, mockInsuree);
        assertEq(storedInsurance.transaction.toAddress, mockToAddress);
        assertEq(storedInsurance.transaction.amount, MOCK_USD_AMOUNT);
        assertEq(storedInsurance.transaction.sourceChain, MOCK_SOURCE_CHAIN);
        assertEq(storedInsurance.transaction.destinationChain, MOCK_TO_CHAIN);
        assertEq(storedInsurance.transaction.fromToken, mockFromToken);
        assertEq(storedInsurance.transaction.toToken, mockToToken);
    }

    function test_InsureWithDifferentParameters() public {
        bytes32 transactionGuid2 = keccak256("test_transaction_2");
        uint256 usdAmount2 = 500e18;
        uint256 premium2 = 5e18;
        string memory bridge2 = "Wormhole";
        address insuree2 = address(0x5555555555555555555555555555555555555555);
        uint16 sourceChain2 = 56; // BSC
        address toAddress2 = address(0x6666666666666666666666666666666666666666);
        uint16 toChain2 = 43114; // Avalanche
        address fromToken2 = address(0x7777777777777777777777777777777777777777);
        address toToken2 = address(0x8888888888888888888888888888888888888888);

        insure.insure(
            transactionGuid2,
            usdAmount2,
            premium2,
            bridge2,
            insuree2,
            sourceChain2,
            toAddress2,
            toChain2,
            fromToken2,
            toToken2
        );

        SygmaTypes.SygmaInsurance memory storedInsurance = state.getInsurance(transactionGuid2);

        assertEq(storedInsurance.usdAmount, usdAmount2);
        assertEq(storedInsurance.premium, premium2);
        assertEq(storedInsurance.transaction.bridge, bridge2);
        assertEq(storedInsurance.transaction.transactionGuid, transactionGuid2);
        assertEq(storedInsurance.transaction.fromAddress, insuree2);
        assertEq(storedInsurance.transaction.toAddress, toAddress2);
        assertEq(storedInsurance.transaction.amount, usdAmount2);
        assertEq(storedInsurance.transaction.sourceChain, sourceChain2);
        assertEq(storedInsurance.transaction.destinationChain, toChain2);
        assertEq(storedInsurance.transaction.fromToken, fromToken2);
        assertEq(storedInsurance.transaction.toToken, toToken2);
    }

    function test_InsureMultipleTransactions() public {
        bytes32 guid1 = keccak256("transaction_1");
        bytes32 guid2 = keccak256("transaction_2");
        bytes32 guid3 = keccak256("transaction_3");

        // Create multiple insurance policies
        insure.insure(
            guid1, 1000e18, 10e18, "LayerZero", mockInsuree, 1, mockToAddress, 137, mockFromToken, mockToToken
        );

        insure.insure(
            guid2, 2000e18, 20e18, "Wormhole", mockInsuree, 56, mockToAddress, 43114, mockFromToken, mockToToken
        );

        insure.insure(guid3, 3000e18, 30e18, "Axelar", mockInsuree, 250, mockToAddress, 10, mockFromToken, mockToToken);

        // Verify all three insurances are stored correctly
        SygmaTypes.SygmaInsurance memory insurance1 = state.getInsurance(guid1);
        SygmaTypes.SygmaInsurance memory insurance2 = state.getInsurance(guid2);
        SygmaTypes.SygmaInsurance memory insurance3 = state.getInsurance(guid3);

        assertEq(insurance1.usdAmount, 1000e18);
        assertEq(insurance1.premium, 10e18);
        assertEq(insurance1.transaction.bridge, "LayerZero");

        assertEq(insurance2.usdAmount, 2000e18);
        assertEq(insurance2.premium, 20e18);
        assertEq(insurance2.transaction.bridge, "Wormhole");

        assertEq(insurance3.usdAmount, 3000e18);
        assertEq(insurance3.premium, 30e18);
        assertEq(insurance3.transaction.bridge, "Axelar");
    }

    function test_InsureWithZeroValues() public {
        bytes32 zeroGuid = keccak256("zero_transaction");

        insure.insure(
            zeroGuid,
            0, // Zero USD amount
            0, // Zero premium
            "TestBridge",
            address(0),
            0,
            address(0),
            0,
            address(0),
            address(0)
        );

        SygmaTypes.SygmaInsurance memory storedInsurance = state.getInsurance(zeroGuid);

        assertEq(storedInsurance.usdAmount, 0);
        assertEq(storedInsurance.premium, 0);
        assertEq(storedInsurance.transaction.fromAddress, address(0));
        assertEq(storedInsurance.transaction.toAddress, address(0));
        assertEq(storedInsurance.transaction.amount, 0);
        assertEq(storedInsurance.transaction.sourceChain, 0);
        assertEq(storedInsurance.transaction.destinationChain, 0);
        assertEq(storedInsurance.transaction.fromToken, address(0));
        assertEq(storedInsurance.transaction.toToken, address(0));
    }

    function test_InsureOverwriteExisting() public {
        // Create initial insurance
        insure.insure(
            MOCK_TRANSACTION_GUID,
            MOCK_USD_AMOUNT,
            MOCK_PREMIUM,
            MOCK_BRIDGE,
            mockInsuree,
            MOCK_SOURCE_CHAIN,
            mockToAddress,
            MOCK_TO_CHAIN,
            mockFromToken,
            mockToToken
        );

        // Overwrite with new values
        uint256 newUsdAmount = 2000e18;
        uint256 newPremium = 25e18;
        string memory newBridge = "Synapse";

        insure.insure(
            MOCK_TRANSACTION_GUID, // Same GUID
            newUsdAmount,
            newPremium,
            newBridge,
            mockInsuree,
            MOCK_SOURCE_CHAIN,
            mockToAddress,
            MOCK_TO_CHAIN,
            mockFromToken,
            mockToToken
        );

        SygmaTypes.SygmaInsurance memory storedInsurance = state.getInsurance(MOCK_TRANSACTION_GUID);

        // Should have new values
        assertEq(storedInsurance.usdAmount, newUsdAmount);
        assertEq(storedInsurance.premium, newPremium);
        assertEq(storedInsurance.transaction.bridge, newBridge);
    }

    function test_InsureWithLargeValues() public {
        bytes32 largeGuid = keccak256("large_transaction");
        uint256 largeUsdAmount = type(uint256).max / 2;
        uint256 largePremium = type(uint256).max / 4;
        uint16 maxChainId = type(uint16).max;

        insure.insure(
            largeGuid,
            largeUsdAmount,
            largePremium,
            "LargeBridge",
            mockInsuree,
            maxChainId,
            mockToAddress,
            maxChainId,
            mockFromToken,
            mockToToken
        );

        SygmaTypes.SygmaInsurance memory storedInsurance = state.getInsurance(largeGuid);

        assertEq(storedInsurance.usdAmount, largeUsdAmount);
        assertEq(storedInsurance.premium, largePremium);
        assertEq(storedInsurance.transaction.sourceChain, maxChainId);
        assertEq(storedInsurance.transaction.destinationChain, maxChainId);
    }

    function test_InsureWithEmptyBridge() public {
        bytes32 emptyBridgeGuid = keccak256("empty_bridge_transaction");

        insure.insure(
            emptyBridgeGuid,
            MOCK_USD_AMOUNT,
            MOCK_PREMIUM,
            "", // Empty bridge name
            mockInsuree,
            MOCK_SOURCE_CHAIN,
            mockToAddress,
            MOCK_TO_CHAIN,
            mockFromToken,
            mockToToken
        );

        SygmaTypes.SygmaInsurance memory storedInsurance = state.getInsurance(emptyBridgeGuid);

        assertEq(storedInsurance.transaction.bridge, "");
        assertEq(storedInsurance.usdAmount, MOCK_USD_AMOUNT);
        assertEq(storedInsurance.premium, MOCK_PREMIUM);
    }

    function test_StateContractInteraction() public {
        // Test that the insure contract correctly interacts with the state contract
        address initialOwner = state.owner();
        assertTrue(initialOwner != address(0));

        // Ensure the insure contract can call addInsurance on the state contract
        insure.insure(
            MOCK_TRANSACTION_GUID,
            MOCK_USD_AMOUNT,
            MOCK_PREMIUM,
            MOCK_BRIDGE,
            mockInsuree,
            MOCK_SOURCE_CHAIN,
            mockToAddress,
            MOCK_TO_CHAIN,
            mockFromToken,
            mockToToken
        );

        // Verify the data was stored
        SygmaTypes.SygmaInsurance memory storedInsurance = state.getInsurance(MOCK_TRANSACTION_GUID);
        assertEq(storedInsurance.usdAmount, MOCK_USD_AMOUNT);
    }

    function testFuzz_InsureWithRandomParameters(
        uint256 usdAmount,
        uint256 premium,
        uint16 sourceChain,
        uint16 destinationChain,
        address insuree,
        address toAddress,
        address fromToken,
        address toToken
    ) public {
        bytes32 randomGuid = keccak256(abi.encodePacked(block.timestamp, msg.sender, usdAmount));

        insure.insure(
            randomGuid,
            usdAmount,
            premium,
            "FuzzBridge",
            insuree,
            sourceChain,
            toAddress,
            destinationChain,
            fromToken,
            toToken
        );

        SygmaTypes.SygmaInsurance memory storedInsurance = state.getInsurance(randomGuid);

        assertEq(storedInsurance.usdAmount, usdAmount);
        assertEq(storedInsurance.premium, premium);
        assertEq(storedInsurance.transaction.fromAddress, insuree);
        assertEq(storedInsurance.transaction.toAddress, toAddress);
        assertEq(storedInsurance.transaction.sourceChain, sourceChain);
        assertEq(storedInsurance.transaction.destinationChain, destinationChain);
        assertEq(storedInsurance.transaction.fromToken, fromToken);
        assertEq(storedInsurance.transaction.toToken, toToken);
    }
}
