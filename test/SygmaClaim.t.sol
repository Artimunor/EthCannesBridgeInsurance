// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SygmaClaim} from "../src/SygmaClaim.sol";
import {SygmaTypes} from "../src/SygmaTypes.sol";
import {SygmaState} from "../src/SygmaState.sol";
import {SygmaValidateReceived} from "../src/SygmaValidateReceived.sol";

// OApp imports
import {IOAppOptionsType3, EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
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
                abi.encode(address(this)) // Pass the owner address to the constructor
            )
        );

        // Deploy SygmaValidateReceived on chain A (aEid)
        // We simulate chain A by associating contracts with aEid
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
                    address(endpoints[bEid]), // _endpoint (LayerZero endpoint on chain B)
                    DEFAULT_CHANNEL_ID, // _readChannel
                    aEid, // _targetEid (Endpoint ID of chain A)
                    address(sygmaValidateReceived) // _targetContractAddress (ExampleContract on chain A)
                )
            )
        );

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
        // Prepare messaging options
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReadOption(1e8, 32, 0);

        SygmaTypes.SygmaInsurance memory insurance = sygmaState.getInsurance(
            0x0
        );
        SygmaTypes.SygmaTransaction memory transaction = insurance.transaction;

        // Define the numbers to add
        bytes32 id = bytes32(uint256(2));

        // Estimate the fee for calling readSum with arguments a and b
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

        // Retrieve the logs to verify the SumReceived event
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool found = false;
        uint256 sumReceived;
        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory entry = entries[i];
            if (entry.topics[0] == keccak256("SumReceived(uint256)")) {
                sumReceived = abi.decode(entry.data, (uint256));
                found = true;
                break;
            }
        }
        assertEq(found, true, "SumReceived event not emitted");
        assertEq(sumReceived, 0, "Sum received does not match expected value");
    }
}
