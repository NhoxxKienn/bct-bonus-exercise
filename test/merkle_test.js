const circomlib = require("circomlibjs");

async function buildMerkleTree(leaves) {
    const poseidon = await circomlib.buildPoseidon();
    const poseidonHash = (l, r) => poseidon.F.toObject(poseidon([l, r]));

    const n = leaves.length;
    const nextPow2 = 1 << Math.ceil(Math.log2(n));
    while (leaves.length < nextPow2) leaves.push(BigInt(0));

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

// Get the Merkle proof elements and indices for a leaf at index
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

async function main() {
    const poseidon = await circomlib.buildPoseidon();
    const F = poseidon.F;

    const voting_secrets = [123n, 456n, 789n, 101n];
    const leaves = voting_secrets.map(s => F.toObject(poseidon([s])));

    const { tree, root } = await buildMerkleTree(leaves);
    console.log("Merkle root:", root.toString());

    // Select your secret and index in voting_secrets
    const secretIndex = 0; // for voting_secret = 123n
    const votingSecret = voting_secrets[secretIndex];
    const leaf = leaves[secretIndex];

    // Compute nullifier as Poseidon(votingSecret)
    const nullifier = F.toObject(poseidon([votingSecret]));

    // Merkle proof
    const { proofElements, proofIndices } = getMerkleProof(tree, secretIndex);

    // Your choice
    const choice = 1;

    // Build input json object for your circuit
    const inputJson = {
        votingSecret: votingSecret.toString(),
        proofElements: proofElements.map(x => x.toString()),
        proofIndices: proofIndices,
        merkleRoot: root.toString(),
        choice: choice,
        nullifier: nullifier.toString()
    };

    console.log("Input.json for your circuit:");
    console.log(JSON.stringify(inputJson, null, 2));
}

main().catch(console.error);
