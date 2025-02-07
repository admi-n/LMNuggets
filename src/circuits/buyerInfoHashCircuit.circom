pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/mimcsponge.circom";


template Selector() {
    signal input in[2];  // 输入两个值
    signal input s;      // 选择信号 (0 或 1)
    signal output out;   // 输出选中的值
    
    // Ensure s is binary
    s * (s-1) === 0;
    
    // Using <== for signal assignment instead of ===
    out <== in[0] + s * (in[1] - in[0]);
}

// MerkleTreeInclusionProof template
template MerkleTreeInclusionProof(nLevels) {
    signal input leaf;
    signal input pathElements[nLevels];
    signal input pathIndices[nLevels];
    signal output root;

    component hashers[nLevels];
    component selectors[nLevels][2];  // 每层需要两个选择器
    signal levelHashes[nLevels + 1];
    
    levelHashes[0] <== leaf;

    for (var i = 0; i < nLevels; i++) {
        // 为每一层创建两个选择器
        selectors[i][0] = Selector();
        selectors[i][1] = Selector();
        
        // 设置选择器的输入
        selectors[i][0].in[0] <== levelHashes[i];
        selectors[i][0].in[1] <== pathElements[i];
        selectors[i][0].s <== pathIndices[i];
        
        selectors[i][1].in[0] <== pathElements[i];
        selectors[i][1].in[1] <== levelHashes[i];
        selectors[i][1].s <== pathIndices[i];

        // 创建并配置哈希组件
        hashers[i] = MiMCSponge(2, 220, 1);
        hashers[i].k <== 0;
        hashers[i].ins[0] <== selectors[i][0].out;  // left
        hashers[i].ins[1] <== selectors[i][1].out;  // right
        
        levelHashes[i + 1] <== hashers[i].outs[0];
    }

    root <== levelHashes[nLevels];
}

// 买家信息哈希电路模板
template BuyerInfoHashCircuit(nLevels) {
    signal input tradeHash;
    signal input buyerAddressHash;
    signal input buyerPhoneHash;
    signal input root;
    signal input pathElements[nLevels];
    signal input pathIndices[nLevels];

    // 计算买家信息哈希
    component buyerInfoHasher = MiMCSponge(2, 220, 1);
    buyerInfoHasher.k <== 0;
    buyerInfoHasher.ins[0] <== buyerAddressHash;
    buyerInfoHasher.ins[1] <== buyerPhoneHash;
    signal buyerInfoHash <== buyerInfoHasher.outs[0];

    // 组合买家信息哈希与交易哈希
    component combinedHasher = MiMCSponge(2, 220, 1);
    combinedHasher.k <== 0;
    combinedHasher.ins[0] <== tradeHash;
    combinedHasher.ins[1] <== buyerInfoHash;
    signal combinedHash <== combinedHasher.outs[0];

    component merkleProof = MerkleTreeInclusionProof(nLevels);
    merkleProof.leaf <== combinedHash;
    merkleProof.pathElements <== pathElements;
    merkleProof.pathIndices <== pathIndices;
    
    root === merkleProof.root;  //验证
}


template Main() {
    var nLevels = 10;
    
    signal input tradeHash;
    signal input buyerAddressHash;
    signal input buyerPhoneHash;
    signal input root;
    signal input pathElements[10];
    signal input pathIndices[10];

    component buyerInfoHashCircuit = BuyerInfoHashCircuit(nLevels);
    buyerInfoHashCircuit.tradeHash <== tradeHash;
    buyerInfoHashCircuit.buyerAddressHash <== buyerAddressHash;
    buyerInfoHashCircuit.buyerPhoneHash <== buyerPhoneHash;
    buyerInfoHashCircuit.root <== root;
    buyerInfoHashCircuit.pathElements <== pathElements;
    buyerInfoHashCircuit.pathIndices <== pathIndices;
}

component main = Main();