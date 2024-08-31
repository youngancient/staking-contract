// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// stake ETH and earn ERC20 Tokens as rewards
contract StakeEthers is ReentrancyGuard {
    error ZeroAddressError();
    error ZeroAmountDetected();
    error InSufficientFunds();
    error CantSendToZeroAddress();
    error NotAStakerError();
    error UnAuthorizedFunctionCall();
    error InsufficientRewardBalance();
    error StakingHasNotStarted();
    error StakingHasNotEnded();
    error FailedTransaction();
    error StakingWindowNotOpen();
    error CantEditStakingThatIsOn();
    error TooLargeStake();
    error CantStartStakingNow();

    address owner;
    bool hasStakingWindowOpened;
    bool hasStakingStarted;
    address tokenAddress; // ERC20 Token to be earned as reward
    uint public stakeDuration;
    uint public stakingLength;
    uint constant MAX_STAKE_VALUE = 50*1e18;
    uint exactTimeStakingStarted;
    uint totalStake;

    struct userStake {
        uint stakedAmount;
        uint rewardsClaimed;
        bool hasWithdrawnStake;
    }
    mapping(address => userStake) userRewardsMap;

    event RewardAddedSuccessfully(address _owner, uint indexed _reward);
    event StakingDurationSetSuccessfully(address _owner, uint _duration);
    event StakingWindowOpenedSuccessfully(bool indexed _hasStakingWindowOpened);
    event UserStakingSuccessful(address indexed _user, uint indexed _amount);
    event StakeWithdrawalSuccessful(
        address indexed _user,
        uint indexed _amount
    );

    constructor(address _tokenAddress) {
        owner = msg.sender;
        tokenAddress = _tokenAddress;
    }

    function sanityCheck(address _user) private pure {
        if (_user == address(0)) {
            revert ZeroAddressError();
        }
    }

    function zeroValue(uint _amount) private pure {
        if (_amount <= 0) {
            revert ZeroAmountDetected();
        }
    }

    function onlyOwner() private view {
        if (msg.sender != owner) {
            revert UnAuthorizedFunctionCall();
        }
    }

    function onlyStaker() private view {
        if (
            userRewardsMap[msg.sender].stakedAmount <= 0 &&
            userRewardsMap[msg.sender].rewardsClaimed <= 0
        ) {
            revert NotAStakerError();
        }
    }

    function checkCurrentTime() public view returns (uint) {
        return block.timestamp;
    }

    // token is of 18 decimals
    function addTokenRewards(uint _tokens) public {
        onlyOwner();
        zeroValue(_tokens);

        uint tokenContractBalance = IERC20(tokenAddress).balanceOf(owner);

        require(
            _tokens <= tokenContractBalance,
            "Insufficient CasToken!"
        );

        IERC20(tokenAddress).transferFrom(owner, address(this), _tokens);
        emit RewardAddedSuccessfully(owner, _tokens);
    }

    // @dev sets general staking duration in days
    function _setGeneralStakingDuration(uint _days) private {
        onlyOwner();
        if (hasStakingStarted) {
            revert CantEditStakingThatIsOn();
        }
        zeroValue(_days);
        // we convert the day to its equivalence in seconds
        // rewards given is per second
        // stakeDuration = (_days) + block.timestamp;   -> for testing
        stakeDuration = (_days * 1 days) + block.timestamp;
        exactTimeStakingStarted = block.timestamp;
        stakingLength = _days * 1 days;
        // stakingLength = _days;   -> for testing in secs
        hasStakingStarted = true;
        emit StakingDurationSetSuccessfully(owner, _days);
    }

    // check if staking duration has ended at the current time
    function checkIfStakingDurationHasEnded() public view returns (bool) {
        return block.timestamp >= stakeDuration;
    }

    // opens the window for users to start staking their ETH
    function openStakingWindow() public {
        onlyOwner();
        hasStakingWindowOpened = true;
        emit StakingWindowOpenedSuccessfully(hasStakingWindowOpened);
    }

    // ends the staking window and starts the actual staking
    function startStaking(uint _days) public {
        onlyOwner();
        if (hasStakingWindowOpened) {
            hasStakingWindowOpened = false;
            _setGeneralStakingDuration(_days);
        } else {
            revert CantStartStakingNow();
        }
    }

    // for owner to track contract balance when users start withdrawing after Staking ends
    function _getContractRewardsLeft() private view returns (uint) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function getOwnerContractRewardsLeft() public view returns (uint) {
        onlyOwner();
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    // users can stake only during the staking window
    function stake() public payable {
        if (!hasStakingWindowOpened) {
            revert StakingWindowNotOpen();
        }
        sanityCheck(msg.sender);
        zeroValue(msg.value);

        if (msg.value > MAX_STAKE_VALUE) {
            revert TooLargeStake();
        }
        // uint i = userRewardsMap[msg.sender].stakedBalance;
        userRewardsMap[msg.sender] = userStake(msg.value, 0, false);
        totalStake = totalStake + msg.value;

        emit UserStakingSuccessful(msg.sender, msg.value);
    }

    function getMyStakedAmount() public view returns (uint) {
        onlyStaker();
        return userRewardsMap[msg.sender].stakedAmount;
    }

    // withdraw
    function withdrawStake() public nonReentrant {
        onlyStaker();
        sanityCheck(msg.sender);
        if (!checkIfStakingDurationHasEnded()) {
            revert StakingHasNotEnded();
        }
        // general staking has ended
        hasStakingStarted = false;
        _endStaking();
    }

    function checkUnclaimedRewards() public view returns (uint) {
        sanityCheck(msg.sender);
        onlyStaker();
        return
            _calculateRewards(msg.sender) -
            userRewardsMap[msg.sender].rewardsClaimed;
    }

    function checkClaimedRewards() public view returns (uint) {
        onlyStaker();
        sanityCheck(msg.sender);
        return userRewardsMap[msg.sender].rewardsClaimed;
    }

    function claimRewards() public {
        onlyStaker();
        sanityCheck(msg.sender);
        uint unclaimedReward = checkUnclaimedRewards();
        zeroValue(unclaimedReward);
        userRewardsMap[msg.sender].rewardsClaimed += unclaimedReward;
        // send rewards

        IERC20(tokenAddress).transfer(msg.sender, unclaimedReward);
    }

    // calculates the cumuative rewards of any person at a time t
    function _calculateRewards(address _user) private view returns (uint) {
        uint totalRewards = _getContractRewardsLeft();
        if (totalRewards <= 0) {
            revert InsufficientRewardBalance();
        }
        uint timeSinceStake = block.timestamp - exactTimeStakingStarted;
        uint _amount;
        // if the duration has ended, calculate the full rewards
        if (checkIfStakingDurationHasEnded()) {
            _amount =
                (userRewardsMap[_user].stakedAmount * totalRewards) /
                (totalStake);
            return _amount;
        }
        // if the duration has ended, calculate rewards per second
        _amount =
            (userRewardsMap[_user].stakedAmount *
                totalRewards *
                timeSinceStake) /
            (totalStake * (stakingLength));
        return _amount;
    }

    function _endStaking() private {
        sanityCheck(msg.sender);
        uint _stakedAmount = userRewardsMap[msg.sender].stakedAmount;
        if (_stakedAmount <= 0) {
            revert ZeroAmountDetected();
        }
        userRewardsMap[msg.sender].stakedAmount = 0;

        // send ethers
        (bool success, ) = msg.sender.call{value: _stakedAmount}("");
        if (!success) {
            revert FailedTransaction();
        }
    }
}
