//   _      __  __ _   _                        _       
//  | |    |  \/  | \ | |                      | |      
//  | |    | \  / |  \| |_   _  __ _  __ _  ___| |_ ___ 
//  | |    | |\/| | . ` | | | |/ _` |/ _` |/ _ \ __/ __|
//  | |____| |  | | |\  | |_| | (_| | (_| |  __/ |_\__ \
//  |______|_|  |_|_| \_|\__,_|\__, |\__, |\___|\__|___/
//                              __/ | __/ |             
//                             |___/ |___/              

// SPDX-License-Identifier: LMNuggets
pragma solidity ^0.8.20;


import {Ownable2Step} from "./Ownable2Step.sol";
import "./Owner_Pausable.sol";  // 通过两步转移定义owner 用来暂停或者开放合约 
import {EconomyLib} from "./LMNuggetsLib/EconomyLib.sol";
import {HomomorphicEncryptionLib} from "./LMNuggetsLib/HomomorphicEncryptionLib.sol";


contract HashLock is Pausable {

    //using HomomorphicEncryptionLib for HomomorphicEncryptionLib.EncryptedData;

    struct Lock {
        uint256 amount;
        //HomomorphicEncryptionLib.EncryptedData hashLock; // 使用同态加密数据结构
        bytes32 hashLock;
        uint256 timelock;
        address payable sender;
        address payable receiver;
        bool withdrawn;
        bool refunded;
        bytes32 preimage;
    }

    mapping(bytes32 => Lock) public locks;

    event Locked(bytes32 indexed lockId, address indexed sender, address indexed receiver, uint256 amount, bytes32 hashLock, uint256 timelock);
    event Withdrawn(bytes32 indexed lockId, bytes32 preimage);
    event Refunded(bytes32 indexed lockId);

     
    function lock(bytes32 _hashLock, uint256 _timelock, address payable _receiver) internal whenNotPaused returns (bytes32 lockId) {
        require(msg.value > 0, "Amount must be greater than 0");
        require(_timelock > block.timestamp, "Timelock must be in the future");

        lockId = keccak256(abi.encodePacked(msg.sender, _receiver, msg.value, _hashLock, _timelock));
        require(locks[lockId].sender == address(0), "Lock already exists");


    // 使用同态加密
    //  HomomorphicEncryptionLib.KeyPair memory key = HomomorphicEncryptionLib.generateKeyPair();
    //  HomomorphicEncryptionLib.EncryptedData memory encryptedHashLock = HomomorphicEncryptionLib.encrypt(_hashLock, key);

        locks[lockId] = Lock({
            amount: msg.value,
            hashLock: _hashLock,
            //hashLock: encryptedHashLock,
            timelock: _timelock,
            sender: payable(msg.sender),
            receiver: _receiver,
            withdrawn: false,
            refunded: false,
            preimage: bytes32(0)
        });

        emit Locked(lockId, msg.sender, _receiver, msg.value, _hashLock, _timelock);
    }

    function withdraw(bytes32 _lockId, bytes32 _preimage) external whenNotPaused {
        Lock storage lock = locks[_lockId];

        require(lock.amount > 0, "Lock does not exist");
        require(lock.receiver == msg.sender, "Not the receiver");
        require(!lock.withdrawn, "Already withdrawn");
        require(!lock.refunded, "Already refunded");
        require(keccak256(abi.encodePacked(_preimage)) == lock.hashLock, "Invalid preimage");   //x

        // 验证预影像
        //require(lock.hashLock.verify(_preimage), "Invalid preimage");

        lock.withdrawn = true;
        lock.preimage = _preimage;  //x
        lock.receiver.transfer(lock.amount);

        emit Withdrawn(_lockId, _preimage);
    }

    function refund(bytes32 _lockId) external whenNotPaused {
        Lock storage lock = locks[_lockId];

        require(lock.amount > 0, "Lock does not exist");
        require(lock.sender == msg.sender, "Not the sender");
        require(!lock.withdrawn, "Already withdrawn");
        require(!lock.refunded, "Already refunded");
        require(block.timestamp >= lock.timelock, "Timelock not yet passed");

        lock.refunded = true;
        lock.sender.transfer(lock.amount);

        emit Refunded(_lockId);
    }
}

