// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title SimpleVoting
 * @dev Voting system with proposals, voting, delegation, quorum, pause, and ownership controls.
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

    // Voting weights per address (default 1)
    mapping(address => uint256) public votingWeights;

    // Delegation mapping: voter => delegate
    mapping(address => address) public delegation;

    // Minimum votes required for quorum (yes + no)
    uint256 public quorum;

    // Proposals storage
    mapping(uint256 => Proposal) private proposals;

    // Events
    event ProposalCreated(uint256 indexed proposalId, string description, uint256 endTime);
    event Voted(uint256 indexed proposalId, address indexed voter, bool vote, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);
    event ProposalCanceled(uint256 indexed proposalId);
    event VotingExtended(uint256 indexed proposalId, uint256 newEndTime);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused();
    event Unpaused();
    event Delegated(address indexed voter, address indexed delegate);
    event DelegationRevoked(address indexed voter);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor(uint256 _quorum) {
        owner = msg.sender;
        quorum = _quorum;
    }

    // ========== Voting Configuration ==========

    function setVotingWeight(address _voter, uint256 _weight) public onlyOwner {
        require(_voter != address(0), "Zero address");
        votingWeights[_voter] = _weight;
    }

    function delegateVote(address _delegate) public whenNotPaused {
        require(_delegate != address(0), "Delegate is zero address");
        require(_delegate != msg.sender, "Cannot delegate to self");
        require(delegation[msg.sender] == address(0), "Already delegated");

        delegation[msg.sender] = _delegate;
        emit Delegated(msg.sender, _delegate);
    }

    function revokeDelegation() public whenNotPaused {
        require(delegation[msg.sender] != address(0), "No delegation found");
        delegation[msg.sender] = address(0);
        emit DelegationRevoked(msg.sender);
    }

    // ========== Proposal Management ==========

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

    function vote(uint256 _proposalId, bool _vote) public whenNotPaused {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];

        require(!proposal.canceled, "Proposal canceled");
        require(block.timestamp < proposal.endTime, "Voting period ended");

        address actualVoter = _getActualVoter(msg.sender);
        require(!proposal.hasVoted[actualVoter], "Already voted");

        proposal.hasVoted[actualVoter] = true;
        proposal.votersCount++;

        uint256 weight = votingWeights[actualVoter];
        if (weight == 0) weight = 1;

        if (_vote) {
            proposal.yesVotes += weight;
        } else {
            proposal.noVotes += weight;
        }

        emit Voted(_proposalId, actualVoter, _vote, weight);
    }

    function executeProposal(uint256 _proposalId) public whenNotPaused returns (bool) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];

        require(!proposal.canceled, "Proposal canceled");
        require(block.timestamp >= proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Already executed");

        require(proposal.yesVotes + proposal.noVotes >= quorum, "Quorum not met");

        proposal.executed = true;
        bool passed = proposal.yesVotes > proposal.noVotes;

        emit ProposalExecuted(_proposalId, passed);
        return passed;
    }

    function cancelProposal(uint256 _proposalId) public onlyOwner {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];

        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Already canceled");
        require(block.timestamp < proposal.endTime, "Voting period ended");

        proposal.canceled = true;
        emit ProposalCanceled(_proposalId);
    }

    function extendVotingPeriod(uint256 _proposalId, uint256 _extraMinutes) public onlyOwner {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];

        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Canceled");
        require(block.timestamp < proposal.endTime, "Voting period ended");

        proposal.endTime += (_extraMinutes * 1 minutes);
        emit VotingExtended(_proposalId, proposal.endTime);
    }

    // ========== Views ==========

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
        Proposal storage p = proposals[_proposalId];

        return (
            p.description,
            p.yesVotes,
            p.noVotes,
            p.endTime,
            p.executed,
            !p.executed && !p.canceled && (block.timestamp < p.endTime),
            p.canceled,
            p.votersCount
        );
    }

    function hasUserVoted(uint256 _proposalId, address _voter) public view returns (bool) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        address actualVoter = _getActualVoter(_voter);
        return proposals[_proposalId].hasVoted[actualVoter];
    }

    function getVoteCounts(uint256 _proposalId) public view returns (uint256 yes, uint256 no) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage p = proposals[_proposalId];
        return (p.yesVotes, p.noVotes);
    }

    function getTimeLeft(uint256 _proposalId) public view returns (uint256) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage p = proposals[_proposalId];
        if (block.timestamp >= p.endTime) return 0;
        return p.endTime - block.timestamp;
    }

    function didProposalPass(uint256 _proposalId) public view returns (bool) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage p = proposals[_proposalId];
        require(p.executed, "Proposal not executed");
        return p.yesVotes > p.noVotes;
    }

    function getAllProposalIds() public view returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](proposalCount);
        for (uint256 i = 0; i < proposalCount; i++) {
            ids[i] = i + 1;
        }
        return ids;
    }

    function getProposalDescription(uint256 _proposalId) public view returns (string memory) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        return proposals[_proposalId].description;
    }

    // ========== Admin Functions ==========

    function changeOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function pause() public onlyOwner {
        paused = true;
        emit Paused();
    }

    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused();
    }

    // ========== Internal Delegation Logic ==========

    function _getActualVoter(address _voter) internal view returns (address) {
        address current = _voter;
        for (uint256 i = 0; i < 10; i++) {
            address next = delegation[current];
            if (next == address(0)) break;
            current = next;
        }
        return current;
    }
}
