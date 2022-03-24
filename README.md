# Project _Voting.sol_

## Description

A voting smart contract can be simple or complex, depending on the requirements of the elections you wish to support. 
The vote may be on a small number of pre-selected proposals (or candidates), or on a potentially large number of proposals suggested dynamically by the voters themselves.

In this project, you will write a voting smart contract for a small organization. 
Voters, all known to the organization, are whitelisted by their Ethereum address, can submit new proposals during a proposal registration session, and can vote on proposals during the voting session.

✔️ The vote is not secret

✔️ Each voter can see the votes of others

✔️ The winner is determined by simple majority

✔️ The proposal that gets the most votes wins.## Install _OpenZeppelin_ with _NPM_


👉 The voting process:

Here's how the entire voting process unfolds:

1) The voting administrator registers a whitelist of voters identified by their Ethereum address.
2) The voting administrator starts the recording session of the proposal.
3) Registered voters are allowed to register their proposals while the registration session is active.
4) The voting administrator terminates the proposal recording session.
5) The voting administrator starts the voting session.
6) Registered voters vote for their preferred proposal.
7) The voting administrator ends the voting session.
8) The voting administrator counts the votes.
9) Everyone can check the final details of the winning proposal.


## Install



```shell
npm init -y
```

then : 

```shell
npm i @openzeppelin/contracts
```
