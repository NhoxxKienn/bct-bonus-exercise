// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./zk_verifier.sol"; // Import the generated verifier from your circuit

contract ZKVoting {
    Groth16Verifier public immutable verifier;
    
    uint256 public immutable merkleRoot;
    
    mapping(uint8 => uint256) public voteCounts;

    uint256 public totalVotes;
    

    event VoteCast(uint8 indexed choice, uint256 timestamp);
    event ElectionResult(uint8 winner, uint256 voteCount);
    
    /**
     * @param _verifierAddress Address of the deployed verifier contract
     * @param _merkleRoot The root of the Merkle tree containing all valid voting commitments
     */
    constructor(address _verifierAddress, uint256 _merkleRoot) {
        require(_verifierAddress != address(0), "Invalid verifier address");
        require(_merkleRoot != 0, "Invalid Merkle root");
        
        verifier = Groth16Verifier(_verifierAddress);
        merkleRoot = _merkleRoot;
    }
    
    /**
     * @dev Cast a vote with ZK proof verification
     * @param choice The vote choice (8-bit integer)
     * @param proof The Groth16 proof array (8 elements for a, b, c points)
     * @param publicSignals The public signals array
     */
    function vote(
        uint8 choice,
        uint256[8] calldata proof,
        uint256[3] calldata publicSignals
    ) external returns (bool) {
        require(publicSignals[0] == merkleRoot, "Merkle root mismatch");
        
        uint256[2] memory a = [proof[0], proof[1]];
        uint256[2][2] memory b = [[proof[2], proof[3]], [proof[4], proof[5]]];
        uint256[2] memory c = [proof[6], proof[7]];
        
        // verify proof using generated verifier
        bool isValidProof = verifier.verifyProof(a, b, c, publicSignals);
        require(isValidProof, "Invalid ZK proof");
        
        // register vote
        voteCounts[choice] += 1;
        totalVotes += 1;
        
        emit VoteCast(choice, block.timestamp);
        
        return true;
    }
    
    /**
     * @dev Query the election winner
     * @return winner The choice with the most votes
     * @return winningVoteCount The number of votes the winner received
     */
    function getWinner() external view returns (uint8 winner, uint256 winningVoteCount) {
        require(totalVotes > 0, "No votes cast yet");
        
        uint256 highestVoteCount = 0;
        uint8 winningChoice = 0;
        
        // Iterate through all possible 8-bit values to find the winner
        for (uint16 i = 0; i <= 255; i++) {
            uint8 choice = uint8(i);
            if (voteCounts[choice] > highestVoteCount) {
                highestVoteCount = voteCounts[choice];
                winningChoice = choice;
            }
        }
        
        return (winningChoice, highestVoteCount);
    }
}