// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";

/**
 * Library that enables me to handle string type
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

/**
 * Voting contract
 */
contract Voting is Ownable {

    using StringLibrary for string;

    //------ STATE VARIABLES ------------------
    uint winningProposalId;
    mapping(address => Voter) public whiteList;
    address[] private _voters; //Array of voters that are in the white list
    uint[] public _winners; //Array to handle ex aequo winners
    Proposal[] private _proposals;
    WorkflowStatus public _workflowVoteStatus;
    bool boolWinnerFound;

    //------ STRUCT ----------------------
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
        string voterName;
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

    //------ EVENTS ----------------------
    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    //---------------------------------------
    //------ MODIFIERS ----------------------
    //---------------------------------------
    /**
     * Modifier that increment the workflow vote status
     */
    modifier nextWorkflowStatus() {
        _;
        incrementStepWorkflow();
        emit WorkflowStatusChange(getPreviousWorkflowStatus(), _workflowVoteStatus);
    }

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
     * Modifier that requires a mandatory voter name
     */
    modifier voterNameMandatory(string memory _voterName) {
        require(!_voterName.equals(""), "The voter name is mandatory!");
        _;
    }

    /**
     * Modifier that indicates if the workflow has the same value than the one given in parameter
     */
    modifier onlyWhenWorkflowStatusIs(WorkflowStatus _status) {
        require(_workflowVoteStatus == _status, "You are not granted to do this due to bad workflow status!");
        _;
    }

    /**
     * Modifier that reverts the transaction if there are no proposal in the transaction
     */
    modifier proposalMandatory(string memory _proposal)
    {
        require(!_proposal.equals(""), "The proposal is mandatory!");
        _;
    }

    /**
     * Modifier that reverts the transaction if there are no proposal when the owner close the proposal recording
     */
    modifier atLeastOneProposal()
    {
        require(_proposals.length > 0, "There must be at least one proposal");
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
     * Modifier that indicates if the given proposal exists
     */
    modifier checkProposalExists(string memory _proposal)
    {
        require(_workflowVoteStatus == WorkflowStatus.ProposalsRegistrationStarted);
        _;
    }

    /**
     * Modifier : The voter must vote only once
     */
    modifier onlyOneVotePerVoter(address _voterAddr)
    {
        require(whiteList[_voterAddr].hasVoted == false, "You already voted and can vote only once!");
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
        return _voters;
    }

    /**
     * Function getter to retrieve the array of proposals
     */
    function getProposals() external view returns (Proposal[] memory) {
        return _proposals;
    }

    /**
     * Get the proposal id by name
     */
    function getProposalId(string memory _proposal) private view returns (uint) {
        uint proposalId;
        for (uint index = 0; index < _proposals.length; index++) {
            if(_proposal.equals(_proposals[index].description)) {
                proposalId = index;
                break;
            }
        }
        return proposalId;
    }

    /**
     * Get the winner
     */
    function getWinner() public view winnerFound returns (uint) {
        return winningProposalId;
    }

    /**
     * Get the previous workflow status
     */
    function getPreviousWorkflowStatus() internal view returns (WorkflowStatus) {
        return WorkflowStatus(uint(_workflowVoteStatus) - 1);
    }

    /**
     * Get details of the proposal winner
     */
    function getProposalWinner() external view winnerFound returns (Proposal memory) {
        uint idWinner = getWinner(); 
        Proposal memory p = Proposal ({
            description:_proposals[idWinner].description, 
            voteCount:_proposals[idWinner].voteCount, 
            blockTimestampCount:_proposals[idWinner].blockTimestampCount});
        return p;
    }

    /**
     * Set the state variable of the workflow status to next step
     */
    function incrementStepWorkflow() internal {
        _workflowVoteStatus = WorkflowStatus(uint(_workflowVoteStatus) + 1);
    }

    /**
     * The admin can vote as well, so he must be added in the white list
     */
    function _addAdminInWhiteList() private {
        whiteList[owner()] = Voter({isRegistered:true, hasVoted:false, votedProposalId:0, voterName:'Gilles Bruno'});
        _voters.push(owner());
    }

    /**
     * Add a voter in the whiteList
     *    3 conditions : 
     *       - Only owner can do it
     *       - Impossible to have duplicate voter in the whitelist
     *       - The name of the voter is mandatory
     */
    function addVoterIndWhiteList(address _voterAddr, string memory _voterName) external 
        onlyOwner 
        checkDuplicateVoter(_voterAddr) 
        voterNameMandatory(_voterName) {
        //The first time this function is called, the admin is added to the white list 
        // and the worflow status becomes 'RegisteringVoters'
        if (_voters.length == 0) {
            _addAdminInWhiteList();
            _setWorkflowVoteStatus(WorkflowStatus.RegisteringVoters);
        }
        require(_workflowVoteStatus == WorkflowStatus.RegisteringVoters, "You are not granted to add voter in the white list due to bad workflow status");
        whiteList[_voterAddr] = Voter({isRegistered:true, hasVoted:false, votedProposalId:0, voterName:_voterName});
        _voters.push(_voterAddr);
        emit VoterRegistered(_voterAddr);
    }

    /**
     * Start recording proposals of voters
     *    2 conditions : 
     *       - Only owner can do it
     *       - the current workflow must be "RegisteringVoters" or 
     */
    function startRecordingSessionProposal() external 
        onlyOwner 
        onlyWhenWorkflowStatusIs(WorkflowStatus.RegisteringVoters) 
        nextWorkflowStatus {

    }

    /**
     * Granted voters give their proposals
     *    4 conditions : 
     *       - Only Granted voters can do it
     *       - the current workflow must be "ProposalsRegistrationStarted"
     *       - A proposal must be unique so exist the function when a proposal already exists
     *       - A proposal is mandatory
     */
    function votersPushProposals(string memory _proposal) external 
        onlyGrantedVoters(msg.sender) 
        onlyWhenWorkflowStatusIs(WorkflowStatus.ProposalsRegistrationStarted)
        checkDuplicateProposal(_proposal)
        proposalMandatory(_proposal) {

            _proposals.push(Proposal({description:_proposal, voteCount:0, blockTimestampCount:0}));
            emit ProposalRegistered(_proposals.length-1);
    }

    /**
     * End recording proposals of voters. 
     * 3 conditions : 
     *     - only the owner can do it
     *     - the current workflow must be "ProposalsRegistrationStarted"
     *     - There must be at least 1 proposal otherwise it's impossible to vote
     */
    function endRecordingSessionProposal() external 
        onlyOwner 
        onlyWhenWorkflowStatusIs(WorkflowStatus.ProposalsRegistrationStarted)
        atLeastOneProposal 
        nextWorkflowStatus {

    }

    /**
     * Start recording Vote
     * 2 conditions : 
     *     - only the owner can do it
     *     - the current workflow must be "ProposalsRegistrationEnded"
     */
    function startRecordingVote() external 
        onlyOwner 
        onlyWhenWorkflowStatusIs(WorkflowStatus.ProposalsRegistrationEnded) 
        nextWorkflowStatus {

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

        emit Voted (msg.sender, getProposalId(_proposal));
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
        atLeastOneVote 
        nextWorkflowStatus {

    }

    /**
     * Count votes
     * 2 conditions : 
     *     - only the owner can do it
     *     - the current workflow must be "VotingSessionEnded"
     */
    function countVotes() external 
        onlyOwner 
        onlyWhenWorkflowStatusIs(WorkflowStatus.VotingSessionEnded) 
        nextWorkflowStatus {

        _setWinners();
        _setWinner();
    }

    /**
     * Function that sets the potential winners if ex aequo results
     * Loop through array of Proposals
     */
    function _setWinners() private {
        boolWinnerFound = true;
        uint maxCount;
        //1) Loop through the proposals to get the higher score
        for (uint index = 0; index < _proposals.length; index++) {
            if (_proposals[index].voteCount > maxCount) {
                maxCount = _proposals[index].voteCount;
            }
        }

        //2) Loop through the proposals again to build an array of ex aequo winners
        for (uint i = 0; i < _proposals.length; i++) {
            if (_proposals[i].voteCount == maxCount) {
                _winners.push(i);
            }
        }
    }

    /**
     * Function that sets the winner id state variable.
     * It depends on the winners length array. 
     * If length = 1 => No ex aequo. Only 1 winner.
     * If length > 1 => There are many ex aequo winners. 
     * I decided the folowing rule : The winner is the proposal that have the minimum blockTimestampCount.
     * because it means that the proposal reached the best score before others proposals
     */
    function _setWinner() private {
        if (_winners.length == 1) {
            winningProposalId = _winners[0];        
        }
        else {
            //I have to find the min blockTimestampCount of proposals
            uint minBlockTimestampCount = 9999999999;
            for (uint256 index = 0; index < _winners.length; index++) {
                uint proposalIndex = _winners[index];
                if (_proposals[proposalIndex].blockTimestampCount < minBlockTimestampCount) {
                    minBlockTimestampCount = _proposals[proposalIndex].blockTimestampCount;
                    winningProposalId = proposalIndex;
                }
            }
        }
    }    

    /**
     * Function that increment the voting count of a proposal
     */
    function _incrementVotingAndTimestampCount(string memory _proposal) private {
        for (uint index = 0; index < _proposals.length; index++) {
            if (_proposal.equals(_proposals[index].description)) {
                _proposals[index].voteCount++;
                _proposals[index].blockTimestampCount += block.timestamp;
                break;
            }
        }
    }

    /**
     * Function that retrieves the index of the proposal in the array of proposals
     */
    function _getVoteId(string memory _proposal) private view returns(uint) {
        uint result;
        for (uint index = 0; index < _proposals.length; index++) {
            if (_proposal.equals(_proposals[index].description)) {
                result = index;
            }
        }
        return result;
    }

    /**
     * Function Setter that set the new value for the state variable "workflowVoteStatus"
     */
    function _setWorkflowVoteStatus(WorkflowStatus _newStatus) private {
        _workflowVoteStatus = _newStatus;
    }

    /**
     * Function that returns true if a proposal already exists
     */
    function _proposalExist(string memory _proposal) private view returns(bool) {
        bool result = false;
        for (uint index = 0; index < _proposals.length; index++) {
            if (_proposal.equals(_proposals[index].description)) {
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
        for (uint i = 0; i < _proposals.length; i++) {
            totalVoteCount += _proposals[i].voteCount;
        }
        if (totalVoteCount == 0) {
            return false;
        }
        else {
            return true;
        }
    }

}