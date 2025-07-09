pragma circom 2.1.8;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";

template MerkleTreeHelper(DEPTH) {
    signal input leaf;
    signal input proofIndices[DEPTH]; // Indices of the proof elements in the Merkle tree proof path.
    signal input proofElements[DEPTH];

    signal output root;

    signal currentHash[DEPTH + 1];
    signal leftTmp1[DEPTH];
    signal leftTmp2[DEPTH];
    signal rightTmp1[DEPTH];
    signal rightTmp2[DEPTH];
    signal nidx[DEPTH];
    signal left[DEPTH];
    signal right[DEPTH];
    component isRight[DEPTH];
    component hash[DEPTH];

    currentHash[0] <== leaf;

    for (var i = 0; i < DEPTH; i++) {
        isRight[i] = IsEqual();
        isRight[i].in[0] <== proofIndices[i];
        isRight[i].in[1] <== 1;
       
        leftTmp1[i] <== currentHash[i] * (1 - isRight[i].out); 
        leftTmp2[i] <== proofElements[i] * isRight[i].out;
        rightTmp1[i] <== proofElements[i] * (1 - isRight[i].out);
        rightTmp2[i] <== currentHash[i] * isRight[i].out;
        left[i] <== leftTmp1[i] + leftTmp2[i];
        right[i] <== rightTmp1[i] + rightTmp2[i];

        hash[i] = Poseidon(2);
        hash[i].inputs[0] <== left[i];
        hash[i].inputs[1] <== right[i];

        currentHash[i+1] <== hash[i].out;
    }

    root <== currentHash[DEPTH];
}