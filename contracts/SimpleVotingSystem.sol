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
        bool canceled;
        uint256 votersCount;
        mapping(address => bool) hasVoted;
    }

    address public owner;
    uint256 public proposalCount;
    bool public paused;

    mapping(uint256 => Proposal) private proposals;

    event ProposalCreated(uint256 indexed proposalId, string description, uint256 endTime);
    event Voted(uint256 indexed proposalId, address indexed voter, bool vote);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);
    event ProposalCanceled(uint256 indexed proposalId);
    event VotingExtended(uint256 indexed proposalId, uint256 newEndTime);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused();
    event Unpaused();

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Create a new proposal
     */
    function createProposal(string memory _description, uint256 _durationInMinutes) public onlyOwner returns (uint256) {
        require(!paused, "Contract is paused");
        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.description = _description;
        newProposal.endTime = block.timestamp + (_durationInMinutes * 1 minutes);
        newProposal.executed = false;
        newProposal.canceled = false;
        newProposal.votersCount = 0;

        emit ProposalCreated(proposalId, _description, newProposal.endTime);
        return proposalId;
    }

    /**
     * @dev Cast a vote on a proposal
     */
    function vote(uint256 _proposalId, bool _vote) public whenNotPaused {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];

        require(!proposal.canceled, "Proposal canceled");
        require(block.timestamp < proposal.endTime, "Voting period has ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        proposal.hasVoted[msg.sender] = true;
        proposal.votersCount++;

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
    function executeProposal(uint256 _proposalId) public whenNotPaused returns (bool) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];

        require(!proposal.canceled, "Proposal canceled");
        require(block.timestamp >= proposal.endTime, "Voting period not yet ended");
        require(!proposal.executed, "Proposal already executed");

        proposal.executed = true;

        bool passed = proposal.yesVotes > proposal.noVotes;

        emit ProposalExecuted(_proposalId, passed);

        return passed;
    }

    /**
     * @dev Cancel a proposal before it is executed
     */
    function cancelProposal(uint256 _proposalId) public onlyOwner {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Already canceled");
        require(block.timestamp < proposal.endTime, "Voting period ended");

        proposal.canceled = true;

        emit ProposalCanceled(_proposalId);
    }

    /**
     * @dev Extend voting period for a proposal before it ends
     */
    function extendVotingPeriod(uint256 _proposalId, uint256 _extraMinutes) public onlyOwner {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Canceled");
        require(block.timestamp < proposal.endTime, "Voting period ended");

        proposal.endTime += (_extraMinutes * 1 minutes);

        emit VotingExtended(_proposalId, proposal.endTime);
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
        bool active,
        bool canceled,
        uint256 votersCount
    ) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];

        return (
            proposal.description,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.endTime,
            proposal.executed,
            !proposal.executed && !proposal.canceled && (block.timestamp < proposal.endTime),
            proposal.canceled,
            proposal.votersCount
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

    /**
     * @dev Get all proposal IDs (for enumeration)
     */
    function getAllProposalIds() public view returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](proposalCount);
        for (uint256 i = 0; i < proposalCount; i++) {
            ids[i] = i + 1;
        }
        return ids;
    }

    /**
     * @dev Get proposal description only
     */
    function getProposalDescription(uint256 _proposalId) public view returns (string memory) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        return proposals[_proposalId].description;
    }

    /**
     * @dev Transfer ownership to new owner
     */
    function changeOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Pause the contract
     */
    function pause() public onlyOwner {
        paused = true;
        emit Paused();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused();
    }

    /**
     * @dev Withdraw any ETH sent to contract (should never hold ETH, but just in case)
     */
    function withdrawEther() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ether to withdraw");
        payable(owner).transfer(balance);
    }
}
