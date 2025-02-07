// SPDX-License-Identifier: LMNuggets
pragma solidity ^0.8.20;

contract BuyerInfoStorage {
    mapping(address => bytes32) private buyerInfoHash;

    event BuyerInfoSubmitted(address indexed buyer, bytes32 buyerInfoHash);
    event BuyerInfoRetrieved(address indexed seller, bytes32 buyerInfoHash);

    modifier onlyBuyer(address _buyer) {
        require(msg.sender == _buyer, "Only the buyer can submit their info");
        _;
    }

    function submitBuyerInfoHash(bytes32 _buyerInfoHash) external {
        buyerInfoHash[msg.sender] = _buyerInfoHash;
        emit BuyerInfoSubmitted(msg.sender, _buyerInfoHash);
    }

    function getBuyerInfoHash(address _buyer) external view returns (bytes32) {
        return buyerInfoHash[_buyer];
    }

    function verifyBuyerInfoHash(address _buyer, bytes32 _providedHash) external view returns (bool) {
        return buyerInfoHash[_buyer] == _providedHash;
    }
}

contract C2CPlatformWithBuyerInfo {
    BuyerInfoStorage public buyerInfoStorage;

    enum TradeStatus { Pending, Locked, OrderInProgress, Complete, Cancelled }
    struct Trade {
        address seller;
        address buyer;
        uint256 amount;
        TradeStatus status;
        bytes32 tradeHash;  // 交易哈希
        bytes32 buyerInfoHash; // 买家信息哈希
    }

    mapping(uint => Trade) public trades;
    uint public tradeCounter;

    event TradeCreated(uint tradeId, address seller, address buyer, uint amount, bytes32 tradeHash, bytes32 buyerInfoHash);
    event TradeConfirmed(uint tradeId);

    function createTrade(address _seller, bytes32 _tradeHash) external payable {
        require(msg.value > 0, "Amount must be greater than 0");

        // 从BuyerInfoStorage合约中获取买家的信息哈希
        bytes32 buyerInfoHash = buyerInfoStorage.getBuyerInfoHash(msg.sender);

        trades[tradeCounter] = Trade({
            seller: _seller,
            buyer: msg.sender,
            amount: msg.value,
            status: TradeStatus.Pending,
            tradeHash: _tradeHash,
            buyerInfoHash: buyerInfoHash
        });

        emit TradeCreated(tradeCounter, _seller, msg.sender, msg.value, _tradeHash, buyerInfoHash);
        tradeCounter++;
    }

    function confirmTrade(uint _tradeId, bytes32 _preimage) external {
        Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.seller, "Only seller can confirm trade");
        require(trade.status == TradeStatus.Locked, "Trade is not locked");

        require(keccak256(abi.encodePacked(_preimage)) == trade.tradeHash, "Invalid preimage");

        trade.status = TradeStatus.Complete;

        bytes32 buyerInfoHash = trade.buyerInfoHash;

        emit TradeConfirmed(_tradeId);

        // ing....
    }
}
