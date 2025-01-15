// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TokenStaking {
    event Stake(address indexed staker, uint256 amount, uint256 time);
    event Withdraw(address indexed staker, uint256 amount, uint256 rewards, uint256 time);

    IERC20 public immutable token;

    struct StakeInfo {
        uint256 amount; // Staked amount
        uint256 startTime; // Start time of staking
        uint256 rewards; // Accumulated rewards
    }

    mapping(address => StakeInfo) private stakes;
	uint256 private _remainingRewards;

    constructor(IERC20 token_, uint256 remainingRewards_) {
        token = token_;
		_remainingRewards = remainingRewards_;
    }

    // Stake tokens
    function stake(uint256 amount) external {
        require(amount > 0, "Stake amount must be greater than zero");

        StakeInfo storage stakeInfo = stakes[msg.sender];
        _updateRewards(msg.sender);
		
        token.transferFrom(msg.sender, address(this), amount);
        stakeInfo.amount += amount;
        stakeInfo.startTime = block.timestamp;

        emit Stake(msg.sender, amount, block.timestamp);
    }

    // Withdraw staked tokens and rewards
    function withdrawAll() external {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        _updateRewards(msg.sender);

        uint256 totalAmount = stakeInfo.amount + stakeInfo.rewards;
        require(totalAmount > 0, "Nothing to withdraw");

        // Check contract balance
        require(token.balanceOf(address(this)) >= totalAmount, "Contract balance insufficient");

        uint256 stakedAmount = stakeInfo.amount;
        uint256 rewardsAmount = stakeInfo.rewards;

        stakeInfo.amount = 0;
        stakeInfo.rewards = 0;
        stakeInfo.startTime = 0;

        token.approve(msg.sender, totalAmount);
        token.transfer(msg.sender, totalAmount);
        emit Withdraw(msg.sender, stakedAmount, rewardsAmount, block.timestamp);
    }

    // Withdraw only rewards
    function withdrawRewards() external {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        _updateRewards(msg.sender);

        uint256 rewards = stakeInfo.rewards;
        require(rewards > 0, "No rewards to withdraw");

        // Check contract balance
        require(token.balanceOf(address(this)) >= rewards, "Contract balance insufficient");

        stakeInfo.rewards = 0;

        token.approve(msg.sender, rewards);
        token.transfer(msg.sender, rewards);
        emit Withdraw(msg.sender, 0, rewards, block.timestamp);
    }

    // Withdraw only amount
    function withdrawAmount() external {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        _updateRewards(msg.sender);

        uint256 stakedAmount = stakeInfo.amount;
        require(stakedAmount > 0, "No amount to withdraw");

        // Check contract balance
        require(token.balanceOf(address(this)) >= stakedAmount, "Contract balance insufficient");

        stakeInfo.amount = 0;

        token.approve(msg.sender, stakedAmount);
        token.transfer(msg.sender, stakedAmount);
        emit Withdraw(msg.sender, stakedAmount, 0, block.timestamp);
    }	

    // Public view to check current rewards
    function currentRewards() public view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        if (stakeInfo.amount == 0) {
            return stakeInfo.rewards;
        }
        uint256 stakingRewardsCount = (block.timestamp - stakeInfo.startTime) / 3600;
        uint256 newRewards = (stakeInfo.amount * stakingRewardsCount) / 8760;
        return stakeInfo.rewards + newRewards;
    }

    // Public view to check current amount
    function currentAmount() public view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[msg.sender];
		return stakeInfo.amount;
    }	

	// Public view to check remaining rewards
    function remainingRewards() public view returns (uint256) {
		return _remainingRewards;
    }

    // Internal function to update rewards
    function _updateRewards(address staker) internal {
        StakeInfo storage stakeInfo = stakes[staker];
        if (stakeInfo.amount > 0) {
            uint256 stakingRewardsCount = (block.timestamp - stakeInfo.startTime) / 3600;
            uint256 newRewards = (stakeInfo.amount * stakingRewardsCount) / 8760;

			if (_remainingRewards >= newRewards) {
                stakeInfo.rewards += newRewards;
				_remainingRewards -= newRewards;
			}
			else {
                stakeInfo.rewards += _remainingRewards;
				_remainingRewards = 0;
			}
            stakeInfo.startTime = block.timestamp;
        }
    }
}
