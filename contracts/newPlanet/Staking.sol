pragma solidity ^0.6.2;

import './ShitBox.sol';
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC20/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/math/Math.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/utils/EnumerableSet.sol";


interface IStakingRewards {
    // Views
    function lastTimeRewardApplicable() external view returns (uint256);

    function rewardPerToken() external view returns (uint256);

    function earned(address account) external view returns (uint256);

    function getRewardForDuration() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    // Mutative

    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getReward() external;

    function exit() external;
}

// https://docs.synthetix.io/contracts/source/contracts/stakingrewards
contract StakingRewards is IStakingRewards {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    /* ========== STATE VARIABLES ========== */

    address public shitboxAddress = 0xe16DE80288618D6c159aDa57E32247114B185aD0;
    ShitBox shitbox = ShitBox(shitboxAddress);

     // TODO
    address _rewardsToken = address(0xa63190F5da411fFE60c0a70E9EAc95cCD5e626be);
    IERC20 public rewardsToken = IERC20(_rewardsToken);
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 365 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalMiningPower;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) public _ownerOf;
    
    mapping (address => EnumerableSet.UintSet) private _holderTokens;
    

    /* ========== CONSTRUCTOR ========== */
    address owner = address(0x0);
    
    modifier onlyOwner(){
        require(msg.sender == owner, "!owner");
        _;
    }

    constructor(
    ) public {
        owner = msg.sender;
    }

    /* ========== VIEWS ========== */
    
    function exit() external override{
        
    }
    
    function ownerOf(uint256 boxId) public view returns(address) {
        return _ownerOf[boxId];
    }
    
    function tokensOfOwner(address owner) public view returns(uint256[] memory ownerTokens) {
        uint256 tokenCount = _holderTokens[owner].length();

        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 resultIndex = 0;
            uint256 _tokenIdx;
            for (_tokenIdx = 0; _tokenIdx < tokenCount; _tokenIdx++) {
                result[resultIndex] = _holderTokens[owner].at(_tokenIdx);
                resultIndex++;
            }
            return result;
        }
    }

    function totalSupply() external override view returns (uint256) {
        return _totalMiningPower;
    }

    function balanceOf(address account) external override view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public override view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public override view returns (uint256) {
        if (_totalMiningPower == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalMiningPower)
            );
    }

    function earned(address account) public override view returns (uint256) {
        return _balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function getRewardForDuration() external override view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    function stake(uint256 boxId) external override updateReward(msg.sender) {
        uint256 miningPower = shitbox.getMiningPower(boxId);
        require(miningPower > 0, "0 mining power");

        shitbox.transferFrom(msg.sender, address(this), boxId);
        require(shitbox.ownerOf(boxId) == address(this),"transferFrom failed");
    
        _totalMiningPower = _totalMiningPower.add(miningPower);
        _balances[msg.sender] = _balances[msg.sender].add(miningPower);
        _ownerOf[boxId] = msg.sender;
        _holderTokens[msg.sender].add(boxId);
    }

    function withdraw(uint256 boxId) public override updateReward(msg.sender) {
        require(shitbox.ownerOf(boxId) == address(this));
        require(_ownerOf[boxId] == msg.sender);

        uint256 miningPower = shitbox.getMiningPower(boxId);
        _totalMiningPower = _totalMiningPower.sub(miningPower);
        _balances[msg.sender] = _balances[msg.sender].sub(miningPower);
        _ownerOf[boxId] = address(0x0);
        _holderTokens[msg.sender].remove(boxId);
        shitbox.transferFrom(address(this), msg.sender, boxId);
    }

    function getReward() public override updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
        }
    }

    function notifyRewardAmount(uint256 reward) external updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(rewardsDuration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance.div(rewardsDuration), "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
    }

    // End rewards emission earlier
    function updatePeriodFinish(uint timestamp) external onlyOwner updateReward(address(0)) {
        periodFinish = timestamp;
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(rewardsToken), "Cannot withdraw the rewards token");
        IERC20(tokenAddress).safeTransfer(owner, tokenAmount);
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(
            block.timestamp > periodFinish,
            "Previous rewards period must be complete before changing the duration for the new period"
        );
        rewardsDuration = _rewardsDuration;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }
}
