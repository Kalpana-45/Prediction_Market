# Prediction Market

A decentralized prediction market smart contract built with Solidity and Hardhat, deployed on Core Testnet 2.

## Project Description

The Prediction Market is a blockchain-based platform that allows users to create markets for future events, place bets on outcomes, and earn rewards based on correct predictions. This smart contract enables anyone to create prediction markets on any topic, while participants can bet on different outcomes using cryptocurrency.

The platform operates on a peer-to-peer model where the total pool of bets is distributed among winners after deducting a small platform fee. Market creators can resolve markets by declaring the winning outcome once the event has concluded.

## Project Vision

Our vision is to create a transparent, decentralized, and accessible prediction market that democratizes forecasting and enables anyone to participate in predicting future events. By leveraging blockchain technology, we aim to build a trustless system where:

- **Transparency**: All bets, payouts, and market resolutions are recorded on the blockchain
- **Decentralization**: No central authority controls the markets or outcomes
- **Accessibility**: Anyone can create markets or participate in predictions
- **Fairness**: Automated smart contract execution ensures fair distribution of winnings
- **Global Reach**: Cross-border participation without traditional financial barriers

## Key Features

### Core Functionality
- **Market Creation**: Users can create prediction markets with custom questions and multiple outcome options
- **Bet Placement**: Participants can place bets on any available outcome with a minimum bet requirement
- **Market Resolution**: Market creators can resolve markets by declaring the winning outcome
- **Automatic Payouts**: Winners can withdraw their earnings automatically through smart contract execution

### Technical Features
- **Multi-Option Markets**: Support for markets with 2 or more possible outcomes
- **Time-Based Markets**: Markets have deadlines after which betting is disabled
- **Proportional Rewards**: Winnings are distributed proportionally based on bet amounts
- **Platform Fee**: Sustainable 2% platform fee for maintenance and development
- **Gas Optimized**: Efficient Solidity code to minimize transaction costs

### Security Features
- **Access Controls**: Only market creators can resolve their markets
- **Bet Validation**: Minimum bet amounts and option validation
- **Double Spending Protection**: Users cannot withdraw winnings multiple times
- **Market State Management**: Proper state transitions and validations

## Future Scope

### Phase 1 - Enhanced Features
- **Oracle Integration**: Connect with Chainlink oracles for automated market resolution
- **Market Categories**: Organize markets by categories (sports, politics, crypto, etc.)
- **Advanced Market Types**: Binary markets, scalar markets, and combinatorial markets
- **Mobile App**: Native mobile application for iOS and Android

### Phase 2 - DeFi Integration
- **Liquidity Pools**: Automated market makers for continuous trading
- **Yield Farming**: Stake tokens to earn rewards from platform fees
- **Governance Token**: Community governance for platform decisions
- **Cross-Chain**: Deploy on multiple blockchains for wider accessibility

### Phase 3 - Advanced Analytics
- **Prediction Analytics**: Historical data analysis and prediction accuracy tracking
- **Reputation System**: User reputation based on prediction accuracy
- **AI Integration**: Machine learning models for market recommendations
- **Social Features**: Follow successful predictors and market discussions

### Phase 4 - Enterprise Solutions
- **Business Intelligence**: Corporate prediction markets for internal decision making
- **API Services**: RESTful APIs for third-party integrations
- **White-Label Solutions**: Customizable prediction market platforms
- **Institutional Features**: Advanced risk management and compliance tools

## Getting Started

