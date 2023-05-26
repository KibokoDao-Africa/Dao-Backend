// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DAO is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public constant MINIMUM_VOTES = 1;
    uint256 public constant PROPOSAL_DURATION = 7 days;
    uint256 public constant VOTING_DURATION = 2 days;
    uint256 public constant MAX_PROPOSALS = 100;
    uint256 public constant MIN_QUORUM_PERCENTAGE = 10;
    uint256 public constant MAX_QUORUM_PERCENTAGE = 80;

    uint256 public totalMembers;
    Proposal[] public proposals;
    mapping(address => bool) public members;

    struct VoterRecord {
        bool hasVoted;
        bool support;
    }

    struct Proposal {
        uint256 id;
        string title;
        string description;
        uint256 votes;
        uint256 deadline;
        address proposer;
        VoterRecord[] voters;
        bool executed;
    }

    event NewMember(address indexed member);
    event MemberLeft(address indexed member);
    event NewProposal(uint256 indexed proposalId, string title);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support);
    // event ProposalExecuted(uint256 indexed proposalId, address indexed executor);

    modifier onlyMember() {
        require(members[msg.sender], "Not a member");
        _;
    }

    function addMember(address _member) public onlyOwner {
        require(_member != address(0), "Invalid member address");
        require(!members[_member], "Already a member");
        members[_member] = true;
        totalMembers++;
        emit NewMember(_member);
    }

    function removeMember(address _member) public onlyOwner {
        require(_member != address(0), "Invalid member address");
        require(members[_member], "Not a member");
        require(totalMembers > 1, "Cannot remove the last member");
        members[_member] = false;
        totalMembers--;
        emit MemberLeft(_member);
    }

    function makeProposal(address _member, string memory _title, string memory _description) public onlyMember {
        require (_member != address(0), "Invalid member address");
        require(proposals.length < MAX_PROPOSALS, "Too many proposals, only 100 allowed");

        Proposal memory proposal;
        proposal.id = proposals.length; // incremental proposal id like an auto incrementing primary key in a database

        while (getProposalById(proposal.id).id != uint256(-1)) {    // if taken increment until we find an empty slot
            proposal.id = proposal.id.add(1);   // this check is important because some proposals might be deleted and the length of the array will be smaller than the last proposal id
        }

        proposal.title = _title;
        proposal.description = _description;
        proposal.votes = 1;
        proposal.deadline = block.timestamp + VOTING_DURATION;
        proposal.proposer = _member;
        proposal.voters.push(VoterRecord({hasVoted: true, support: true})); // the assumption is that the proposer votes for their own proposal
        proposal.executed = false;

        proposals.push(proposal);
        emit NewProposal(proposal.id, proposal.title);
    }

    /// @notice Finds the proposal with the matching ID
    /// @param _proposalId the id to look up
    /// @return proposal the proposal with the matching ID or -1 if not found
    /// @dev Uses binary search/divide and conquer
    function getProposalById(uint256 _proposalId) internal returns (Proposal storage) {
        uint256 left = 0;
        uint256 right = proposals.length.sub(1);

        while (left <= right) {
            uint256 mid = (left.add(right)).div(2);
            if (proposals[mid].id == _proposalId) {
                return proposals[mid]; // Return the proposal with the matching ID
            }
            if (proposals[mid].id < _proposalId) {
                left = mid.add(1);
            } else {
                right = mid.sub(1);
            }
        }

        // Return an empty proposal of -1 if the ID is not found
        Proposal emptyProposal;
        emptyProposal.id = uint256(-1);
        return emptyProposal;
    }

    function voteProposal(uint256 _proposalId, bool _support) public onlyMember {
        require(_proposalId < proposals.length, "Invalid proposal id");
        Proposal storage proposal = getProposalById(_proposalId);
        require(proposal.id != uint256(-1), "Proposal not found");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.voters[msg.sender].hasVoted, "Already voted for this proposal");
        require(proposal.deadline > block.timestamp, "Proposal voting period expired");

        proposal.voters[msg.sender].hasVoted = true;
        proposal.voters[msg.sender].support = _support;
        proposal.votes = _support ? proposal.votes.add(1) : proposal.votes.sub(1);
        emit Voted(_proposalId, msg.sender, _support);
    }
}