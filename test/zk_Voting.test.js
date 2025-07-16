const { expect } = require("chai");
const { ethers } = require("hardhat");
const snarkjs = require("snarkjs");
const fs = require("fs");
const path = require("path");
const circomlib = require("circomlibjs");

async function buildMerkleTree(leaves) {
    const poseidon = await circomlib.buildPoseidon();
    const poseidonHash = (l, r) => poseidon.F.toObject(poseidon([l, r]));

    const n = leaves.length;
    const nextPow2 = 1 << Math.ceil(Math.log2(n));
    while (leaves.length < nextPow2) leaves.push(poseidon.F.toObject(poseidon([0n])));

    let level = leaves;
    const tree = [level];

    while (level.length > 1) {
        const nextLevel = [];
        for (let i = 0; i < level.length; i += 2) {
            const left = level[i];
            const right = level[i + 1];
            nextLevel.push(poseidonHash(left, right));
        }
        tree.push(nextLevel);
        level = nextLevel;
    }

    return { tree, root: tree[tree.length - 1][0] };
}

function getMerkleProof(tree, leafIndex) {
    const proofElements = [];
    const proofIndices = [];

    for (let level = 0; level < tree.length - 1; level++) {
        const levelNodes = tree[level];
        const isRightNode = leafIndex % 2;
        const siblingIndex = isRightNode ? leafIndex - 1 : leafIndex + 1;

        proofElements.push(levelNodes[siblingIndex] || BigInt(0));
        proofIndices.push(isRightNode);

        leafIndex = Math.floor(leafIndex / 2);
    }

    return { proofElements, proofIndices };
}

describe("zk_Voting", function () {
    let verifierContract;
    let votingContract;
    let owner;

    // Raw secrets (as inputs to the circuit)
    const votingSecrets = [123n, 456n, 789n, 101n];

    let merkleRoot;

    beforeEach(async () => {
        [owner] = await ethers.getSigners();

        const poseidon = await circomlib.buildPoseidon();

        // Hash secrets before putting into the Merkle tree
        const leafHashes = votingSecrets.map(secret => poseidon.F.toObject(poseidon([secret])));
        const { tree, root } = await buildMerkleTree(leafHashes);
        merkleRoot = root;

        const Verifier = await ethers.getContractFactory("Groth16Verifier");
        verifierContract = await Verifier.deploy();

        const Voting = await ethers.getContractFactory("zk_Voting");
        votingContract = await Voting.deploy(verifierContract.getAddress(), merkleRoot.toString());
    });

    it("should initialize with correct merkle root", async () => {
        expect((await votingContract.merkleRoot()).toString()).to.equal(merkleRoot.toString());
    });

    it("should accept a valid vote proof", async function () {
        this.timeout(120000); // Long timeout for proof gen

        const poseidon = await circomlib.buildPoseidon();
        const F = poseidon.F;

        // Use secrets and hash them for Merkle leaves
        const votingSecrets = [123n, 456n, 789n, 101n];
        const leaves = votingSecrets.map(s => F.toObject(poseidon([s])));
        const { tree, root } = await buildMerkleTree([...leaves]); // Clone

        // === Pick voter
        const voterIndex = 0;
        const votingSecret = votingSecrets[voterIndex];

        // === Build Merkle proof for this voter
        const { proofElements, proofIndices } = getMerkleProof(tree, voterIndex);

        // === Compute nullifier = Poseidon([votingSecret])
        const nullifier = F.toObject(poseidon([votingSecret]));

        // === Input for the circuit
        const input = {
            votingSecret: votingSecret.toString(),
            proofElements: proofElements.map(x => x.toString()),
            proofIndices: proofIndices,
            merkleRoot: root.toString(),
            choice: "1",
            nullifier: nullifier.toString(),
        };

        console.log("Test Input:", input);

        // === Generate proof
        const { proof, publicSignals } = await snarkjs.groth16.fullProve(
            input,
            path.join(__dirname, "../circuits/circoms/zk_voting_js/zk_voting.wasm"),
            path.join(__dirname, "../circuits/circoms/zk_voting_final.zkey")
        );

        console.log("Public signals:", publicSignals);

        // === Prepare call data for Solidity
        const callData = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);

        const argv = callData.replace(/["[\]\s]/g, "").split(",");


        // Extract 8 proof elements
        const proofPartial = argv.slice(0, 8).map(x => BigInt(x));

        // Pad to 24 elements with zeros
        const proofFull = proofPartial.concat(Array(24 - proofPartial.length).fill(BigInt(0)));

        // Extract 3 public signals
        const pubSignals = argv.slice(8, 11).map(x => BigInt(x));

        // Vote choice from your code 
        const choice = 1;

        // Call the vote function
        await votingContract.vote(choice, proofFull, pubSignals);

        expect(await votingContract.votes(1)).to.equal(1);
    });

    it("should reject double voting with the same nullifier", async function () {
        this.timeout(120000); // Long timeout for proof gen

        const poseidon = await circomlib.buildPoseidon();
        const F = poseidon.F;

        // Use secrets and hash them for Merkle leaves
        const votingSecrets = [123n, 456n, 789n, 101n];
        const leaves = votingSecrets.map(s => F.toObject(poseidon([s])));
        const { tree, root } = await buildMerkleTree([...leaves]); // Clone

        // === Pick voter
        const voterIndex = 0;
        const votingSecret = votingSecrets[voterIndex];

        // === Build Merkle proof for this voter
        const { proofElements, proofIndices } = getMerkleProof(tree, voterIndex);

        // === Compute nullifier = Poseidon([votingSecret])
        const nullifier = F.toObject(poseidon([votingSecret]));

        // === Input for the circuit
        const input = {
            votingSecret: votingSecret.toString(),
            proofElements: proofElements.map(x => x.toString()),
            proofIndices: proofIndices,
            merkleRoot: root.toString(),
            choice: "1",
            nullifier: nullifier.toString(),
        };

        // === Generate proof
        const { proof, publicSignals } = await snarkjs.groth16.fullProve(
            input,
            path.join(__dirname, "../circuits/circoms/zk_voting_js/zk_voting.wasm"),
            path.join(__dirname, "../circuits/circoms/zk_voting_final.zkey")
        );

        // Prepare calldata string
        const callData = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
        const argv = callData.replace(/["[\]\s]/g, "").split(",");

        // Extract 8 proof elements
        const proofPartial = argv.slice(0, 8).map(x => BigInt(x));

        // Pad to 24 elements with zeros
        const proofFull = proofPartial.concat(Array(24 - proofPartial.length).fill(BigInt(0)));

        // Extract 3 public signals
        const pubSignals = argv.slice(8, 11).map(x => BigInt(x));

        const choice = 1;

        // 1st vote should succeed
        await votingContract.vote(choice, proofFull, pubSignals);
        expect(await votingContract.votes(choice)).to.equal(1);

        // 2nd vote with same nullifier should fail
        await expect(
            votingContract.vote(choice, proofFull, pubSignals)
        ).to.be.revertedWith("Double voting detected");

        // Votes count stays at 1
        expect(await votingContract.votes(choice)).to.equal(1);
    });
});
