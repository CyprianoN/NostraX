// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import 'hardhat/console.sol';

interface IReputationSystem {
    function updateReputation(address user, bool correct) external;
    function getReputation(address user) external view returns (uint256);
}

/**
 * @title WorldCupBetting
 * @notice Assessment entrypoint: replace stub bodies with a full prediction market until
 *         `test/WorldCupBetting.assessment.test.ts` passes. Out-of-the-box, every call reverts so
 *         the assessment suite is red until you implement behavior.
 * @dev Optional behavioral reference in-repo: `PredictionMarket.sol` (do not modify that file
 *      unless your interview allows it). Instructors can run tests against the reference by
 *      setting `WORLD_CUP_ASSESSMENT_SOLUTION=1` when executing Hardhat (see `assessment/instructions.md`).
 */
contract WorldCupBetting is ReentrancyGuard, Ownable {
    enum MarketStatus {
        Open,
        Closed,
        Resolved,
        Cancelled
    }

    struct Market {
        uint256 id;
        string question;
        string description;
        string[] outcomes;
        uint256 resolutionTime;
        address arbitrator;
        address creator;
        uint256 createdAt;
        MarketStatus status;
        uint256 winningOutcome;
        address tokenAddress;
        uint256 totalVolume;
    }

    struct Bet {
        uint256 id;
        address bettor;
        uint256 marketId;
        uint256 outcomeIndex;
        uint256 amount;
        uint256 shares;
        uint256 timestamp;
        bool claimed;
    }

    IReputationSystem public reputationSystem;

    uint256 public marketCount;
    uint256 public betCount;

    mapping(uint256 => Market) public markets;
    mapping(uint256 => Bet) public bets;

    mapping(uint256 => mapping(uint256 => uint256)) public outcomePools;
    mapping(uint256 => mapping(uint256 => uint256)) public outcomeShares;

    mapping(address => uint256[]) public userBets;
    mapping(uint256 => uint256[]) public marketBets;
    mapping(address => uint256) public collectedFees;
    mapping(uint256 => bool) public positionsForSale;
    mapping(uint256 => uint256) public positionPrices;

    constructor(address _reputationSystem) Ownable(msg.sender) {
        reputationSystem = IReputationSystem(_reputationSystem);
    }

    function _candidateStub() internal pure {
        revert("WorldCupBetting: candidate implementation required");
    }

function createMarket(
    string memory _question,
    string memory _description,
    string[] memory _outcomes,
    uint256 _resolutionTime,
    address _arbitrator,
    address _tokenAddress
) external returns (uint256) {
    require(_outcomes.length >= 2, "Need at least 2 outcomes");
    require(_resolutionTime > block.timestamp, "Resolution must be in future");
    require(_arbitrator != address(0), "Invalid arbitrator");

    marketCount++;

    Market storage market = markets[marketCount];

    market.id = marketCount;
    market.question = _question;
    market.description = _description;
    market.outcomes = _outcomes;
    market.resolutionTime = _resolutionTime;
    market.arbitrator = _arbitrator;
    market.creator = msg.sender;
    market.createdAt = block.timestamp;
    market.status = MarketStatus.Open;
    market.winningOutcome = 0;
    market.tokenAddress = _tokenAddress;
    market.totalVolume = 0;

    return marketCount;
}

function placeBet(
    uint256 _marketId,
    uint256 _outcomeIndex,
    uint256 _amount,
    uint256 _minShares
) external payable returns (uint256) {
    Market storage market = markets[_marketId];

    require(market.id != 0, "Market not found");
    require(market.status == MarketStatus.Open, "Market not open");
    require(block.timestamp < market.resolutionTime, "Market closed");
    require(_outcomeIndex < market.outcomes.length, "Invalid outcome");
    require(_amount > 0, "Amount must be > 0");

if (market.tokenAddress == address(0)) {
    require(msg.value == _amount, "Incorrect ETH amount");
} else {
    require(msg.value == 0, "Do not send ETH");

    bool success = IERC20(market.tokenAddress).transferFrom(
        msg.sender,
        address(this),
        _amount
    );

    require(success, "ERC20 transfer failed");
}

    uint256 shares = _amount;

    require(shares >= _minShares, "Slippage exceeded");

    betCount++;

    Bet storage bet = bets[betCount];
    bet.id = betCount;
    bet.bettor = msg.sender;
    bet.marketId = _marketId;
    bet.outcomeIndex = _outcomeIndex;
    bet.amount = _amount;
    bet.shares = shares;
    bet.timestamp = block.timestamp;
    bet.claimed = false;

    outcomePools[_marketId][_outcomeIndex] += _amount;
    outcomeShares[_marketId][_outcomeIndex] += shares;

    market.totalVolume += _amount;

    userBets[msg.sender].push(betCount);
    marketBets[_marketId].push(betCount);

    return betCount;
}

 function resolveMarket(uint256 _marketId, uint256 _winningOutcome) external {
    Market storage market = markets[_marketId];

    require(market.id != 0, "Market not found");
    require(msg.sender == market.arbitrator, "Only arbitrator");
    require(block.timestamp >= market.resolutionTime, "Too early");
    require(market.status == MarketStatus.Open, "Market not open");
    require(_winningOutcome < market.outcomes.length, "Invalid outcome");

    market.status = MarketStatus.Resolved;
    market.winningOutcome = _winningOutcome;
}

function claimWinnings(uint256 _betId) external nonReentrant {
    Bet storage bet = bets[_betId];
    Market storage market = markets[bet.marketId];

    require(bet.id != 0, "Bet not found");
    require(msg.sender == bet.bettor, "Not your bet");
    require(!bet.claimed, "Already claimed");
    require(market.status == MarketStatus.Resolved, "Market not resolved");

    bet.claimed = true;

    if (bet.outcomeIndex != market.winningOutcome) {
        reputationSystem.updateReputation(msg.sender, false);
        return;
    }

    uint256 winningPool = outcomePools[bet.marketId][market.winningOutcome];
    uint256 totalPool = market.totalVolume;

    uint256 payout = (bet.amount * totalPool) / winningPool;
    uint256 fee = (payout * 2) / 100;
    uint256 netPayout = payout - fee;

    reputationSystem.updateReputation(msg.sender, true);

    if (market.tokenAddress == address(0)) {
        collectedFees[address(0)] += fee;

        (bool success, ) = payable(msg.sender).call{value: netPayout}("");
        require(success, "ETH transfer failed");
    } else {
        collectedFees[market.tokenAddress] += fee;

        bool success = IERC20(market.tokenAddress).transfer(
            msg.sender,
            netPayout
        );
        require(success, "ERC20 transfer failed");
    }
}

function listPosition(uint256 _betId, uint256 _price) external {
    Bet storage bet = bets[_betId];

    require(msg.sender == bet.bettor, "Not your bet");
    require(!bet.claimed, "Already claimed");
    require(markets[bet.marketId].status == MarketStatus.Open, "Market not open");

    positionsForSale[_betId] = true;
    positionPrices[_betId] = _price;

}

    function cancelListing(uint256) external {
        _candidateStub();
    }
function buyPosition(uint256 _betId) external payable nonReentrant {
    require(positionsForSale[_betId], "Position not for sale");

    Bet storage bet = bets[_betId];
    Market storage market = markets[bet.marketId];

    require(market.tokenAddress == address(0), "ERC20 not implemented");

    uint256 price = positionPrices[_betId];
    require(msg.value == price, "Incorrect ETH amount");

    address seller = bet.bettor;

    bet.bettor = msg.sender;

    positionsForSale[_betId] = false;
    positionPrices[_betId] = 0;

    (bool success, ) = payable(seller).call{value: price}("");
    require(success, "ETH transfer failed");
}

function withdrawFees(address _tokenAddress)
    external
    onlyOwner
    nonReentrant
{
    uint256 amount = collectedFees[_tokenAddress];

    require(amount > 0, "No fees to withdraw");

    collectedFees[_tokenAddress] = 0;

    if (_tokenAddress == address(0)) {
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "ETH transfer failed");
    } else {
        revert("ERC20 not implemented");
    }
}

function getAvailableFees(address _tokenAddress)
    external
    view
    returns (uint256)
{
    return collectedFees[_tokenAddress];
}

    function calculateShares(uint256, uint256, uint256) public view returns (uint256) {
        _candidateStub();
    }

    function getPrice(uint256, uint256) public view returns (uint256) {
        _candidateStub();
    }

    function getTotalPool(uint256) public view returns (uint256) {
        _candidateStub();
    }

    function getUserBets(address) external view returns (uint256[] memory) {
        _candidateStub();
    }

function getMarketBets(uint256 _marketId)
    external
    view
    returns (uint256[] memory)
{
    return marketBets[_marketId];
}


   function getMarket(uint256 _marketId)
    external
    view
    returns (
        uint256,
        string memory,
        string memory,
        string[] memory,
        uint256,
        address,
        address,
        MarketStatus,
        uint256,
        address
    )
{
    Market storage m = markets[_marketId];

    return (
        m.id,
        m.question,
        m.description,
        m.outcomes,
        m.resolutionTime,
        m.arbitrator,
        m.creator,
        m.status,
        m.totalVolume,
        m.tokenAddress
    );
}

}
