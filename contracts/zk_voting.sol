pragma solidity ^0.8.4;

import "./zk_verifier.sol"; // Import your generated verifier

contract zk_Voting {
    Groth16Verifier public verifier;

    uint256 public merkleRoot;
    // choice => vote count
    mapping(uint8 => uint256) public votes;

    // nullifierHash => used
    mapping(uint256 => bool) public nullifiers;

    constructor(address _verifierAddress, uint256 _root) {
        verifier = Groth16Verifier(_verifierAddress);
        merkleRoot = _root;
    }

    function vote(
        uint8 choice,
        uint256[24] calldata _proof,
        uint256[3] calldata _pubSignals
    ) public returns (bool) {
        // Unpack public signals
        uint256 submittedRoot = _pubSignals[0];
        uint256 submittedChoice = _pubSignals[1];
        uint256 nullifierHash = _pubSignals[2];

        require(submittedRoot == merkleRoot, "Merkle root mismatch");
        require(submittedChoice == choice, "Vote binding mismatch");
        require(!nullifiers[nullifierHash], "Double voting detected");

        bool valid = verifier.verifyProof(
            [_proof[0], _proof[1]],
            [[_proof[2], _proof[3]], [_proof[4], _proof[5]]],
            [_proof[6], _proof[7]],
            _pubSignals
        );
        require(valid, "Invalid proof");

        votes[choice] += 1;
        nullifiers[nullifierHash] = true;

        return true;
    }

    function getWinner() public view returns (uint8) {
        uint8 winner = 0;
        uint256 highest = 0;

        for (uint8 i = 0; i < 256; i++) {
            if (votes[i] > highest) {
                highest = votes[i];
                winner = i;
            }
        }

        return winner;
    }
}
