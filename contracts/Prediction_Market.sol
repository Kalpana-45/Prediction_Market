// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    struct Market {
        string question;
        string[] options;
        uint256 deadline;
        bool resolved;
        bool cancelled;
        uint256 winningOption;
        address creator;
        uint256 totalPool;
        string category;
        bool bettingPaused;
        uint256 minBet;
        uint256 maxBet;
        mapping(uint256 => uint256) optionPools;
        mapping(address => mapping(uint256 => uint256)) userBets;
    }

    address public admin;
    uint256 public marketCount;
    uint256 public constant PLATFORM_FEE = 2;

    mapping(uint256 => Market) public markets;
    mapping(address => uint256[]) public userHistory;

    event MarketCreated(uint256 indexed marketId, string question, string[] options, uint256 deadline, address creator, string category);
    event BetPlaced(uint256 indexed marketId, address indexed user, uint256 optionIndex, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint256 winningOption, uint256 totalPool);
    event WinningsWithdrawn(uint256 indexed marketId, address indexed user, uint256 amount);
    event MarketCancelled(uint256 indexed marketId);
    event DeadlineUpdated(uint256 indexed marketId, uint256 newDeadline);
    event BettingPaused(uint256 indexed marketId, bool status);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier marketExists(uint256 marketId) {
        require(marketId < marketCount, "Market does not exist");
        _;
    }

    modifier marketActive(uint256 marketId) {
        Market storage market = markets[marketId];
        require(block.timestamp < market.deadline, "Market expired");
        require(!market.resolved, "Market already resolved");
        require(!market.cancelled, "Market is cancelled");
        require(!market.bettingPaused, "Betting is paused");
        _;
    }

    modifier onlyMarketCreator(uint256 marketId) {
        require(msg.sender == markets[marketId].creator, "Only market creator allowed");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function createMarket(
        string memory question,
        string[] memory options,
        uint256 duration,
        string memory category,
        uint256 minBet,
        uint256 maxBet
    ) external returns (uint256) {
        require(options.length >= 2, "Need at least 2 options");
        require(duration > 0, "Duration must be greater than zero");
        require(bytes(question).length > 0, "Question is required");

        uint256 marketId = marketCount++;
        Market storage market = markets[marketId];

        market.question = question;
        market.options = options;
        market.deadline = block.timestamp + duration;
        market.creator = msg.sender;
        market.category = category;
        market.minBet = minBet;
        market.maxBet = maxBet;
        market.resolved = false;
        market.cancelled = false;

        emit MarketCreated(marketId, question, options, market.deadline, msg.sender, category);
        return marketId;
    }

    function placeBet(uint256 marketId, uint256 optionIndex)
        external
        payable
        marketExists(marketId)
        marketActive(marketId)
    {
        Market storage market = markets[marketId];
        require(msg.value >= market.minBet, "Bet below minimum limit");
        require(msg.value <= market.maxBet, "Bet exceeds maximum limit");
        require(optionIndex < market.options.length, "Invalid option");

        market.userBets[msg.sender][optionIndex] += msg.value;
        market.optionPools[optionIndex] += msg.value;
        market.totalPool += msg.value;

        userHistory[msg.sender].push(marketId);

        emit BetPlaced(marketId, msg.sender, optionIndex, msg.value);
    }

    function resolveMarket(uint256 marketId, uint256 winningOption)
        external
        marketExists(marketId)
        onlyMarketCreator(marketId)
    {
        Market storage market = markets[marketId];
        require(!market.resolved, "Already resolved");
        require(!market.cancelled, "Market cancelled");
        require(block.timestamp >= market.deadline, "Market not yet expired");
        require(winningOption < market.options.length, "Invalid option");

        market.resolved = true;
        market.winningOption = winningOption;

        emit MarketResolved(marketId, winningOption, market.totalPool);
    }

    function emergencyResolveMarket(uint256 marketId, uint256 winningOption)
        external
        onlyAdmin
        marketExists(marketId)
    {
        Market storage market = markets[marketId];
        require(!market.resolved, "Already resolved");
        require(!market.cancelled, "Market cancelled");
        require(winningOption < market.options.length, "Invalid option");

        market.resolved = true;
        market.winningOption = winningOption;

        emit MarketResolved(marketId, winningOption, market.totalPool);
    }

    function withdrawWinnings(uint256 marketId) external marketExists(marketId) {
        Market storage market = markets[marketId];
        require(market.resolved, "Market not resolved");
        require(!market.cancelled, "Market was cancelled");

        uint256 betAmount = market.userBets[msg.sender][market.winningOption];
        require(betAmount > 0, "No winnings to withdraw");

        uint256 platformFee = (market.totalPool * PLATFORM_FEE) / 100;
        uint256 poolToDistribute = market.totalPool - platformFee;
        uint256 winningPool = market.optionPools[market.winningOption];
        uint256 userShare = (betAmount * poolToDistribute) / winningPool;

        market.userBets[msg.sender][market.winningOption] = 0;
        payable(msg.sender).transfer(userShare);

        emit WinningsWithdrawn(marketId, msg.sender, userShare);
    }

    function refundUnresolved(uint256 marketId) external marketExists(marketId) {
        Market storage market = markets[marketId];
        require(block.timestamp >= market.deadline, "Still active");
        require(!market.resolved && !market.cancelled, "Not eligible for refund");

        uint256 refundAmount;

        for (uint256 i = 0; i < market.options.length; i++) {
            uint256 bet = market.userBets[msg.sender][i];
            if (bet > 0) {
                refundAmount += bet;
                market.userBets[msg.sender][i] = 0;
                market.optionPools[i] -= bet;
                market.totalPool -= bet;
            }
        }

        require(refundAmount > 0, "No bets found");
        payable(msg.sender).transfer(refundAmount);
    }

    function cancelMarket(uint256 marketId)
        external
        marketExists(marketId)
        onlyMarketCreator(marketId)
    {
        Market storage market = markets[marketId];
        require(!market.resolved, "Already resolved");
        require(!market.cancelled, "Already cancelled");
        require(block.timestamp < market.deadline, "Already expired");
        require(market.totalPool == 0, "Bets already placed");

        market.cancelled = true;
        emit MarketCancelled(marketId);
    }

    function pauseBetting(uint256 marketId, bool status)
        external
        marketExists(marketId)
        onlyMarketCreator(marketId)
    {
        Market storage market = markets[marketId];
        market.bettingPaused = status;
        emit BettingPaused(marketId, status);
    }

    function updateDeadline(uint256 marketId, uint256 additionalTime)
        external
        marketExists(marketId)
        onlyMarketCreator(marketId)
    {
        Market storage market = markets[marketId];
        require(!market.resolved && !market.cancelled, "Already ended");
        require(block.timestamp < market.deadline, "Already expired");
        require(additionalTime > 0, "Invalid extension");

        market.deadline += additionalTime;
        emit DeadlineUpdated(marketId, market.deadline);
    }

    function getUserWinnings(uint256 marketId, address user)
        external
        view
        marketExists(marketId)
        returns (uint256)
    {
        Market storage market = markets[marketId];
        if (!market.resolved || market.cancelled) return 0;

        uint256 bet = market.userBets[user][market.winningOption];
        if (bet == 0) return 0;

        uint256 winningPool = market.optionPools[market.winningOption];
        uint256 poolToDistribute = market.totalPool - ((market.totalPool * PLATFORM_FEE) / 100);
        return (bet * poolToDistribute) / winningPool;
    }

    function getUserHistory(address user) external view returns (uint256[] memory) {
        return userHistory[user];
    }

    function getMarketDetails(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (
            string memory question,
            string[] memory options,
            uint256 deadline,
            bool resolved,
            uint256 winningOption,
            address creator,
            uint256 totalPool,
            string memory category,
            bool cancelled,
            bool bettingPaused,
            uint256 minBet,
            uint256 maxBet
        )
    {
        Market storage market = markets[marketId];
        return (
            market.question,
            market.options,
            market.deadline,
            market.resolved,
            market.winningOption,
            market.creator,
            market.totalPool,
            market.category,
            market.cancelled,
            market.bettingPaused,
            market.minBet,
            market.maxBet
        );
    }

    // ✅ New Function: Get total amount user bet in a market
    function getTotalBetsByUser(uint256 marketId, address user) external view marketExists(marketId) returns (uint256 total) {
        Market storage market = markets[marketId];
        for (uint256 i = 0; i < market.options.length; i++) {
            total += market.userBets[user][i];
        }
    }
}
