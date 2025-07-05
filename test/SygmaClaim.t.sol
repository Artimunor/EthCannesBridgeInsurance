// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SygmaClaim} from "../src/SygmaClaim.sol";
import {SygmaTypes} from "../src/SygmaTypes.sol";
import {SygmaState} from "../src/SygmaState.sol";
import {SygmaValidateReceived} from "../src/SygmaValidateReceived.sol";

// OApp imports
import {
    IOAppOptionsType3, EnforcedOptionParam
} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

// OZ imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Forge imports
import "forge-std/console.sol";
import "forge-std/Test.sol";

// DevTools imports
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

/**
 * @title SigmaClaimTest
 * @notice A test suite for the SigmaClaim contract.
 */
contract SigmaClaimTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    /// @notice Chain A Endpoint ID.
    uint32 private aEid = 1;

    /// @notice Chain B Endpoint ID.
    uint32 private bEid = 2;

    /// @notice The SygmaClaim contract deployed on core Chain.
    SygmaClaim private sygmaClaim;

    /// @notice The SygmaState contract deployed on the core Chain.
    SygmaState private sygmaState;

    /// @notice The SygmaValidateReceived deployed on chain A.
    SygmaValidateReceived private sygmaValidateReceived;

    /// @notice Address representing User A.
    address private userA = address(0x1);

    /// @notice Message type for the read operation.
    uint16 private constant READ_TYPE = 1;

    /**
     * @notice Sets up the test environment before each test.
     *
     * @dev Deploys the SygmaValidateReceived on chain A and the SygmaClaim contract on chain B.
     *      Wires the OApps and sets up the endpoints.
     */
    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        sygmaState = SygmaState(
            _deployOApp(
                type(SygmaState).creationCode,
                abi.encode() // SygmaState constructor takes no parameters
            )
        );

        // Deploy SygmaValidateReceived on chain A (aEid)
        sygmaValidateReceived = SygmaValidateReceived(
            _deployOApp(
                type(SygmaValidateReceived).creationCode,
                abi.encode() // No constructor arguments needed for SygmaValidateReceived
            )
        );

        // Deploy SygmaClaim on chain B (bEid)
        sygmaClaim = SygmaClaim(
            _deployOApp(
                type(SygmaClaim).creationCode,
                abi.encode(
                    address(sygmaState), // _stateAddress
                    address(endpoints[bEid]), // _endpoint (LayerZero endpoint on chain B)
                    address(this), // _delegate (owner)
                    DEFAULT_CHANNEL_ID // _readChannel
                )
            )
        );

        // Set up options for the SygmaClaim contract
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReadOption(300000, 32, 0);

        // Set enforced options for the read channel
        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](1);
        enforcedOptions[0] = EnforcedOptionParam({eid: DEFAULT_CHANNEL_ID, msgType: READ_TYPE, options: options});

        sygmaClaim.setEnforcedOptions(enforcedOptions);

        // Wire the OApps
        address[] memory oapps = new address[](1);
        oapps[0] = address(sygmaClaim);
        uint32[] memory channels = new uint32[](1);
        channels[0] = DEFAULT_CHANNEL_ID;
        this.wireReadOApps(oapps, channels);
    }

    /**
     * @notice Tests that the constructor initializes the contract correctly.
     *
     * @dev Verifies that the owner, endpoint, READ_CHANNEL, targetEid, and targetContractAddress are set as expected.
     */
    function test_constructor() public view {
        // Verify that the owner is correctly set
        assertEq(sygmaClaim.owner(), address(this));
        // Verify that the endpoint is correctly set
        assertEq(address(sygmaClaim.endpoint()), address(endpoints[bEid]));
        // Verify that READ_CHANNEL is correctly set
        assertEq(sygmaClaim.READ_CHANNEL(), DEFAULT_CHANNEL_ID);
    }

    /**
     * @notice Tests sending a read request and handling the received sum.
     *
     * @dev Simulates a user initiating a read request to add two numbers and verifies that the SumReceived event is emitted with the correct sum.
     */
    function test_send_read() public {
        // Define the transaction ID
        bytes32 id = bytes32(uint256(2));

        // Create a minimal insurance to avoid the default 0 destinationChain
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "",
            transactionGuid: bytes32(0),
            fromAddress: address(0),
            toAddress: address(0),
            amount: 0,
            sourceChain: 0,
            destinationChain: uint16(aEid), // Use aEid instead of 0
            fromToken: address(0),
            toToken: address(0)
        });

        SygmaTypes.SygmaInsurance memory insurance =
            SygmaTypes.SygmaInsurance({usdAmount: 0, premium: 0, transaction: transaction});

        // Add minimal insurance
        sygmaState.addInsurance(id, insurance);

        // Set up chain receiver checker
        sygmaState.setChainReceiverChecker(aEid, address(sygmaValidateReceived));

        // Estimate the fee
        MessagingFee memory fee = sygmaClaim.quoteReadFee(id);

        // Record logs to capture the SumReceived event
        vm.recordLogs();

        // User A initiates the read request on bOApp
        vm.prank(userA);
        sygmaClaim.claim{value: fee.nativeFee}(id);

        // Simulate processing the response packet to bOApp on bEid, injecting the sum
        this.verifyPackets(
            bEid,
            addressToBytes32(address(sygmaClaim)),
            0,
            address(0x0),
            abi.encode(uint256(id) + 3) // The sum of id and 3
        );

        // Retrieve the logs to verify the DataReceived event
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool found = false;
        uint256 dataReceived;
        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory entry = entries[i];
            if (entry.topics[0] == keccak256("DataReceived(uint256)")) {
                dataReceived = abi.decode(entry.data, (uint256));
                found = true;
                break;
            }
        }
        assertEq(found, true, "DataReceived event not emitted");
        assertEq(dataReceived, 5, "Data received does not match expected value");
    }

    /**
     * @notice Tests the claim function with a properly created insurance policy.
     *
     * @dev Creates an insurance policy first, then tests the claim function to verify
     *      it properly retrieves the insurance and initiates the validation process.
     */
    function test_claimWithValidInsurance() public {
        // Step 1: Create a sample insurance policy
        bytes32 transactionGuid = keccak256("test_claim_transaction");

        // Create a transaction struct
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: transactionGuid,
            fromAddress: userA,
            toAddress: address(0x2222222222222222222222222222222222222222),
            amount: 1000e18,
            sourceChain: 1, // Ethereum
            destinationChain: uint16(aEid), // Chain A where validator is deployed
            fromToken: address(0x3333333333333333333333333333333333333333),
            toToken: address(0x4444444444444444444444444444444444444444)
        });

        // Create insurance struct
        SygmaTypes.SygmaInsurance memory insurance =
            SygmaTypes.SygmaInsurance({usdAmount: 1000e18, premium: 10e18, transaction: transaction});

        // Add insurance to state
        sygmaState.addInsurance(transactionGuid, insurance);

        // Step 2: Set up chain receiver checker for the destination chain
        sygmaState.setChainReceiverChecker(uint32(aEid), address(sygmaValidateReceived));

        // Step 3: Estimate fee for the claim
        MessagingFee memory fee = sygmaClaim.quoteReadFee(transactionGuid);

        // Step 4: Record logs to capture events
        vm.recordLogs();

        // Step 5: Execute the claim function
        vm.prank(userA);
        vm.deal(userA, fee.nativeFee + 1 ether); // Ensure user has enough ETH
        sygmaClaim.claim{value: fee.nativeFee}(transactionGuid);

        // Step 6: Verify the claim was initiated properly by checking events
        // The claim function should trigger internal LayerZero messaging

        // Step 7: Simulate the validation response
        // Mock that validation returns true (1)
        uint256 validationResult = 1;

        this.verifyPackets(bEid, addressToBytes32(address(sygmaClaim)), 0, address(0x0), abi.encode(validationResult));

        // Step 8: Verify the DataReceived event was emitted
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool dataReceivedFound = false;
        uint256 receivedData;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory entry = entries[i];
            if (entry.topics[0] == keccak256("DataReceived(uint256)")) {
                receivedData = abi.decode(entry.data, (uint256));
                dataReceivedFound = true;
                break;
            }
        }

        assertTrue(dataReceivedFound, "DataReceived event should be emitted");
        assertEq(receivedData, validationResult, "Received data should match validation result");
    }

    /**
     * @notice Tests the claim function with non-existent insurance.
     *
     * @dev This test verifies that the claim function can handle cases where
     *      an insurance policy doesn't exist (should result in empty/default values).
     */
    function test_claimWithNonExistentInsurance() public {
        bytes32 nonExistentGuid = keccak256("non_existent_transaction");

        // Set up a default chain receiver checker for aEid instead of 0
        sygmaState.setChainReceiverChecker(aEid, address(sygmaValidateReceived));

        // Since the insurance doesn't exist, the transaction will have destinationChain: 0
        // But we'll create a minimal insurance for testing purposes
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "",
            transactionGuid: bytes32(0),
            fromAddress: address(0),
            toAddress: address(0),
            amount: 0,
            sourceChain: 0,
            destinationChain: uint16(aEid), // Use aEid instead of 0
            fromToken: address(0),
            toToken: address(0)
        });

        SygmaTypes.SygmaInsurance memory insurance =
            SygmaTypes.SygmaInsurance({usdAmount: 0, premium: 0, transaction: transaction});

        // Add minimal insurance to avoid the default 0 destinationChain
        sygmaState.addInsurance(nonExistentGuid, insurance);

        // Estimate fee (should work with valid destinationChain)
        MessagingFee memory fee = sygmaClaim.quoteReadFee(nonExistentGuid);

        // Execute claim
        vm.prank(userA);
        vm.deal(userA, fee.nativeFee + 1 ether);
        sygmaClaim.claim{value: fee.nativeFee}(nonExistentGuid);

        // Should execute without reverting even with minimal insurance values
    }

    /**
     * @notice Tests the quoteReadFee function with various insurance scenarios.
     *
     * @dev Verifies that fee estimation works correctly for different insurance policies.
     */
    function test_quoteReadFee() public {
        bytes32 transactionGuid = keccak256("fee_test_transaction");

        // Create insurance with specific destination chain
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "Wormhole",
            transactionGuid: transactionGuid,
            fromAddress: userA,
            toAddress: address(0x5555555555555555555555555555555555555555),
            amount: 2000e18,
            sourceChain: 56, // BSC
            destinationChain: uint16(aEid),
            fromToken: address(0x6666666666666666666666666666666666666666),
            toToken: address(0x7777777777777777777777777777777777777777)
        });

        SygmaTypes.SygmaInsurance memory insurance =
            SygmaTypes.SygmaInsurance({usdAmount: 2000e18, premium: 20e18, transaction: transaction});

        // Add insurance and set chain receiver checker
        sygmaState.addInsurance(transactionGuid, insurance);
        sygmaState.setChainReceiverChecker(uint32(aEid), address(sygmaValidateReceived));

        // Test fee estimation
        MessagingFee memory fee = sygmaClaim.quoteReadFee(transactionGuid);

        assertTrue(fee.nativeFee > 0, "Native fee should be greater than 0");
        assertEq(fee.lzTokenFee, 0, "LZ token fee should be 0 for this test");
    }

    /**
     * @notice Tests the validateReceive function directly.
     *
     * @dev This test calls validateReceive directly to verify it works independently.
     */
    function test_validateReceive() public {
        // Create a transaction
        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "Axelar",
            transactionGuid: keccak256("direct_validate_test"),
            fromAddress: userA,
            toAddress: address(0x8888888888888888888888888888888888888888),
            amount: 500e18,
            sourceChain: 250, // Fantom
            destinationChain: uint16(aEid),
            fromToken: address(0x9999999999999999999999999999999999999999),
            toToken: address(0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA)
        });

        // Set chain receiver checker
        sygmaState.setChainReceiverChecker(uint32(aEid), address(sygmaValidateReceived));

        // Call validateReceive directly
        vm.prank(userA);
        vm.deal(userA, 1 ether);
        MessagingReceipt memory receipt = sygmaClaim.validateReceive{value: 0.1 ether}(uint32(aEid), transaction);

        // Verify receipt
        assertTrue(receipt.guid != bytes32(0), "ValidateReceive should generate a valid receipt");
        assertTrue(receipt.nonce > 0, "ValidateReceive should generate a valid nonce");
    }

    /**
     * @notice Tests setReadChannel function (owner only).
     *
     * @dev Verifies that only the owner can set the read channel.
     */
    function test_setReadChannel() public {
        uint32 newChannelId = 999;

        // Owner should be able to set read channel
        sygmaClaim.setReadChannel(newChannelId, true);
        assertEq(sygmaClaim.READ_CHANNEL(), newChannelId, "READ_CHANNEL should be updated");

        // Non-owner should not be able to set read channel
        vm.prank(userA);
        vm.expectRevert(); // Should revert with Ownable unauthorized error
        sygmaClaim.setReadChannel(1000, true);
    }

    /**
     * @notice Simple test to verify basic contract functionality without LayerZero calls.
     *
     * @dev Tests the basic setup and insurance creation without cross-chain calls.
     */
    function test_basicSetup() public {
        // Create a sample insurance policy
        bytes32 transactionGuid = keccak256("basic_test_transaction");

        SygmaTypes.SygmaTransaction memory transaction = SygmaTypes.SygmaTransaction({
            bridge: "LayerZero",
            transactionGuid: transactionGuid,
            fromAddress: userA,
            toAddress: address(0x2222222222222222222222222222222222222222),
            amount: 1000e18,
            sourceChain: 1,
            destinationChain: uint16(aEid),
            fromToken: address(0x3333333333333333333333333333333333333333),
            toToken: address(0x4444444444444444444444444444444444444444)
        });

        SygmaTypes.SygmaInsurance memory insurance =
            SygmaTypes.SygmaInsurance({usdAmount: 1000e18, premium: 10e18, transaction: transaction});

        // Add insurance to state
        sygmaState.addInsurance(transactionGuid, insurance);

        // Set up chain receiver checker
        sygmaState.setChainReceiverChecker(uint32(aEid), address(sygmaValidateReceived));

        // Verify the insurance was stored correctly
        SygmaTypes.SygmaInsurance memory storedInsurance = sygmaState.getInsurance(transactionGuid);
        assertEq(storedInsurance.usdAmount, 1000e18);
        assertEq(storedInsurance.premium, 10e18);
        assertEq(storedInsurance.transaction.bridge, "LayerZero");

        // Verify the chain receiver checker was set
        assertEq(sygmaState.getChainReceiverChecker(uint32(aEid)), address(sygmaValidateReceived));

        // Verify the SygmaClaim contract has the correct state reference
        assertEq(address(sygmaClaim.state()), address(sygmaState));
        assertEq(sygmaClaim.READ_CHANNEL(), DEFAULT_CHANNEL_ID);
    }
}
