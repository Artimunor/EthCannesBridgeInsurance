// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {OAppRead} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {ReadCodecV1, EVMCallRequestV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SygmaState} from "./SygmaState.sol";
import {SygmaTypes} from "./SygmaTypes.sol";
import {ISygmaValidateReceived} from "./interface/ISygmaValidateReceived.sol";

contract SygmaClaim is OAppRead, OAppOptionsType3 {
    SygmaState public state;

    event DataReceived(uint256 data);

    // LayerZero read channel ID.
    uint32 public READ_CHANNEL;

    // Message type for the read operation.
    uint16 public constant READ_TYPE = 1;

    constructor(
        address _stateAddress,
        address _endpoint,
        address _delegate,
        uint32 _readChannel
    ) OAppRead(_endpoint, _delegate) Ownable(msg.sender) {
        state = SygmaState(_stateAddress);
        READ_CHANNEL = _readChannel;
        _setPeer(_readChannel, AddressCast.toBytes32(address(this)));
    }

    function claim(bytes32 transactionGuid) external payable {
        SygmaTypes.SygmaInsurance memory insurance = state.getInsurance(
            transactionGuid
        );
        SygmaTypes.SygmaTransaction memory transaction = insurance.transaction;

        validateReceive(transaction.destinationChain, transaction);
    }

    /**
     * @notice Estimates the messaging fee required to perform the read operation.
     *
     * @param _transactionGuid The transaction GUID for which to estimate the fee.
     *
     * @return fee The estimated messaging fee.
     */
    function quoteReadFee(
        bytes32 _transactionGuid
    ) public view returns (MessagingFee memory fee) {
        SygmaTypes.SygmaInsurance memory insurance = state.getInsurance(
            _transactionGuid
        );
        SygmaTypes.SygmaTransaction memory transaction = insurance.transaction;

        address destinationChainReceiverChecker = state.getChainReceiverChecker(
            transaction.destinationChain
        );
        return
            _quote(
                READ_CHANNEL,
                _getCmdValidateReceive(
                    destinationChainReceiverChecker,
                    transaction.destinationChain,
                    transaction
                ),
                this.combineOptions(READ_CHANNEL, READ_TYPE, new bytes(0)),
                false
            );
    }

    /**
     * @notice Claim logic to read data from a target contract on a remote chain.
     *
     * @dev The caller must send enough ETH to cover the messaging fee.
     *
     * @param _targetEid The target chain's Endpoint ID.
     *
     * @return receipt The LayerZero messaging receipt for the request.
     */
    function validateReceive(
        uint32 _targetEid,
        SygmaTypes.SygmaTransaction memory _transaction
    ) public payable returns (MessagingReceipt memory receipt) {
        address destinationChainReceiverChecker = state.getChainReceiverChecker(
            _transaction.destinationChain
        );

        bytes memory cmd = _getCmdValidateReceive(
            destinationChainReceiverChecker,
            _targetEid,
            _transaction
        );

        return
            _lzSend(
                READ_CHANNEL,
                cmd,
                this.combineOptions(READ_CHANNEL, READ_TYPE, new bytes(0)),
                MessagingFee(msg.value, 0),
                payable(msg.sender)
            );
    }

    /**
     * @notice Constructs the read command to fetch the `data` variable from target chain.
     * @dev This function defines the core read operation - what data to fetch and from where.
     *      Replace this logic to read different functions or data from your target contracts.
     *
     * @param _targetContractAddress The address of the contract containing the `data` variable.
     * @param _targetEid The target chain's Endpoint ID.
     *
     * @return cmd The encoded command that specifies what data to read.
     */
    function _getCmdValidateReceive(
        address _targetContractAddress,
        uint32 _targetEid,
        SygmaTypes.SygmaTransaction memory transaction
    ) internal view returns (bytes memory cmd) {
        // 1. Define WHAT function to call on the target contract
        //    Using the interface selector ensures type safety and correctness
        //    You can replace this with any public/external function or state variable
        bytes memory callData = abi.encodeWithSelector(
            ISygmaValidateReceived.validateReceived.selector,
            transaction
        );

        // 2. Build the read request specifying WHERE and HOW to fetch the data
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
        readRequests[0] = EVMCallRequestV1({
            appRequestLabel: 1, // Label for tracking this specific request
            targetEid: _targetEid, // WHICH chain to read from
            isBlockNum: false, // Use timestamp (not block number)
            blockNumOrTimestamp: uint64(block.timestamp), // WHEN to read the state (current time)
            confirmations: 15, // HOW many confirmations to wait for
            to: _targetContractAddress, // WHERE - the contract address to call
            callData: callData // WHAT - the function call to execute
        });

        // 3. Encode the complete read command
        //    No compute logic needed for simple data reading
        //    The appLabel (0) can be used to identify different types of read operations
        cmd = ReadCodecV1.encode(0, readRequests);
    }

    /**
     * @notice Handles the received data from the target chain.
     *
     * @dev This function is called internally by the LayerZero protocol.
     * @dev   _origin    Metadata (source chain, sender address, nonce)
     * @dev   _guid      Global unique ID for tracking this response
     * @param _message   The data returned from the read request (uint256 in this case)
     * @dev   _executor  Executor address that delivered the response
     * @dev   _extraData Additional data from the Executor (unused here)
     */
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        // 1. Decode the returned data from bytes to uint256
        uint256 data = abi.decode(_message, (uint256));

        // 2. Emit an event with the received data
        emit DataReceived(data);

        // 3. (Optional) Apply your custom logic here.
        //    e.g., store the data, trigger additional actions, etc.
    }

    /**
     * @notice Sets the LayerZero read channel.
     *
     * @dev Only callable by the owner.
     *
     * @param _channelId The channel ID to set.
     * @param _active Flag to activate or deactivate the channel.
     */
    function setReadChannel(
        uint32 _channelId,
        bool _active
    ) public override onlyOwner {
        _setPeer(
            _channelId,
            _active ? AddressCast.toBytes32(address(this)) : bytes32(0)
        );
        READ_CHANNEL = _channelId;
    }
}
