// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVendingMachine {
    address public owner;
    address public charityFoundation;
    IERC20 public tokenToDispense;
    
    uint256 public pricePerToken; 
    uint256 public tokensPerSale;
    uint256 public freeFollowerAmount; 
    
    uint256 public totalTokensCreated;
    uint256 public totalTokensSold;
    uint256 public totalFreeClaimed;
    uint256 public totalDonationsCollected;

    mapping(address => bool) public hasClaimedFree;
    mapping(bytes32 => bool) public validClaimCodes;

    event TokensPurchased(address indexed buyer, uint256 amountPaid, uint256 tokensReceived);
    event FollowerClaimed(address indexed follower, uint256 tokensReceived);

    constructor(
        address _tokenAddress, 
        address _charityFoundation,
        uint256 _pricePerToken, 
        uint256 _tokensPerSale,
        uint256 _freeFollowerAmount,
        uint256 _totalCreated
    ) {
        owner = msg.sender;
        charityFoundation = _charityFoundation;
        tokenToDispense = IERC20(_tokenAddress);
        pricePerToken = _pricePerToken;
        tokensPerSale = _tokensPerSale;
        freeFollowerAmount = _freeFollowerAmount;
        totalTokensCreated = _totalCreated;
    }

    function addClaimCode(string memory _code) external {
        require(msg.sender == owner, "Only owner");
        validClaimCodes[keccak256(abi.encodePacked(_code))] = true;
    }

    function buyTokens() external payable {
        require(msg.value >= pricePerToken, "Insufficient native currency sent");
        require(tokenToDispense.balanceOf(address(this)) >= tokensPerSale, "Out of tokens");

        totalTokensSold += tokensPerSale;
        totalDonationsCollected += msg.value;

        // 90% to owner wallet, 10% stays for gas/maintenance operations
        uint256 ownerCut = (msg.value * 90) / 100;
        uint256 foundationCut = msg.value - ownerCut;

        (bool sentOwner, ) = payable(owner).call{value: ownerCut}("");
        require(sentOwner, "Owner transfer failed");

        (bool sentCharity, ) = payable(charityFoundation).call{value: foundationCut}("");
        require(sentCharity, "Foundation transfer failed");

        bool success = tokenToDispense.transfer(msg.sender, tokensPerSale);
        require(success, "Token transfer failed");

        emit TokensPurchased(msg.sender, msg.value, tokensPerSale);
    }

    function claimFreeTokens(string memory _code) external {
        bytes32 codeHash = keccak256(abi.encodePacked(_code));
        require(validClaimCodes[codeHash], "Invalid follower code");
        require(!hasClaimedFree[msg.sender], "Already claimed free tokens");
        require(tokenToDispense.balanceOf(address(this)) >= freeFollowerAmount, "Out of tokens");

        hasClaimedFree[msg.sender] = true;
        totalFreeClaimed += freeFollowerAmount;

        bool success = tokenToDispense.transfer(msg.sender, freeFollowerAmount);
        require(success, "Free transfer failed");

        emit FollowerClaimed(msg.sender, freeFollowerAmount);
    }
}
