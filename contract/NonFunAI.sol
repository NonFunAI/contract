// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/access/Ownable.sol";
import "./@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IRewardSystem {
    function logBuy(address user, uint amount) external;
    function reward(address refer, uint amount) external returns (uint);
}
interface IBotProtect {
    function protect(address from, address to, uint amount) external;
}
contract NonFunAI is ERC20, Ownable, ReentrancyGuard {
    //ALLOCATION
    uint private CORE_TEAM = 50_000_000 * 10 ** 18;
    uint private SEED_ROUND_SALE = 40_000_000 * 10 ** 18;
    uint private PUBLIC_ROUND_SALE = 40_000_000 * 10 ** 18;
    uint private COMMUNITY = 55_000_000 * 10 ** 18;
    uint private LIQUIDITY = 140_000_000 * 10 ** 18;
    uint private DEVELOPMENT = 50_000_000 * 10 ** 18;
    uint private STAKING_REWARD = 125_000_000 * 10 ** 18;
    //SALE INFO
    uint public SEED_ROUND_PRICE = 16667;
    uint public PUBLIC_ROUND_PRICE = 15384;
    uint public SEED_ROUND_FROM;
    uint public SEED_ROUND_TO;
    uint public PUBLIC_ROUND_FROM;
    uint public PUBLIC_ROUND_TO;
    //TOKEN LOCKED TIME
    uint public TGE;
    uint public CORE_TEAM_LOCKED = 30 * 12 days;
    uint public COMMUNITY_LOCKED = 30 days;
    uint public LIQUIDITY_LOCKED = 30 days;
    uint public DEVELOPMENT_LOCKED = 30 * 12 days;
    uint public STAKING_REWARD_LOCKED = 10 days;
    //TOKEN UNLOCKED
    uint public CORE_TEAM_UNLOCKED;
    uint public COMMUNITY_UNLOCKED;
    uint public LIQUIDITY_UNLOCKED;
    uint public DEVELOPMENT_UNLOCKED;
    uint public STAKING_REWARD_UNLOCKED;
    //IRewardSystem
    IRewardSystem public RewardSystem;
    //BotProtect
    IBotProtect public BotProtect;

    mapping(address => bool) private whiteLists;

    event LogAddWhiteList(address user, bool wl);

    constructor() ERC20("Non-Fungible AI", "NFAI"){
        _transferOwnership(tx.origin);
    }

    function buy(address refer) external payable nonReentrant {
        require(msg.value >= 0.01 ether, "min buy 0.01 bnb");
        bool inSeedRound = SEED_ROUND_FROM > 0 && SEED_ROUND_TO > SEED_ROUND_FROM;
        bool inPrivateRound = PUBLIC_ROUND_FROM > 0 && PUBLIC_ROUND_TO > PUBLIC_ROUND_FROM;
        uint amount;
        uint reward;
        if (inSeedRound) {
            amount = msg.value * SEED_ROUND_PRICE;
        } else if (inPrivateRound) {
            amount = msg.value * PUBLIC_ROUND_PRICE;
        } else {
            revert("not in sale time");
        }
        if (address(RewardSystem) != address(0)) {
            RewardSystem.logBuy(msg.sender, msg.value);
            reward = RewardSystem.reward(refer, msg.value);
        }
        if (reward > 0 && reward < msg.value && refer != msg.sender) {
            (bool success,) = payable(refer).call{value : reward}("");
            require(success, "reward failed");
        }
        _mint(msg.sender, amount);
    }

    function _transfer(address from, address to, uint amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (TGE == 0) {
            require(whiteLists[from] || whiteLists[to], "Trading is not active until TGE.");
        }

        if (address(BotProtect) != address(0)) {
            BotProtect.protect(from, to, amount);
        }
        super._transfer(from, to, amount);
    }

    function startTGE() external onlyOwner {
        //60% of LIQUIDITY
        _mint(msg.sender, LIQUIDITY * 6000 / 10000);
        //LOCKED TOKEN OF TEAM
        TGE = block.timestamp;
        CORE_TEAM_LOCKED += TGE;
        COMMUNITY_LOCKED += TGE;
        LIQUIDITY_LOCKED += TGE;
        DEVELOPMENT_LOCKED += TGE;
        STAKING_REWARD_LOCKED += TGE;
    }

    function vesting() external onlyOwner {
        require(TGE != 0, "must started TGE");
        if (CORE_TEAM_LOCKED <= block.timestamp && CORE_TEAM_UNLOCKED < CORE_TEAM) {
            _mint(msg.sender, CORE_TEAM * 500 / 10000);
            CORE_TEAM_UNLOCKED += CORE_TEAM * 500 / 10000;
            CORE_TEAM_LOCKED += 30 days;
        }
        if (COMMUNITY_LOCKED <= block.timestamp && COMMUNITY_UNLOCKED < COMMUNITY) {
            _mint(msg.sender, COMMUNITY * 500 / 10000);
            COMMUNITY_UNLOCKED += COMMUNITY * 500 / 10000;
            COMMUNITY_LOCKED += 30 days;
        }
        if (LIQUIDITY_LOCKED <= block.timestamp && LIQUIDITY_UNLOCKED < LIQUIDITY) {
            _mint(msg.sender, LIQUIDITY * 500 / 10000);
            LIQUIDITY_UNLOCKED += LIQUIDITY * 500 / 10000;
            LIQUIDITY_LOCKED += 30 days;
        }
        if (DEVELOPMENT_LOCKED <= block.timestamp && DEVELOPMENT_UNLOCKED < DEVELOPMENT) {
            _mint(msg.sender, DEVELOPMENT * 500 / 10000);
            DEVELOPMENT_UNLOCKED += DEVELOPMENT * 500 / 10000;
            DEVELOPMENT_LOCKED += 30 days;
        }
        if (STAKING_REWARD_LOCKED <= block.timestamp && STAKING_REWARD_UNLOCKED < STAKING_REWARD) {
            _mint(msg.sender, STAKING_REWARD * 500 / 10000);
            STAKING_REWARD_UNLOCKED += STAKING_REWARD * 500 / 10000;
            STAKING_REWARD_LOCKED += 30 days;
        }
    }

    function addWhiteLists(address user, bool _wl) external onlyOwner {
        whiteLists[user] = _wl;
        emit LogAddWhiteList(user, _wl);
    }

    function updateRewardSystem(IRewardSystem _rw) external onlyOwner {
        RewardSystem = _rw;
    }

    function updateBotProtectSystem(IBotProtect _bp) external onlyOwner {
        BotProtect = _bp;
    }

    function updateSeedTime(uint from, uint to) external onlyOwner {
        SEED_ROUND_FROM = from;
        SEED_ROUND_TO = to;
    }

    function updatePublicTime(uint from, uint to) external onlyOwner {
        PUBLIC_ROUND_FROM = from;
        PUBLIC_ROUND_TO = to;
    }

    function withdrawToken(
        address token,
        uint amount,
        address sendTo
    ) external onlyOwner {
        ERC20(token).transfer(sendTo, amount);
    }

    function withdraw() external onlyOwner {
        (bool success,) = msg.sender.call{value : address(this).balance}("");
        require(success, "withdraw failed");
    }

    receive() payable external {}
}