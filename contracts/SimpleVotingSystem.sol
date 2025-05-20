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
    mapping(uint256 => Proposal) private proposals;

    event ProposalCreated(uint256 indexed proposalId, string description, uint256 endTime);
    event Voted(uint256 indexed proposalId, address indexed voter, bool vote);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Create a new proposal
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

    /**
     * @dev Check if a user has voted on a proposal
     */
    function hasUserVoted(uint256 _proposalId, address _voter) public view returns (bool) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];
        return proposal.hasVoted[_voter];
    }

    /**
     * @dev Get only the vote counts of a proposal
     */
    function getVoteCounts(uint256 _proposalId) public view returns (uint256 yes, uint256 no) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];
        return (proposal.yesVotes, proposal.noVotes);
    }

    /**
     * @dev Get time left in seconds for voting to end
     */
    function getTimeLeft(uint256 _proposalId) public view returns (uint256) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];
        if (block.timestamp >= proposal.endTime) {
            return 0;
        }
        return proposal.endTime - block.timestamp;
    }

    /**
     * @dev Get if a proposal passed or not (after execution)
     */
    function didProposalPass(uint256 _proposalId) public view returns (bool) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.executed, "Proposal not yet executed");
        return proposal.yesVotes > proposal.noVotes;
    }
}
