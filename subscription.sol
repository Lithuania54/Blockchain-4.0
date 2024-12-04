// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SubscriptionService {
    address public owner;
    
    enum Tier { Basic, Premium }
    uint256 public basicFee = 0.0000001 ether;
    uint256 public premiumFee = 0.0000005 ether;
    uint256 public basicInterval = 30 days;
    uint256 public premiumInterval = 90 days;
    uint256 public earlyRenewalDiscount = 10; // 10% discount
    
    mapping(address => uint256) public subscriptionExpiry;
    mapping(address => Tier) public subscriberTier;
    
    event SubscriptionRenewed(address indexed subscriber, uint256 expiryTimestamp, Tier tier);
    event NearExpiration(address indexed subscriber, uint256 timeRemaining);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function subscribe(Tier tier) external payable {
        uint256 fee = (tier == Tier.Basic) ? basicFee : premiumFee;
        uint256 interval = (tier == Tier.Basic) ? basicInterval : premiumInterval;
        
        require(msg.value == fee, "Exact subscription fee required");
        
        uint256 expiryTimestamp = subscriptionExpiry[msg.sender] > block.timestamp
            ? subscriptionExpiry[msg.sender] + interval
            : block.timestamp + interval;

        subscriptionExpiry[msg.sender] = expiryTimestamp;
        subscriberTier[msg.sender] = tier;

        emit SubscriptionRenewed(msg.sender, expiryTimestamp, tier);
    }

    function renewSubscription() external payable {
        require(subscriptionExpiry[msg.sender] > 0, "No active subscription found");
        
        uint256 timeRemaining = subscriptionExpiry[msg.sender] > block.timestamp
            ? subscriptionExpiry[msg.sender] - block.timestamp
            : 0;

        uint256 fee = (subscriberTier[msg.sender] == Tier.Basic) ? basicFee : premiumFee;
        uint256 interval = (subscriberTier[msg.sender] == Tier.Basic) ? basicInterval : premiumInterval;

        if (timeRemaining > 0) {
            uint256 discount = (fee * earlyRenewalDiscount) / 100;
            fee -= discount;
        }
        
        require(msg.value == fee, "Exact renewal fee required");
        
        uint256 expiryTimestamp = block.timestamp + interval;
        subscriptionExpiry[msg.sender] = expiryTimestamp;

        emit SubscriptionRenewed(msg.sender, expiryTimestamp, subscriberTier[msg.sender]);
    }

    function checkSubscription() external view returns (bool) {
        return block.timestamp <= subscriptionExpiry[msg.sender];
    }

    function checkNearExpiration() external {
        uint256 timeRemaining = subscriptionExpiry[msg.sender] > block.timestamp
            ? subscriptionExpiry[msg.sender] - block.timestamp
            : 0;
            
        if (timeRemaining <= 3 days) {
            emit NearExpiration(msg.sender, timeRemaining);
        }
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "Withdrawal failed");
    }
}
