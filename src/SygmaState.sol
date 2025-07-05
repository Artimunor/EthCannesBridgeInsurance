// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SygmaTypes} from "./SygmaTypes.sol";
import {OAppRead} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SygmaState is Ownable {
    constructor() Ownable(msg.sender) {}

    mapping(bytes32 => SygmaTypes.SygmaInsurance) public insurance;

    mapping(uint32 => address) public chainReceiverCheckers;

    function addInsurance(bytes32 _transactionGuid, SygmaTypes.SygmaInsurance memory _insurance) public {
        insurance[_transactionGuid] = _insurance;
    }

    function getInsurance(bytes32 _transactionGuid) public view returns (SygmaTypes.SygmaInsurance memory) {
        return insurance[_transactionGuid];
    }

    function setChainReceiverChecker(uint32 _chainId, address _checker) public onlyOwner {
        chainReceiverCheckers[_chainId] = _checker;
    }

    function getChainReceiverChecker(uint32 _chainId) public view returns (address) {
        return chainReceiverCheckers[_chainId];
    }
}
