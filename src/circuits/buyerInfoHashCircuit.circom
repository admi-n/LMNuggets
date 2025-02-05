pragma circom 2.0.0;

include "merkle.circom";
// include "../node_modules/circomlib/circuits/mimcsponge.circom";
// include "../node_modules/circomlib/circuits/mimcsponge.circom";

template BuyerInfoHashCircuit() {
    // 输入交易哈希和买家信息
    signal input tradeHash;          // 交易哈希
    signal input buyerAddressHash;
    signal input buyerPhoneHash;
    signal input merkleRoot;
    signal input merklePath[10];
    signal input merkleIndex; 

    // 定义 Merkle 树验证
    component merkleVerify = Merkle(10);
    merkleVerify.root <== merkleRoot;
    merkleVerify.path <== merklePath;
    merkleVerify.index <== merkleIndex;

    // 综合哈希
    signal buyerInfoHash;
    buyerInfoHash <== sha256(buyerAddressHash, buyerPhoneHash);

    // 组合买家信息的哈希与交易哈希
    signal combinedHash;
    combinedHash <== sha256(tradeHash, buyerInfoHash);

    // 验证合并的哈希是否与 Merkle 树路径中的哈希匹配
    merkleVerify.hash <== combinedHash;
}


template Main() {
    signal input tradeHash;
    signal input buyerAddressHash;
    signal input buyerPhoneHash;
    signal input merkleRoot;
    signal input merklePath[10];
    signal input merkleIndex;

    component buyerInfoHashCircuit = BuyerInfoHashCircuit();
    buyerInfoHashCircuit.tradeHash <== tradeHash;
    buyerInfoHashCircuit.buyerAddressHash <== buyerAddressHash;
    buyerInfoHashCircuit.buyerPhoneHash <== buyerPhoneHash;
    buyerInfoHashCircuit.merkleRoot <== merkleRoot;
    buyerInfoHashCircuit.merklePath <== merklePath;
    buyerInfoHashCircuit.merkleIndex <== merkleIndex;
}