### Prerequisites
- Node.js v16 or higher
- npm or yarn
- MetaMask or compatible wallet
- Core Testnet 2 tokens for deployment

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd prediction-market
```

2. Install dependencies
```bash
npm install
```

3. Configure environment variables
```bash
cp .env.example .env
# Edit .env with your private key
```

4. Compile the contract
```bash
npm run compile
```

5. Deploy to Core Testnet 2
```bash
npm run deploy
```

### Usage

#### Creating a Market
```javascript
const tx = await predictionMarket.createMarket(
  "Who will win the 2024 World Cup?",
  ["Brazil", "Argentina", "France", "Other"],
  86400 // 24 hours in seconds
);
```

#### Placing a Bet
```javascript
const tx = await predictionMarket.placeBet(
  0, // marketId
  1, // optionIndex (Argentina)
  { value: ethers.parseEther("0.1") }
);
```

#### Resolving a Market
```javascript
const tx = await predictionMarket.resolveMarket(
  0, // marketId
  1  // winningOption (Argentina)
);
```

#### Withdrawing Winnings
```javascript
const tx = await predictionMarket.withdrawWinnings(0); // marketId
```

## Contract Details

- **Network**: Core Testnet 2
- **RPC URL**: https://rpc.test2.btcs.network
- **Chain ID**: 1115
- **Minimum Bet**: 0.001 CORE
- **Platform Fee**: 2%

## Development

### Testing
```bash
npm test
```

### Local Development
```bash
npm run node
npm run deploy:local
```

### Contract Verification
After deployment, verify the contract on the blockchain explorer using the provided contract address.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, email support@predictionmarket.com or join our Discord community.

## Disclaimer

This is experimental software. Use at your own risk. Always do your own research before participating in prediction markets.
# Prediction Market

A decentralized prediction market smart contract built with Solidity and Hardhat, deployed on Core Testnet 2.

## Project Description

The Prediction Market is a blockchain-based platform that allows users to create markets for future events, place bets on outcomes, and earn rewards based on correct predictions. This smart contract enables anyone to create prediction markets on any topic, while participants can bet on different outcomes using cryptocurrency.

The platform operates on a peer-to-peer model where the total pool of bets is distributed among winners after deducting a small platform fee. Market creators can resolve markets by declaring the winning outcome once the event has concluded.

## Project Vision

Our vision is to create a transparent, decentralized, and accessible prediction market that democratizes forecasting and enables anyone to participate in predicting future events. By leveraging blockchain technology, we aim to build a trustless system where:

- **Transparency**: All bets, payouts, and market resolutions are recorded on the blockchain
- **Decentralization**: No central authority controls the markets or outcomes
- **Accessibility**: Anyone can create markets or participate in predictions
- **Fairness**: Automated smart contract execution ensures fair distribution of winnings
- **Global Reach**: Cross-border participation without traditional financial barriers

## Key Features

### Core Functionality
- **Market Creation**: Users can create prediction markets with custom questions and multiple outcome options
- **Bet Placement**: Participants can place bets on any available outcome with a minimum bet requirement
- **Market Resolution**: Market creators can resolve markets by declaring the winning outcome
- **Automatic Payouts**: Winners can withdraw their earnings automatically through smart contract execution

### Technical Features
- **Multi-Option Markets**: Support for markets with 2 or more possible outcomes
- **Time-Based Markets**: Markets have deadlines after which betting is disabled
- **Proportional Rewards**: Winnings are distributed proportionally based on bet amounts
- **Platform Fee**: Sustainable 2% platform fee for maintenance and development
- **Gas Optimized**: Efficient Solidity code to minimize transaction costs

### Security Features
- **Access Controls**: Only market creators can resolve their markets
- **Bet Validation**: Minimum bet amounts and option validation
- **Double Spending Protection**: Users cannot withdraw winnings multiple times
- **Market State Management**: Proper state transitions and validations

## Future Scope

### Phase 1 - Enhanced Features
- **Oracle Integration**: Connect with Chainlink oracles for automated market resolution
- **Market Categories**: Organize markets by categories (sports, politics, crypto, etc.)
- **Advanced Market Types**: Binary markets, scalar markets, and combinatorial markets
- **Mobile App**: Native mobile application for iOS and Android

### Phase 2 - DeFi Integration
- **Liquidity Pools**: Automated market makers for continuous trading
- **Yield Farming**: Stake tokens to earn rewards from platform fees
- **Governance Token**: Community governance for platform decisions
- **Cross-Chain**: Deploy on multiple blockchains for wider accessibility

### Phase 3 - Advanced Analytics
- **Prediction Analytics**: Historical data analysis and prediction accuracy tracking
- **Reputation System**: User reputation based on prediction accuracy
- **AI Integration**: Machine learning models for market recommendations
- **Social Features**: Follow successful predictors and market discussions

### Phase 4 - Enterprise Solutions
- **Business Intelligence**: Corporate prediction markets for internal decision making
- **API Services**: RESTful APIs for third-party integrations
- **White-Label Solutions**: Customizable prediction market platforms
- **Institutional Features**: Advanced risk management and compliance tools

## Getting Started

### Prerequisites
- Node.js v16 or higher
- npm or yarn
- MetaMask or compatible wallet
- Core Testnet 2 tokens for deployment

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd prediction-market
```

2. Install dependencies
```bash
npm install
```

3. Configure environment variables
```bash
cp .env.example .env
# Edit .env with your private key
```

4. Compile the contract
```bash
npm run compile
```

5. Deploy to Core Testnet 2
```bash
npm run deploy
```

### Usage

#### Creating a Market
```javascript
const tx = await predictionMarket.createMarket(
  "Who will win the 2024 World Cup?",
  ["Brazil", "Argentina", "France", "Other"],
  86400 // 24 hours in seconds
);
```

#### Placing a Bet
```javascript
const tx = await predictionMarket.placeBet(
  0, // marketId
  1, // optionIndex (Argentina)
  { value: ethers.parseEther("0.1") }
);
```

#### Resolving a Market
```javascript
const tx = await predictionMarket.resolveMarket(
  0, // marketId
  1  // winningOption (Argentina)
);
```

#### Withdrawing Winnings
```javascript
const tx = await predictionMarket.withdrawWinnings(0); // marketId
```

## Contract Details

- **Network**: Core Testnet 2
- **RPC URL**: https://rpc.test2.btcs.network
- **Chain ID**: 1115
- **Minimum Bet**: 0.001 CORE
- **Platform Fee**: 2%

## Development

### Testing
```bash
npm test
```

### Local Development
```bash
npm run node
npm run deploy:local
```

### Contract Verification
After deployment, verify the contract on the blockchain explorer using the provided contract address.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, email support@predictionmarket.com or join our Discord community.

## Disclaimer

This is experimental software. Use at your own risk. Always do your own research before participating in prediction markets.
0xC5714BA85f12bAE0f2496A2EB1cCef6ea0Db2ac3
<img width="955" height="443" alt="Transaction" src="https://github.com/user-attachments/assets/effcebd9-9702-4edb-8b81-7b3460ea827a" />