// 主要合约
contract C2CPlatform is HashLock {
    using EconomyLib for EconomyLib.Economy;
    using EconomyLib for mapping(uint => EconomyLib.Trade);

    EconomyLib.Economy private economy;

    // 交易ID到交易详情的映射
    mapping(uint => EconomyLib.Trade) public trades;
    uint public tradeCounter;

    event TradeCreated(uint tradeId, address seller, address buyer, uint amount, bytes32 hashLock, uint256 timelock);
    event TradeLocked(uint tradeId);
    event TradeConfirmed(uint tradeId);
    event TradeCancelled(uint tradeId);
    event FeeCollected(uint tradeId, uint fee);
    event LogPreimage(bytes32 preimage);

    // 创建新交易
    function createTrade(address payable _seller, bytes32 _hashLock, uint256 _timelock) external payable whenNotPaused {
        require(msg.value > 0, "Amount must be greater than 0");
        require(_timelock > block.timestamp, "Timelock must be in the future");

        bytes32 lockId = lock(_hashLock, _timelock, _seller);

        uint fee = EconomyLib.calculateFee(msg.value);  // 调用库中的calculateFee函数
        economy.addToRewardPool(fee);

        trades[tradeCounter] = EconomyLib.Trade({
            seller: _seller,
            buyer: payable(msg.sender),
            amount: msg.value - fee,
            status: EconomyLib.TradeStatus.Pending,
            hashLock: _hashLock,
            timelock: _timelock
        });

        emit FeeCollected(tradeCounter, fee);
        emit TradeCreated(tradeCounter, _seller, msg.sender, msg.value - fee, _hashLock, _timelock);
        tradeCounter++;
    }

    // 锁定资金
    function lockFunds(uint _tradeId) external whenNotPaused {
        EconomyLib.Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.buyer, "Only buyer can lock funds");
        require(trade.status == EconomyLib.TradeStatus.Pending, "Trade is not in pending state");

        trade.status = EconomyLib.TradeStatus.Locked;
        emit TradeLocked(_tradeId);
    }

    // 卖家确认发货
    function confirmShipment(uint _tradeId) external whenNotPaused {
        EconomyLib.Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.seller, "Only seller can confirm shipment");
        require(trade.status == EconomyLib.TradeStatus.Locked, "Funds are not locked");

        trade.status = EconomyLib.TradeStatus.OrderInProgress;
        emit TradeConfirmed(_tradeId);
    }

    // 买家确认收货
    function confirmReceipt(uint _tradeId, bytes32 _preimage) external whenNotPaused {
        EconomyLib.Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.buyer, "Only buyer can confirm receipt");
        require(trade.status == EconomyLib.TradeStatus.OrderInProgress, "Funds are not in order progress state");
        require(keccak256(abi.encodePacked(_preimage)) == trade.hashLock, "Invalid preimage");

        trade.status = EconomyLib.TradeStatus.Complete;
        trade.seller.transfer(trade.amount);
        emit TradeConfirmed(_tradeId);

        emit LogPreimage(_preimage);
    }

    // 取消交易并退还资金
    function cancelTrade(uint _tradeId) external whenNotPaused {
        EconomyLib.Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.buyer, "Only buyer can cancel trade");
        require(trade.status == EconomyLib.TradeStatus.Pending || trade.status == EconomyLib.TradeStatus.Locked, "Cannot cancel trade in current state");

        if (trade.status == EconomyLib.TradeStatus.Locked) {
            trade.status = EconomyLib.TradeStatus.Cancelled;
            trade.buyer.transfer(trade.amount);
        } else if (trade.status == EconomyLib.TradeStatus.Pending) {
            trade.status = EconomyLib.TradeStatus.Cancelled;
        }

        emit TradeCancelled(_tradeId);
    }

    // 每周分配激励池
    function distributeWeeklyRewards() external onlyOwner whenNotPaused {
        economy.distributeRewards(tradeCounter, trades);
    }
}



// 用于后期更新(暂定)
contract Create2Factory {
    event Deploy(address add);

    function deploy(uint _salt) external {
        C2CPlatform _contract = new C2CPlatform{salt: bytes32(_salt)}();
        emit Deploy(address(_contract));
    }

    function getAddress(bytes memory bytecode, uint _salt) public view returns(address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
        return address(uint160(uint(hash)));
    }

    function getBytecode(address _owner) public pure returns (bytes memory){
        bytes memory bytecode = type(C2CPlatform).creationCode;
        return abi.encodePacked(bytecode, abi.encode(_owner));
    }
}