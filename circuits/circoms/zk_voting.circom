pragma circom 2.1.8;

include "./merkle_utils.circom";

template ZKVoted(depth) {
    // Add private inputs...
    signal input votingSecret;
    signal input proofIndices[depth];
    signal input proofElements[depth];

    // Add public inputs...
    signal input merkleRoot;

    component hashLeaf = Poseidon(1);
    hashLeaf.inputs[0] <== votingSecret;

    component merkleProof = MerkleTreeHelper(depth);
    merkleProof.leaf <== hashLeaf.out;

    for (var i = 0; i < depth; i++) {
        merkleProof.proofIndices[i] <== proofIndices[i];
        merkleProof.proofElements[i] <== proofElements[i];
    }

    // Check that computed root matches the public root
    merkleProof.root === merkleRoot;
}

component main { public [merkleRoot] } = ZKVoted(3);