pragma circom 2.1.8;

include "../circomlib/circuits/poseidon.circom";

template MerkleTreeHelper(DEPTH) {
    signal input leaf;
    signal input proofIndices[DEPTH];
    signal input proofElements[DEPTH];
    signal output root;

    signal hashChain[DEPTH + 1];
    hashChain[0] <== leaf;

    signal left[DEPTH];
    signal left_temp[DEPTH];
    signal right[DEPTH];
    signal right_temp[DEPTH];
    component hashers[DEPTH];

    for (var i = 0; i < DEPTH; i++) {
        proofIndices[i] * (proofIndices[i] - 1) === 0;

        right_temp[i]  <== hashChain[i] * (1 - proofIndices[i]); 
        right[i] <== right_temp[i] + (proofElements[i] * proofIndices[i]);

        left_temp[i] <== proofElements[i] * (1 - proofIndices[i]);
        left[i] <== left_temp[i] + (hashChain[i] * proofIndices[i]);

        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== left[i];
        hashers[i].inputs[1] <== right[i];

        hashChain[i + 1] <== hashers[i].out;
    }

    root <== hashChain[DEPTH];
}
