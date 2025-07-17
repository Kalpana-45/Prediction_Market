// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    struct Market {
        string question;
        string[] options;
        uint256 deadline;
        bool resolved;
        uint256 winningOption;
        address creator;
        uint256 totalPool;
        mapping(uint256 => uint256) optionPools;
        mapping(address => mapping(uint256 => uint256)) userBets;
    }

    mapping(uint256 => Market) public markets;
    uint256 public marketCount;
    uint256 public constant MINIMUM_BET = 0.001 ether;
    uint256 public constant PLATFORM_FEE = 2; // 2% platform fee

    event MarketCreated(
        uint256 indexed marketId,
        string question,
        string[] options,
        uint256 deadline,
        address creator
    );

    event BetPlaced(
        uint256 indexed marketId,
        address indexed user,
        uint256 optionIndex,
        uint256 amount
    );

    event MarketResolved(
        uint256 indexed marketId,
        uint256 winningOption,
        uint256 totalPool
    );

    event WinningsWithdrawn(
        uint256 indexed marketId,
        address indexed user,
        uint256 amount
    );

    modifier marketExists(uint256 marketId) {
        require(marketId < marketCount, "Market does not exist");
        _;
    }

    modifier marketActive(uint256 marketId) {
        require(block.timestamp < markets[marketId].deadline, "Market has expired");
        require(!markets[marketId].resolved, "Market already resolved");
        _;
    }

    modifier onlyMarketCreator(uint256 marketId) {
        require(msg.sender == markets[marketId].creator, "Only market creator can resolve");
        _;
    }

    // Core Function 1: Create a new prediction market
    function createMarket(
        string memory question,
        string[] memory options,
        uint256 duration
    ) external returns (uint256) {
        require(options.length >= 2, "Market must have at least 2 options");
        require(duration > 0, "Duration must be positive");
        require(bytes(question).length > 0, "Question cannot be empty");

        uint256 marketId = marketCount++;
        Market storage market = markets[marketId];
        
        market.question = question;
        market.options = options;
        market.deadline = block.timestamp + duration;
        market.resolved = false;
        market.creator = msg.sender;
        market.totalPool = 0;

        emit MarketCreated(marketId, question, options, market.deadline, msg.sender);
        return marketId;
    }

    // Core Function 2: Place a bet on a market option
    function placeBet(uint256 marketId, uint256 optionIndex) 
        external 
        payable 
        marketExists(marketId) 
        marketActive(marketId) 
    {
        require(msg.value >= MINIMUM_BET, "Bet amount too low");
        require(optionIndex < markets[marketId].options.length, "Invalid option");

        Market storage market = markets[marketId];
        
        market.userBets[msg.sender][optionIndex] += msg.value;
        market.optionPools[optionIndex] += msg.value;
        market.totalPool += msg.value;

        emit BetPlaced(marketId, msg.sender, optionIndex, msg.value);
    }

    // Core Function 3: Resolve market and allow winners to withdraw
    function resolveMarket(uint256 marketId, uint256 winningOption) 
        external 
        marketExists(marketId) 
        onlyMarketCreator(marketId) 
    {
        Market storage market = markets[marketId];
        require(block.timestamp >= market.deadline, "Market not yet expired");
        require(!market.resolved, "Market already resolved");
        require(winningOption < market.options.length, "Invalid winning option");

        market.resolved = true;
        market.winningOption = winningOption;

        emit MarketResolved(marketId, winningOption, market.totalPool);
    }

    // Additional helper function: Withdraw winnings
    function withdrawWinnings(uint256 marketId) 
        external 
        marketExists(marketId) 
    {
        Market storage market = markets[marketId];
        require(market.resolved, "Market not resolved yet");
        
        uint256 userBet = market.userBets[msg.sender][market.winningOption];
        require(userBet > 0, "No winning bet found");
        
        uint256 winningPool = market.optionPools[market.winningOption];
        require(winningPool > 0, "No winning pool");
        
        // Calculate winnings: (user's bet / winning pool) * total pool * (1 - platform fee)
        uint256 platformFeeAmount = (market.totalPool * PLATFORM_FEE) / 100;
        uint256 distributionPool = market.totalPool - platformFeeAmount;
        uint256 winnings = (userBet * distributionPool) / winningPool;
        
        // Reset user's bet to prevent double withdrawal
        market.userBets[msg.sender][market.winningOption] = 0;
        
        payable(msg.sender).transfer(winnings);
        
        emit WinningsWithdrawn(marketId, msg.sender, winnings);
    }

    // View functions
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
            uint256 totalPool
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
            market.totalPool
        );
    }

    function getUserBet(uint256 marketId, address user, uint256 optionIndex) 
        external 
        view 
        marketExists(marketId) 
        returns (uint256) 
    {
        return markets[marketId].userBets[user][optionIndex];
    }

    function getOptionPool(uint256 marketId, uint256 optionIndex) 
        external 
        view 
        marketExists(marketId) 
        returns (uint256) 
    {
        return markets[marketId].optionPools[optionIndex];
    }
}
