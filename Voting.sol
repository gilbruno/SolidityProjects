// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";


/**
 * TODO :: Be more accurate on functions visibility
 */

library StringLibrary {

    // Function that tests equality between 2 strings
    function equals(string memory a, string memory b) public pure returns (bool) {
        if (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b))) {
             return true;
        }
        return false;
    }
}    


contract Voting is Ownable {

    using StringLibrary for string;

    //------ STATE VARIABLES ------------------
    uint winningProposalId;
    mapping(address => Voter) public whiteList;
    address[] private voters; //Array of voters that are in the white list
    uint[] private winners; //Array to handle ex aequo winners
    Proposal[] private proposals;
    WorkflowStatus private workflowVoteStatus;
    bool boolWinnerFound;

    //------ EVENTS ----------------------
    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    //------ STRUCT ----------------------
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
        uint blockTimestampCount;
    }

    //------ ENUM ----------------------
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    //------ MODIFIERS ----------------------
    /**
     * Modifier to check if a voter exists in the white list
     */
    modifier checkDuplicateVoter(address _voterAddr) {
        require(whiteList[_voterAddr].isRegistered == false, "The voter already exists!");
        _;
    }

    /**
     * A proposal must be unique
     */
    modifier checkDuplicateProposal(string memory _proposal) {
        require(_proposalExist(_proposal) == false, "The proposal already exists!");
        _;
    }

    /**
     * A proposal must exist
     */
    modifier checkValidProposal(string memory _proposal) {
        require(_proposalExist(_proposal) == true, "The proposal does not exists!");
        _;
    }

    /**
     * Modifier that indicates if the '_voterAddr' exists in the white list
     */
    modifier onlyGrantedVoters(address _voterAddr) {
        require(whiteList[_voterAddr].isRegistered == true, "This voter is not granted to vote!");
        _;
    }

    /**
     * Modifier that indicates if the '_voterAddr' exists in the white list
     */
    modifier onlyWhenWorkflowStatusIs(WorkflowStatus _status) {
        require(workflowVoteStatus == _status, "You are not granted to vote due to bad workflow status!");
        _;
    }

    /**
     * Modifier that reverts the transaction if there are no proposal when the owner close the proposal recording
     */
    modifier atLeastOneProposal()
    {
        require(proposals.length > 0, "There must be at least one proposal");
        _;
    }

    /**
     * Modifier that reverts the transaction if there are no vote when the owner close the vote recording
     */
    modifier atLeastOneVote()
    {
        require(_atLeast1Vote(), "There must be at least one vote");
        _;
    }

    /**
     * Modifier that indicates if the '_voterAddr' exists in the white list
     */
    modifier checkProposalExists(string memory _proposal)
    {
        require(workflowVoteStatus == WorkflowStatus.ProposalsRegistrationStarted);
        _;
    }

    /**
     * Modifier : The voter must vote only once
     */
    modifier onlyOneVotePerVoter(address _voterAddr)
    {
        require(whiteList[_voterAddr].hasVoted == false, "You already vote");
        _;
    }

    /**
     * Modifier : The voter must be found to see it
     */
    modifier winnerFound()
    {
        require(boolWinnerFound == true, "The winner has not been found yet");
        _;
    }

    //---------------------------------------
    //------ FUNCTIONS ----------------------
    //---------------------------------------
    /**
     * Function getter to retrieve the array of voters
     */
    function getVoters() external view returns (address[] memory) {
        return voters;
    }

    /**
     * Function getter to retrieve the array of proposals
     */
    function getProposals() external view returns (Proposal[] memory) {
        return proposals;
    }

    /**
     * Get the winner
     */
    function getWinner() external view winnerFound returns (uint) {
        return winningProposalId;
    }

    /**
     * The admin can vote as well, so he must be added in the white list
     */
    function addAdminInWhiteList() private {
        whiteList[owner()] = Voter({isRegistered:true, hasVoted:false, votedProposalId:0});
        voters.push(owner());
    }

    /**
     * Add a voter in the whiteList
     */
    function addVoterIndWhiteList(address _voterAddr) external onlyOwner checkDuplicateVoter(_voterAddr) {
        //The first time this function is called, the admin is added to the white list 
        // and the worflow status becomes 'RegisteringVoters'
        if (voters.length == 0) {
            addAdminInWhiteList();
            _setWorkflowVoteStatus(WorkflowStatus.RegisteringVoters);
        }
        require(workflowVoteStatus == WorkflowStatus.RegisteringVoters, "You are not granted to add voter in the white list due to bad workflow status");
        whiteList[_voterAddr] = Voter({isRegistered:true, hasVoted:false, votedProposalId:0});
        voters.push(_voterAddr);
        emit VoterRegistered(_voterAddr);
    }

    /**
     * Start recording proposals of voters
     *    2 conditions : 
     *       - Only owner can do it
     *       - the current workflow must be "RegisteringVoters"
     */
    function startRecordingSessionProposal() external 
        onlyOwner 
        onlyWhenWorkflowStatusIs(WorkflowStatus.RegisteringVoters) {

        _setWorkflowVoteStatus(WorkflowStatus.ProposalsRegistrationStarted);
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /**
     * Granted voters give their proposals
     *    3 conditions : 
     *       - Only Granted voters can do it
     *       - the current workflow must be "ProposalsRegistrationStarted"
     *       - A proposal must be unique so exist the function when a proposal already exists
     */
    function votersPushProposals(string memory _proposal) external 
        onlyGrantedVoters(msg.sender) 
        onlyWhenWorkflowStatusIs(WorkflowStatus.ProposalsRegistrationStarted)
        checkDuplicateProposal(_proposal) {
            proposals.push(Proposal({description:_proposal, voteCount:0, blockTimestampCount:0}));
    }

    /**
     * End recording proposals of voters. 
     * 3 conditions : 
     *     - only the owner can do it
     *     - the current workflow must be "ProposalsRegistrationStarted"
     *     - There must be at least 1 proposal
     */
    function endRecordingSessionProposal() external 
        onlyOwner 
        onlyWhenWorkflowStatusIs(WorkflowStatus.ProposalsRegistrationStarted)
        atLeastOneProposal {

        _setWorkflowVoteStatus(WorkflowStatus.ProposalsRegistrationEnded);
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /**
     * Start recording Vote
     * 2 conditions : 
     *     - only the owner can do it
     *     - the current workflow must be "ProposalsRegistrationEnded"
     */
    function startRecordingVote() external 
        onlyOwner 
        onlyWhenWorkflowStatusIs(WorkflowStatus.ProposalsRegistrationEnded) {

        _setWorkflowVoteStatus(WorkflowStatus.VotingSessionStarted);
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    /**
     * The granted voters can vote
     * 4 conditions : 
     *     - only granted voters can do it
     *     - the current workflow must be "VotingSessionStarted"
     *     - a voter must vote only once
     *     - the proposal given by the voter must exist
     *  
     */
    function vote(string memory _proposal) external 
        onlyGrantedVoters(msg.sender) 
        onlyWhenWorkflowStatusIs(WorkflowStatus.VotingSessionStarted) 
        onlyOneVotePerVoter(msg.sender)
        checkValidProposal(_proposal) {

        whiteList[msg.sender].hasVoted = true;
        whiteList[msg.sender].votedProposalId = _getVoteId(_proposal);
        _incrementVotingAndTimestampCount(_proposal);
    }

    /**
     * End recording Vote
     * 3 conditions : 
     *     - only the owner can do it
     *     - the current workflow must be "VotingSessionStarted"
     *     - there must be at least one vote to pick a winner
     */
    function endRecordingVote() external 
        onlyOwner 
        onlyWhenWorkflowStatusIs(WorkflowStatus.VotingSessionStarted) 
        atLeastOneVote {

        _setWorkflowVoteStatus(WorkflowStatus.VotingSessionEnded);
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    /**
     * Count votes
     * 2 conditions : 
     *     - only the owner can do it
     *     - the current workflow must be "VotingSessionEnded"
     */
    function countVotes() external 
        onlyOwner 
        onlyWhenWorkflowStatusIs(WorkflowStatus.VotingSessionEnded) {

        _setWorkflowVoteStatus(WorkflowStatus.VotesTallied);
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);

        _setWinners();
        _setWinner();
    }

    /**
     * Function that sets the potential winners if ex aequo results
     * Loop through array of Proposals
     */
    function _setWinners() private {
        boolWinnerFound = true;
        uint maxCount = 0;
        for (uint index = 0; index < proposals.length; index++) {
            if (proposals[index].voteCount >= maxCount) {
                maxCount = proposals[index].voteCount;
                winners.push(index);       
            }
        }
    }

    /**
     * Function that sets the winner id state variable.
     * It depends on the winners length array. 
     * If length = 1 => No ex aequo. Only 1 winner.
     * If length > 1 => There are many ex aequo winners. 
     * I decided the folowing rule : The winner is the proposal that have the minimum blockTimestampCount.
     * because it means that many voters vote for him until the best vote count before others
     */
    function _setWinner() private {
        if (winners.length == 1) {
            winningProposalId = winners[0];        
        }
        else {
            //I have to find the min blockTimestampCount of proposals
            uint minBlockTimestampCount = 9999999999;
            for (uint256 index = 0; index < winners.length; index++) {
                if (proposals[index].blockTimestampCount < minBlockTimestampCount) {
                    minBlockTimestampCount = proposals[index].blockTimestampCount;
                    winningProposalId = index;
                }
            }
        }
    }    

    /**
     * Function that increment the voting count of a proposal
     */
    function _incrementVotingAndTimestampCount(string memory _proposal) private {
        for (uint index = 0; index < proposals.length; index++) {
            if (_proposal.equals(proposals[index].description)) {
                proposals[index].voteCount++;
                proposals[index].blockTimestampCount += block.timestamp;
                break;
            }
        }
    }

    /**
     * Function that retrieves the index of the proposal in the array of proposals
     */
    function _getVoteId(string memory _proposal) private view returns(uint) {
        uint result;
        for (uint index = 0; index < proposals.length; index++) {
            if (_proposal.equals(proposals[index].description)) {
                result = index;
            }
        }
        return result;
    }

    /**
     * Function Setter that set the new value for the state variable "workflowVoteStatus"
     */
    function _setWorkflowVoteStatus(WorkflowStatus _newStatus) private {
        workflowVoteStatus = _newStatus;
    }

    /**
     * Function that returns true if a proposal already exists
     */
    function _proposalExist(string memory _proposal) private view returns(bool) {
        bool result = false;
        for (uint index = 0; index < proposals.length; index++) {
            if (_proposal.equals(proposals[index].description)) {
                result = true;
                break;
            }
        }
        return result;
    }

    /**
     * Function that returns true if there are at leastone vote
     */
    function _atLeast1Vote() private view returns (bool) {
        uint totalVoteCount;
        for (uint i = 0; i < proposals.length; i++) {
            totalVoteCount += proposals[i].voteCount;
        }
        if (totalVoteCount == 0) {
            return false;
        }
        else {
            return true;
        }

    }

}