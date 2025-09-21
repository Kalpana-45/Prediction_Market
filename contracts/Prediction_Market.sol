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
        mapping(address => bool) participants; // ✅ Track unique participants
    }

    struct Comment {
        address user;
        string text;
        uint256 timestamp;
    }

    address public admin;
    uint256 public marketCount;
    uint256 public constant PLATFORM_FEE = 2;

    mapping(uint256 => Market) public markets;
    mapping(address => uint256[]) public userHistory;
    mapping(address => uint256) public totalWinnings;
    mapping(address => uint256) public totalWins;
    address[] public allUsers;
    mapping(uint256 => Comment[]) public marketComments;

    // Category tracking
    mapping(string => uint256) public categoryCounts;
    string[] public allCategories;
    mapping(string => bool) private categoryExists;

    event MarketCreated(uint256 indexed marketId, string question, string[] options, uint256 deadline, address creator, string category);
    event BetPlaced(uint256 indexed marketId, address indexed user, uint256 optionIndex, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint256 winningOption, uint256 totalPool);
    event WinningsWithdrawn(uint256 indexed marketId, address indexed user, uint256 amount);
    event MarketCancelled(uint256 indexed marketId);
    event DeadlineUpdated(uint256 indexed marketId, uint256 newDeadline);
    event BettingPaused(uint256 indexed marketId, bool status);
    event CommentAdded(uint256 indexed marketId, address indexed user, string comment, uint256 timestamp);
    event AdminWithdrawn(address indexed admin, uint256 amount);

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

        // update category metadata
        if (!categoryExists[category]) {
            categoryExists[category] = true;
            allCategories.push(category);
        }
        categoryCounts[category] += 1;

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

        if (market.userBets[msg.sender][optionIndex] == 0) {
            userHistory[msg.sender].push(marketId);
            allUsers.push(msg.sender);
        }

        market.userBets[msg.sender][optionIndex] += msg.value;
        market.optionPools[optionIndex] += msg.value;
        market.totalPool += msg.value;
        market.participants[msg.sender] = true; // ✅ track participant

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

        totalWinnings[msg.sender] += userShare;
        totalWins[msg.sender] += 1;

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
        markets[marketId].bettingPaused = status;
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
            string memory,
            string[] memory,
            uint256,
            bool,
            uint256,
            address,
            uint256,
            string memory,
            bool,
            bool,
            uint256,
            uint256
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

    function getTotalBetsByUser(uint256 marketId, address user)
        external
        view
        marketExists(marketId)
        returns (uint256 total)
    {
        Market storage market = markets[marketId];
        for (uint256 i = 0; i < market.options.length; i++) {
            total += market.userBets[user][i];
        }
    }

    function getOptionPoolDistribution(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (uint256[] memory)
    {
        Market storage market = markets[marketId];
        uint256[] memory poolDistribution = new uint256[](market.options.length);
        for (uint256 i = 0; i < market.options.length; i++) {
            poolDistribution[i] = market.optionPools[i];
        }
        return poolDistribution;
    }

    function getAllMarkets() external view returns (
        uint256[] memory ids,
        string[] memory questions,
        string[] memory categories,
        uint256[] memory deadlines,
        bool[] memory resolvedList
    ) {
        ids = new uint256[](marketCount);
        questions = new string[](marketCount);
        categories = new string[](marketCount);
        deadlines = new uint256[](marketCount);
        resolvedList = new bool[](marketCount);

        for (uint256 i = 0; i < marketCount; i++) {
            Market storage market = markets[i];
            ids[i] = i;
            questions[i] = market.question;
            categories[i] = market.category;
            deadlines[i] = market.deadline;
            resolvedList[i] = market.resolved;
        }
    }

    function getLeaderboard(uint256 topN)
        external
        view
        returns (address[] memory users, uint256[] memory winnings, uint256[] memory wins)
    {
        require(topN > 0, "Invalid number");

        users = new address[](topN);
        winnings = new uint256[](topN);
        wins = new uint256[](topN);

        for (uint256 i = 0; i < allUsers.length; i++) {
            address user = allUsers[i];
            uint256 userWinnings = totalWinnings[user];

            for (uint256 j = 0; j < topN; j++) {
                if (userWinnings > winnings[j]) {
                    for (uint256 k = topN - 1; k > j; k--) {
                        users[k] = users[k - 1];
                        winnings[k] = winnings[k - 1];
                        wins[k] = wins[k - 1];
                    }
                    users[j] = user;
                    winnings[j] = userWinnings;
                    wins[j] = totalWins[user];
                    break;
                }
            }
        }
    }

    function addComment(uint256 marketId, string calldata commentText)
        external
        marketExists(marketId)
    {
        require(bytes(commentText).length > 0, "Empty comment");
        marketComments[marketId].push(Comment(msg.sender, commentText, block.timestamp));
        emit CommentAdded(marketId, msg.sender, commentText, block.timestamp);
    }

    function getComments(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (Comment[] memory)
    {
        return marketComments[marketId];
    }

    // ✅ Get all active and open markets
    function getActiveMarkets() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < marketCount; i++) {
            Market storage market = markets[i];
            if (
                !market.resolved &&
                !market.cancelled &&
                block.timestamp < market.deadline &&
                !market.bettingPaused
            ) {
                count++;
            }
        }

        uint256[] memory activeMarketIds = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < marketCount; i++) {
            Market storage market = markets[i];
            if (
                !market.resolved &&
                !market.cancelled &&
                block.timestamp < market.deadline &&
                !market.bettingPaused
            ) {
                activeMarketIds[index++] = i;
            }
        }

        return activeMarketIds;
    }

    // ✅ Get user's active bets
    function getUserActiveBets(address user) 
        external 
        view 
        returns (uint256[] memory marketIds, uint256[] memory optionIndexes, uint256[] memory betAmounts) 
    {
        uint256 count = 0;

        for (uint256 i = 0; i < marketCount; i++) {
            Market storage market = markets[i];
            if (!market.resolved && !market.cancelled && block.timestamp < market.deadline) {
                for (uint256 j = 0; j < market.options.length; j++) {
                    if (market.userBets[user][j] > 0) {
                        count++;
                    }
                }
            }
        }

        marketIds = new uint256[](count);
        optionIndexes = new uint256[](count);
        betAmounts = new uint256[](count);

        uint256 index = 0;

        for (uint256 i = 0; i < marketCount; i++) {
            Market storage market = markets[i];
            if (!market.resolved && !market.cancelled && block.timestamp < market.deadline) {
                for (uint256 j = 0; j < market.options.length; j++) {
                    uint256 bet = market.userBets[user][j];
                    if (bet > 0) {
                        marketIds[index] = i;
                        optionIndexes[index] = j;
                        betAmounts[index] = bet;
                        index++;
                    }
                }
            }
        }
    }

    // ✅ Get all cancelled markets
    function getCancelledMarkets() external view returns (uint256[] memory cancelledIds) {
        uint256 count = 0;
        for (uint256 i = 0; i < marketCount; i++) {
            if (markets[i].cancelled) {
                count++;
            }
        }
        cancelledIds = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < marketCount; i++) {
            if (markets[i].cancelled) {
                cancelledIds[index++] = i;
            }
        }
    }

    // ✅ Get all resolved markets
    function getResolvedMarkets() external view returns (uint256[] memory resolvedIds) {
        uint256 count = 0;
        for (uint256 i = 0; i < marketCount; i++) {
            if (markets[i].resolved) {
                count++;
            }
        }
        resolvedIds = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < marketCount; i++) {
            if (markets[i].resolved) {
                resolvedIds[index++] = i;
            }
        }
    }

    // ✅ Get all participants of a market
    function getMarketParticipants(uint256 marketId) 
        external 
        view 
        marketExists(marketId) 
        returns (address[] memory participantsList) 
    {
        Market storage market = markets[marketId];
        uint256 count = 0;

        for (uint256 i = 0; i < allUsers.length; i++) {
            if (market.participants[allUsers[i]]) {
                count++;
            }
        }

        participantsList = new address[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < allUsers.length; i++) {
            if (market.participants[allUsers[i]]) {
                participantsList[index++] = allUsers[i];
            }
        }
    }

    // ✅ Get markets by a specific category
    function getMarketsByCategory(string memory category)
        external
        view
        returns (uint256[] memory categoryMarketIds)
    {
        uint256 count = 0;
        for (uint256 i = 0; i < marketCount; i++) {
            if (
                keccak256(bytes(markets[i].category)) ==
                keccak256(bytes(category))
            ) {
                count++;
            }
        }

        categoryMarketIds = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < marketCount; i++) {
            if (
                keccak256(bytes(markets[i].category)) ==
                keccak256(bytes(category))
            ) {
                categoryMarketIds[index++] = i;
            }
        }
    }

    // ---------- NEW UTIL FUNCTIONS ----------

    /// @notice Returns number of unique participants and total pool for a market
    function getMarketStats(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (uint256 participantsCount, uint256 totalPool)
    {
        Market storage market = markets[marketId];
        uint256 count = 0;
        for (uint256 i = 0; i < allUsers.length; i++) {
            if (market.participants[allUsers[i]]) {
                count++;
            }
        }
        participantsCount = count;
        totalPool = market.totalPool;
    }

    /// @notice Returns total bet amount by user across all markets, total won (tracked), and marketsJoined (history)
    function getUserStats(address user)
        external
        view
        returns (uint256 totalBet, uint256 totalWon, uint256 marketsJoined)
    {
        // totalBet: sum of bets across all markets/options
        uint256 sum = 0;
        for (uint256 i = 0; i < marketCount; i++) {
            Market storage market = markets[i];
            for (uint256 j = 0; j < market.options.length; j++) {
                sum += market.userBets[user][j];
            }
        }
        totalBet = sum;
        totalWon = totalWinnings[user];
        marketsJoined = userHistory[user].length;
    }

    /// @notice Admin can withdraw the contract's ETH balance (platform fees accumulate here).
    /// @dev IMPORTANT: this transfers the entire contract balance to admin. Ensure platform fees are the only funds expected here.
    function adminWithdrawFees() external onlyAdmin {
        uint256 bal = address(this).balance;
        require(bal > 0, "No balance to withdraw");
        payable(admin).transfer(bal);
        emit AdminWithdrawn(admin, bal);
    }

    /// @notice Returns top categories by number of markets. If fewer categories exist than topN, returns all.
    function getTopCategories(uint256 topN)
        external
        view
        returns (string[] memory categories, uint256[] memory counts)
    {
        require(topN > 0, "topN must be > 0");
        uint256 totalCats = allCategories.length;
        if (totalCats == 0) {
            categories = new string;
            counts = new uint256;
            return (categories, counts);
        }

        // prepare arrays of size totalCats
        string[] memory catArr = new string[](totalCats);
        uint256[] memory cntArr = new uint256[](totalCats);

        for (uint256 i = 0; i < totalCats; i++) {
            catArr[i] = allCategories[i];
            cntArr[i] = categoryCounts[allCategories[i]];
        }

        // We will build topN lists
        uint256 resultSize = topN <= totalCats ? topN : totalCats;
        categories = new string[](resultSize);
        counts = new uint256[](resultSize);

        for (uint256 r = 0; r < resultSize; r++) {
            // find max index in cntArr
            uint256 maxIdx = r;
            for (uint256 k = r; k < totalCats; k++) {
                if (cntArr[k] > cntArr[maxIdx]) {
                    maxIdx = k;
                }
            }
            // swap r and maxIdx
            if (maxIdx != r) {
                string memory tmpS = catArr[r];
                catArr[r] = catArr[maxIdx];
                catArr[maxIdx] = tmpS;

                uint256 tmpN = cntArr[r];
                cntArr[r] = cntArr[maxIdx];
                cntArr[maxIdx] = tmpN;
            }
            categories[r] = catArr[r];
            counts[r] = cntArr[r];
        }
    }
}

