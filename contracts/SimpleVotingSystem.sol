// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title SimpleVoting
 * @dev A simple voting system contract that allows creating proposals and voting
 */
contract SimpleVoting {
    struct Proposal {
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    address public owner;
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    
    event ProposalCreated(uint256 indexed proposalId, string description, uint256 endTime);
    event Voted(uint256 indexed proposalId, address indexed voter, bool vote);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Create a new proposal
     * @param _description Description of the proposal
     * @param _durationInMinutes Duration of the voting period in minutes
     * @return proposalId The ID of the newly created proposal
     */
    function createProposal(string memory _description, uint256 _durationInMinutes) public returns (uint256) {
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.description = _description;
        newProposal.endTime = block.timestamp + (_durationInMinutes * 1 minutes);
        newProposal.executed = false;
        
        emit ProposalCreated(proposalId, _description, newProposal.endTime);
        return proposalId;
    }

    /**
     * @dev Cast a vote on a proposal
     * @param _proposalId The ID of the proposal to vote on
     * @param _vote True for yes, false for no
     */
    function vote(uint256 _proposalId, bool _vote) public {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        
        require(block.timestamp < proposal.endTime, "Voting period has ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        
        proposal.hasVoted[msg.sender] = true;
        
        if (_vote) {
            proposal.yesVotes++;
        } else {
            proposal.noVotes++;
        }
        
        emit Voted(_proposalId, msg.sender, _vote);
    }

    /**
     * @dev Execute a proposal after voting period ends
     * @param _proposalId The ID of the proposal to execute
     * @return passed Whether the proposal passed or not
     */
    function executeProposal(uint256 _proposalId) public returns (bool) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        
        require(block.timestamp >= proposal.endTime, "Voting period not yet ended");
        require(!proposal.executed, "Proposal already executed");
        
        proposal.executed = true;
        
        bool passed = proposal.yesVotes > proposal.noVotes;
        
        emit ProposalExecuted(_proposalId, passed);
        
        return passed;
    }

    /**
     * @dev Get the current status of a proposal
     * @param _proposalId The ID of the proposal to check
     * @return description The proposal description
     * @return yesVotes Number of yes votes
     * @return noVotes Number of no votes
     * @return endTime The end time of the voting period
     * @return executed Whether the proposal has been executed
     * @return active Whether the voting period is still active
     */
    function getProposal(uint256 _proposalId) public view returns (
        string memory description,
        uint256 yesVotes,
        uint256 noVotes,
        uint256 endTime,
        bool executed,
        bool active
    ) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        
        return (
            proposal.description,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.endTime,
            proposal.executed,
            block.timestamp < proposal.endTime
        );
    }
}
