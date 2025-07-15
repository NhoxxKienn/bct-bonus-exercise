pragma circom 2.1.8;

include "./merkle_utils.circom";

template ZKVoted(depth) {
    signal input votingSecret;

    // Merkle proof
    signal input proofElements[depth];
    signal input proofIndices[depth];

    // Public input: Merkle root
    signal input merkleRoot;

    component merkle = MerkleTreeHelper(depth);
    merkle.leaf <== votingSecret;
    
    for (var i = 0; i < depth; i++) {
        merkle.proofElements[i] <== proofElements[i];
        merkle.proofIndices[i] <== proofIndices[i];
    }

    merkle.root === merkleRoot;
}

component main {public [merkleRoot]} = ZKVoted(2);