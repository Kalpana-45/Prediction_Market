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
        mapping(address => bool) participants;
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
    event AdminUpdated(address oldAdmin, address newAdmin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier marketExists(uint256 marketId) {
        require(marketId < marketCount, "Market does not exist");
        _;
    }

    modifier marketActive(uint256 marketId) {
        Market storage m = markets[marketId];
        require(block.timestamp < m.deadline, "Expired");
        require(!m.resolved, "Resolved");
        require(!m.cancelled, "Cancelled");
        require(!m.bettingPaused, "Paused");
        _;
    }

    modifier onlyMarketCreator(uint256 marketId) {
        require(msg.sender == markets[marketId].creator, "Not creator");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // ------------------ CORE LOGIC ------------------
    function createMarket(
        string memory question,
        string[] memory options,
        uint256 duration,
        string memory category,
        uint256 minBet,
        uint256 maxBet
    ) external returns (uint256) {
        require(options.length >= 2, "Need >=2 options");
        require(duration > 0, "Invalid duration");
        require(bytes(question).length > 0, "Empty question");

        uint256 marketId = marketCount++;
        Market storage m = markets[marketId];

        m.question = question;
        m.options = options;
        m.deadline = block.timestamp + duration;
        m.creator = msg.sender;
        m.category = category;
        m.minBet = minBet;
        m.maxBet = maxBet;

        if (!categoryExists[category]) {
            categoryExists[category] = true;
            allCategories.push(category);
        }
        categoryCounts[category]++;

        emit MarketCreated(marketId, question, options, m.deadline, msg.sender, category);
        return marketId;
    }

    function placeBet(uint256 marketId, uint256 optionIndex)
        external
        payable
        marketExists(marketId)
        marketActive(marketId)
    {
        Market storage m = markets[marketId];
        require(optionIndex < m.options.length, "Invalid option");
        require(msg.value >= m.minBet, "Below min");
        require(msg.value <= m.maxBet, "Above max");

        if (m.userBets[msg.sender][optionIndex] == 0) {
            userHistory[msg.sender].push(marketId);
            allUsers.push(msg.sender);
        }
        m.userBets[msg.sender][optionIndex] += msg.value;
        m.optionPools[optionIndex] += msg.value;
        m.totalPool += msg.value;
        m.participants[msg.sender] = true;

        emit BetPlaced(marketId, msg.sender, optionIndex, msg.value);
    }

    function resolveMarket(uint256 marketId, uint256 winningOption)
        external
        marketExists(marketId)
        onlyMarketCreator(marketId)
    {
        Market storage m = markets[marketId];
        require(!m.resolved && !m.cancelled, "Ended");
        require(block.timestamp >= m.deadline, "Not expired");
        require(winningOption < m.options.length, "Invalid");

        m.resolved = true;
        m.winningOption = winningOption;
        emit MarketResolved(marketId, winningOption, m.totalPool);
    }

    function emergencyResolveMarket(uint256 marketId, uint256 winningOption)
        external
        onlyAdmin
        marketExists(marketId)
    {
        Market storage m = markets[marketId];
        require(!m.resolved && !m.cancelled, "Ended");
        require(winningOption < m.options.length, "Invalid");

        m.resolved = true;
        m.winningOption = winningOption;
        emit MarketResolved(marketId, winningOption, m.totalPool);
    }

    function withdrawWinnings(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        require(m.resolved && !m.cancelled, "Not resolved");

        uint256 bet = m.userBets[msg.sender][m.winningOption];
        require(bet > 0, "No winnings");

        uint256 platformFee = (m.totalPool * PLATFORM_FEE) / 100;
        uint256 poolToDistribute = m.totalPool - platformFee;
        uint256 winningPool = m.optionPools[m.winningOption];
        uint256 share = (bet * poolToDistribute) / winningPool;

        m.userBets[msg.sender][m.winningOption] = 0;
        payable(msg.sender).transfer(share);

        totalWinnings[msg.sender] += share;
        totalWins[msg.sender] += 1;

        emit WinningsWithdrawn(marketId, msg.sender, share);
    }

    function refundUnresolved(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        require(block.timestamp >= m.deadline, "Still active");
        require(!m.resolved && !m.cancelled, "Not refundable");

        uint256 refund;
        for (uint256 i = 0; i < m.options.length; i++) {
            uint256 b = m.userBets[msg.sender][i];
            if (b > 0) {
                refund += b;
                m.userBets[msg.sender][i] = 0;
                m.optionPools[i] -= b;
                m.totalPool -= b;
            }
        }
        require(refund > 0, "No bets");
        payable(msg.sender).transfer(refund);
    }

    function cancelMarket(uint256 marketId)
        external
        marketExists(marketId)
        onlyMarketCreator(marketId)
    {
        Market storage m = markets[marketId];
        require(!m.resolved && !m.cancelled, "Ended");
        require(block.timestamp < m.deadline, "Expired");
        require(m.totalPool == 0, "Bets placed");

        m.cancelled = true;
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
        Market storage m = markets[marketId];
        require(!m.resolved && !m.cancelled, "Ended");
        require(block.timestamp < m.deadline, "Expired");
        require(additionalTime > 0, "Invalid");
        m.deadline += additionalTime;
        emit DeadlineUpdated(marketId, m.deadline);
    }

    // ------------------ NEW ANALYTICS FUNCTIONS ------------------

    /// Platform-wide stats
    function getPlatformStats()
        external
        view
        returns (
            uint256 totalMarkets,
            uint256 totalUsersCount,
            uint256 totalCategoriesCount,
            uint256 totalVolume
        )
    {
        totalMarkets = marketCount;
        totalUsersCount = allUsers.length;
        totalCategoriesCount = allCategories.length;

        uint256 volume;
        for (uint256 i = 0; i < marketCount; i++) {
            volume += markets[i].totalPool;
        }
        totalVolume = volume;
    }

    /// Largest pool market
    function getLargestMarket()
        external
        view
        returns (uint256 marketId, uint256 poolSize)
    {
        uint256 maxPool;
        for (uint256 i = 0; i < marketCount; i++) {
            if (markets[i].totalPool > maxPool) {
                maxPool = markets[i].totalPool;
                marketId = i;
            }
        }
        poolSize = maxPool;
    }

    /// Latest N markets (most recent)
    function getLatestMarkets(uint256 n) external view returns (uint256[] memory ids) {
        if (n > marketCount) n = marketCount;
        ids = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            ids[i] = marketCount - 1 - i;
        }
    }

    /// Markets by creator
    function getMarketsByCreator(address creator)
        external
        view
        returns (uint256[] memory creatorMarkets)
    {
        uint256 count;
        for (uint256 i = 0; i < marketCount; i++) {
            if (markets[i].creator == creator) count++;
        }
        creatorMarkets = new uint256[](count);
        uint256 idx;
        for (uint256 i = 0; i < marketCount; i++) {
            if (markets[i].creator == creator) creatorMarkets[idx++] = i;
        }
    }

    /// Resolved markets where user participated
    function getUserResolvedMarkets(address user)
        external
        view
        returns (uint256[] memory ids)
    {
        uint256 count;
        for (uint256 i = 0; i < userHistory[user].length; i++) {
            uint256 mId = userHistory[user][i];
            if (markets[mId].resolved) count++;
        }
        ids = new uint256[](count);
        uint256 idx;
        for (uint256 i = 0; i < userHistory[user].length; i++) {
            uint256 mId = userHistory[user][i];
            if (markets[mId].resolved) ids[idx++] = mId;
        }
    }

    /// Total pending winnings across all resolved markets (not yet withdrawn)
    function getUserPendingWinnings(address user) external view returns (uint256 total) {
        for (uint256 i = 0; i < marketCount; i++) {
            Market storage m = markets[i];
            if (m.resolved && !m.cancelled) {
                uint256 bet = m.userBets[user][m.winningOption];
                if (bet > 0) {
                    uint256 poolToDistribute = m.totalPool - ((m.totalPool * PLATFORM_FEE) / 100);
                    total += (bet * poolToDistribute) / m.optionPools[m.winningOption];
                }
            }
        }
    }

    // ------------------ ADMIN UTILITIES ------------------

    function updateAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid");
        emit AdminUpdated(admin, newAdmin);
        admin = newAdmin;
    }

    function adminWithdrawFees() external onlyAdmin {
        uint256 bal = address(this).balance;
        require(bal > 0, "No balance");
        payable(admin).transfer(bal);
        emit AdminWithdrawn(admin, bal);
    }

    function emergencyPauseAll() external onlyAdmin {
        for (uint256 i = 0; i < marketCount; i++) {
            if (!markets[i].resolved && !markets[i].cancelled) {
                markets[i].bettingPaused = true;
            }
        }
    }

    function unpauseAll() external onlyAdmin {
        for (uint256 i = 0; i < marketCount; i++) {
            if (!markets[i].resolved && !markets[i].cancelled) {
                markets[i].bettingPaused = false;
            }
        }
    }

    // ------------------ Existing View Functions (shortened) ------------------

    function getTopCategories(uint256 topN)
        external
        view
        returns (string[] memory categories, uint256[] memory counts)
    {
        require(topN > 0, "topN > 0");
        uint256 totalCats = allCategories.length;
        if (totalCats == 0) {
            return (new string , new uint256 );
        }
        if (topN > totalCats) topN = totalCats;

        string[] memory catArr = new string[](totalCats);
        uint256[] memory cntArr = new uint256[](totalCats);
        for (uint256 i = 0; i < totalCats; i++) {
            catArr[i] = allCategories[i];
            cntArr[i] = categoryCounts[allCategories[i]];
        }

        // selection sort topN
        for (uint256 r = 0; r < topN; r++) {
            uint256 maxIdx = r;
            for (uint256 k = r; k < totalCats; k++) {
                if (cntArr[k] > cntArr[maxIdx]) maxIdx = k;
            }
            if (maxIdx != r) {
                (catArr[r], catArr[maxIdx]) = (catArr[maxIdx], catArr[r]);
                (cntArr[r], cntArr[maxIdx]) = (cntArr[maxIdx], cntArr[r]);
            }
        }

        categories = new string[](topN);
        counts = new uint256[](topN);
        for (uint256 i = 0; i < topN; i++) {
            categories[i] = catArr[i];
            counts[i] = cntArr[i];
        }
    }
}

