// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

contract FeeCollector {
    address public owner;
    uint public balance;

    constructor() {
        owner = msg.sender;
    }

    receive() payable external {
        balance += msg.value;
    }

    function withdraw (uint amount, address payable destinationAddr) public {
        require(msg.sender == owner, "Only owner can withdraw!");
        require(amount < balance, "Insufficent funds !");

        destinationAddr.transfer(amount);
        balance -= amount;
    } 
}