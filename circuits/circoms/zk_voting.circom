pragma circom 2.1.8;

include "./merkle_utils.circom";

template ZKVoted(depth) {
    signal input votingSecret;

    // Merkle proof
    signal input proofElements[depth];
    signal input proofIndices[depth];

     // Public inputs
    signal input merkleRoot;
    signal input choice;
    signal input nullifier;

    component merkle = MerkleTreeHelper(depth);

    component leafHash = Poseidon(1);
    leafHash.inputs[0] <== votingSecret;
    merkle.leaf <== leafHash.out;
    
    for (var i = 0; i < depth; i++) {
        merkle.proofElements[i] <== proofElements[i];
        merkle.proofIndices[i] <== proofIndices[i];
    }
    merkle.root === merkleRoot;

    // Nullifier must match the hash of the voting secret
    component nullify = Poseidon(1);
    nullify.inputs[0] <== votingSecret;
    nullifier === nullify.out; 

    // Dummy use of `choice` in constraint to prevent compiler optimization
    // We don't want to prove correctness of choice (i.e., no hash), just bind it
    signal dummy;
    dummy <== choice * 1;
    dummy === choice;
}

// Must match Solidity public signals: [merkleRoot, nullifier, choice]
component main { public [merkleRoot, choice, nullifier] } = ZKVoted(2);