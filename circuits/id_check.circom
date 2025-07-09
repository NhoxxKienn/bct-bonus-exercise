pragma circom 2.1.8;

include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";

// IDHasher: computes a hash of the zkID using a constant tag.
template IDHasher() {
    // This template hashes the zkID.
    signal input id;
    signal output hash;

    // Constant tag for the zkID.
    var ZKID = 1514883396;

    component hasher = Poseidon(2);
    hasher.inputs[0] <== id;
    hasher.inputs[1] <== ZKID;
    hash <== hasher.out;
}

template IDCheck(n) {
    // Private inputs.
    signal input age;
    signal input id;
    signal input nationality;

    // Public inputs.
    signal input zkID;
    signal input allowedNationalities[n];

    // a. Check if the user is an adult (age > 18).
    component isAdult = GreaterThan(8);
    isAdult.in[0] <== age;
    isAdult.in[1] <== 18;

    1 === isAdult.out;

    // b. Compute and check zkID.
    component idHasher = IDHasher();
    idHasher.id <== id;
    idHasher.hash === zkID;

    // c. Verify nationality.
    component eq[n];
    signal isAllowed[n];
    signal partialSum[n+1];

    partialSum[0] <== 0;
    for (var i = 0; i < n; i++) {
        eq[i] = IsEqual();
        eq[i].in[0] <== nationality;
        eq[i].in[1] <== allowedNationalities[i];
        isAllowed[i] <== eq[i].out;

        partialSum[i+1] <== partialSum[i] + isAllowed[i];
    }

    partialSum[n] === 1;
}

// Define signals as public as required.
component main { public [zkID, allowedNationalities] } = IDCheck(5);