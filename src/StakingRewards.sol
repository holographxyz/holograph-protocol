// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title StakingRewards - Auto-Compounding HLG Staking Contract
 * @notice Users stake HLG tokens and rewards automatically compound into their balance
 * @dev Uses MasterChef algorithm for O(1) reward distribution with auto-compounding
 *
 * KEY FEATURES:
 * - Stake HLG tokens to earn proportional rewards
 * - Rewards automatically compound (increase your stake balance)
 * - No separate claiming - must fully unstake to access rewards
 * - ALL incoming tokens are split according to configurable burn percentage (default 50% burn, 50% rewards)
 * - Works for both bootstrap (depositAndDistribute) and automated (addRewards) flows
 *
 * MASTERCHEF ALGORITHM:
 * - Global reward rate tracks cumulative rewards per token
 * - User debt tracks how much of the global rate they've already received
 * - When rewards are added: global rate increases
 * - When user interacts: pending rewards = (balance * (global_rate - user_debt)) / INDEX_PRECISION
 * - Pending rewards are added to user's balance (auto-compounding)
 */
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract StakingRewards is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /* -------------------------------------------------------------------------- */
    /*                                  Errors                                    */
    /* -------------------------------------------------------------------------- */
    error ZeroAmount();
    error ZeroAddress();
    error NoStake();
    error InsufficientBalance();
    error Unauthorized();
    error CannotRecoverStakeToken();
    error NoEtherAccepted();
    error InvalidCall();
    error FeeOnTransferNotSupported();
    error InsufficientToken();
    error EthTransferFailed();
    error InvalidBurnPercentage();

    /* -------------------------------------------------------------------------- */
    /*                                Constants                                    */
    /* -------------------------------------------------------------------------- */

    /// @notice Precision multiplier for reward calculations (MasterChef standard)
    uint256 private constant INDEX_PRECISION = 1e12;

    /// @notice Maximum percentage value in basis points (100%)
    uint256 public constant MAX_PERCENTAGE = 10000;

    /* -------------------------------------------------------------------------- */
    /*                                 Storage                                    */
    /* -------------------------------------------------------------------------- */

    /// @notice HLG token that users stake and receive as rewards
    IERC20 public immutable HLG;

    /// @notice Total HLG staked in the contract (includes compounded rewards)
    /// @dev This grows as rewards are distributed and auto-compound
    uint256 public totalStaked;

    /// @notice User stake balances (includes original stake + compounded rewards)
    /// @dev This automatically increases as rewards compound
    mapping(address => uint256) public balanceOf;

    /// @notice FeeRouter address (future automated rewards source)
    address public feeRouter;

    /// @notice Percentage of rewards that get burned (in basis points, 10000 = 100%)
    /// @dev Default is 5000 (50%), can be changed by owner
    uint256 public burnPercentage;

    /* -------------------------------------------------------------------------- */
    /*                        Auto-Compounding MasterChef State                   */
    /* -------------------------------------------------------------------------- */

    /// @notice Global cumulative reward index (scaled by INDEX_PRECISION for precision)
    /// @dev This increases when new rewards are added to the pool
    /// Formula: globalRewardIndex += (newRewards * INDEX_PRECISION) / totalStaked
    uint256 public globalRewardIndex;

    /// @notice Tracks each user's reward snapshot to prevent double-claiming
    /// @dev Updated after balance changes using: (userBalance * globalRewardIndex) / INDEX_PRECISION
    /// Formula: pendingRewards = (userBalance * (globalRewardIndex - userIndexSnapshot)) / INDEX_PRECISION
    mapping(address => uint256) public userIndexSnapshot;

    /// @notice Buffer for rewards received when no stakers are present
    /// @dev These rewards are distributed when the first user stakes
    uint256 public unallocatedBuffer;

    /* -------------------------------------------------------------------------- */
    /*                                  Events                                    */
    /* -------------------------------------------------------------------------- */
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event EmergencyExit(address indexed user, uint256 amount);
    event RewardsCompounded(address indexed user, uint256 rewardAmount);
    event RewardsDistributed(uint256 totalAmount, uint256 burnAmount, uint256 rewardAmount);
    event FeeRouterUpdated(address indexed newFeeRouter);
    event BurnPercentageUpdated(uint256 oldPercentage, uint256 newPercentage);
    event TokensRecovered(address indexed token, uint256 amount, address indexed to);
    event EthSwept(uint256 amount, address indexed to);

    /* -------------------------------------------------------------------------- */
    /*                               Constructor                                  */
    /* -------------------------------------------------------------------------- */
    constructor(address _hlg, address _owner) Ownable(_owner) {
        if (_hlg == address(0)) revert ZeroAddress();
        HLG = IERC20(_hlg);
        burnPercentage = 5000; // Default to 50% burn, 50% rewards
        _pause(); // Start paused until ready
    }

    /* -------------------------------------------------------------------------- */
    /*                              User Functions                                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Stake HLG tokens to earn auto-compounding rewards
     * @dev Rewards automatically compound into your balance - no separate claiming needed
     * @param amount Amount of HLG to stake
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        // Auto-compound any pending rewards first
        updateUser(msg.sender);

        // Transfer tokens from user with fee-on-transfer protection
        uint256 balanceBefore = HLG.balanceOf(address(this));
        HLG.safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfter = HLG.balanceOf(address(this));
        uint256 actualAmount = balanceAfter - balanceBefore;

        if (actualAmount != amount) revert FeeOnTransferNotSupported();

        // Handle case where this is the first staker and we have buffered rewards
        bool isFirstStaker = (totalStaked == 0);

        // Add new stake to user's balance
        balanceOf[msg.sender] += actualAmount;
        totalStaked += actualAmount;

        // If first staker and we have buffered rewards, give them all to first staker as genesis bonus
        if (isFirstStaker && unallocatedBuffer > 0) {
            uint256 bufferedRewards = unallocatedBuffer;
            unallocatedBuffer = 0;

            // Give all buffered rewards to the first staker as genesis bonus
            balanceOf[msg.sender] += bufferedRewards;
            totalStaked += bufferedRewards;

            emit RewardsCompounded(msg.sender, bufferedRewards);
        }

        // Update user's snapshot to current index (important for new stakers)
        userIndexSnapshot[msg.sender] = globalRewardIndex;

        emit Staked(msg.sender, actualAmount);
    }

    /**
     * @notice Unstake entire HLG balance including all accumulated rewards
     * @dev Must unstake full balance - this is the only way to access your rewards
     * @dev Your balance includes original stake + all auto-compounded rewards
     * @dev Can be called even when paused to allow exits during emergencies
     */
    function unstake() external nonReentrant {
        // Auto-compound any pending rewards first
        updateUser(msg.sender);

        uint256 userBalance = balanceOf[msg.sender];
        if (userBalance == 0) revert NoStake();

        // Reset user's state
        balanceOf[msg.sender] = 0;
        userIndexSnapshot[msg.sender] = 0; // Reset snapshot
        totalStaked -= userBalance;

        // Transfer full balance (original stake + compounded rewards)
        HLG.safeTransfer(msg.sender, userBalance);
        emit Unstaked(msg.sender, userBalance);
    }

    /**
     * @notice Emergency exit without claiming rewards (like MasterChef emergencyWithdraw)
     * @dev Withdraws only the original stake amount, forfeiting any pending rewards
     * @dev Can be called even when paused for emergency situations
     */
    function emergencyExit() external nonReentrant {
        uint256 userBalance = balanceOf[msg.sender];
        if (userBalance == 0) revert NoStake();

        // Reset user's state without updating rewards
        balanceOf[msg.sender] = 0;
        userIndexSnapshot[msg.sender] = 0;
        totalStaked -= userBalance;

        // Transfer balance without compounding rewards (emergency exit)
        HLG.safeTransfer(msg.sender, userBalance);
        emit EmergencyExit(msg.sender, userBalance);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Bootstrap Operations                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Deposit HLG and distribute according to burn/reward percentage split
     * @dev Used for manual bootstrap operations before FeeRouter integration
     * @param hlgAmount Total HLG to process (will be split according to burnPercentage)
     */
    function depositAndDistribute(uint256 hlgAmount) external onlyOwner nonReentrant {
        if (hlgAmount == 0) revert ZeroAmount();

        // Transfer HLG from caller with fee-on-transfer protection
        uint256 balanceBefore = HLG.balanceOf(address(this));
        HLG.safeTransferFrom(msg.sender, address(this), hlgAmount);
        uint256 balanceAfter = HLG.balanceOf(address(this));
        uint256 actualAmount = balanceAfter - balanceBefore;

        if (actualAmount != hlgAmount) revert FeeOnTransferNotSupported();

        // Calculate burn/reward split based on burnPercentage
        uint256 burnAmount = (actualAmount * burnPercentage) / MAX_PERCENTAGE;
        uint256 rewardAmount = actualAmount - burnAmount;

        // NOTE: HLG (0x740df024CE73f589ACD5E8756b377ef8C6558BaB) exposes burn/burnFrom,
        // but they require an allowance. Using transfer(address(0)) is universally safe
        // and still decreases total supply onchain (see HLG implementation).
        HLG.safeTransfer(address(0), burnAmount);

        // Distribute the remaining portion as auto-compounding rewards
        _addRewards(rewardAmount);

        // Emit event after state changes for consistent indexing
        emit RewardsDistributed(actualAmount, burnAmount, rewardAmount);
    }

    /* -------------------------------------------------------------------------- */
    /*                      Future Automated Integration                          */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Add rewards from FeeRouter (automated flow)
     * @dev Handles burn/reward distribution according to burnPercentage, same as manual bootstrap
     * @param amount Total amount of HLG to process (will be split according to burnPercentage)
     */
    function addRewards(uint256 amount) external nonReentrant {
        if (msg.sender != feeRouter) revert Unauthorized();
        if (amount == 0) revert ZeroAmount();

        // Transfer HLG from FeeRouter with fee-on-transfer protection
        uint256 balanceBefore = HLG.balanceOf(address(this));
        HLG.safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfter = HLG.balanceOf(address(this));
        uint256 actualAmount = balanceAfter - balanceBefore;

        if (actualAmount != amount) revert FeeOnTransferNotSupported();

        // Calculate burn/reward split based on burnPercentage
        uint256 burnAmount = (actualAmount * burnPercentage) / MAX_PERCENTAGE;
        uint256 rewardAmount = actualAmount - burnAmount;

        // NOTE: HLG (0x740dF024Ce73F589AcD5E8756B377eF8C6558BaB) exposes burn/burnFrom,
        // but they require an allowance. Using transfer(address(0)) is universally safe
        // and still decreases total supply onchain (see HLG implementation).
        HLG.safeTransfer(address(0), burnAmount);

        // Distribute remaining portion as auto-compounding rewards
        _addRewards(rewardAmount);

        // Emit event after state changes for consistent indexing
        emit RewardsDistributed(actualAmount, burnAmount, rewardAmount);
    }

    /* -------------------------------------------------------------------------- */
    /*                      Core Auto-Compounding Functions                       */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Update user's reward state and auto-compound pending rewards
     * @dev Uses MasterChef V2 algorithm with 1e12 precision for gas efficiency
     * @param account Address to update rewards for
     */
    function updateUser(address account) public {
        uint256 userBalance = balanceOf[account];
        if (userBalance > 0) {
            // Calculate pending rewards using MasterChef V2 formula
            // pendingRewards = userBalance * (globalRewardIndex - userIndexSnapshot) / INDEX_PRECISION
            uint256 pendingRewards = (userBalance * (globalRewardIndex - userIndexSnapshot[account])) / INDEX_PRECISION;

            if (pendingRewards > 0) {
                // Auto-compound: add rewards directly to user's balance
                balanceOf[account] += pendingRewards;

                // Update total staked to account for compounded rewards
                totalStaked += pendingRewards;

                emit RewardsCompounded(account, pendingRewards);
            }
        }

        // Update user's snapshot to current global index (prevents double-claiming)
        userIndexSnapshot[account] = globalRewardIndex;
    }

    /**
     * @notice Add rewards to the pool with buffer-aware distribution
     * @dev Handles the case where no stakers exist by using unallocated buffer
     * @param rewardAmount Amount of HLG rewards to distribute to stakers
     */
    function _addRewards(uint256 rewardAmount) internal {
        if (rewardAmount == 0) return;

        // Handle unallocated buffer first (rewards received when no stakers)
        if (unallocatedBuffer > 0 && totalStaked > 0) {
            // Distribute previously buffered rewards now that we have stakers
            uint256 bufferedRewards = unallocatedBuffer;
            unallocatedBuffer = 0;

            // Update global index with buffered rewards
            globalRewardIndex += (bufferedRewards * INDEX_PRECISION) / totalStaked;
        }

        if (totalStaked == 0) {
            // No stakers - add to buffer for later distribution
            unallocatedBuffer += rewardAmount;
            return;
        }

        // Update global reward index using MasterChef V2 formula with 1e12 precision
        globalRewardIndex += (rewardAmount * INDEX_PRECISION) / totalStaked;
    }

    /* -------------------------------------------------------------------------- */
    /*                              View Functions                                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Calculate pending rewards for a user (not yet compounded)
     * @dev Shows rewards that would be compounded into balance on next interaction
     * @param account Address to check pending rewards for
     * @return Amount of pending auto-compound rewards
     */
    function earned(address account) external view returns (uint256) {
        uint256 accountBalance = balanceOf[account];
        if (accountBalance == 0) return 0;

        // Calculate pending rewards using MasterChef V2 formula with 1e12 precision
        return (accountBalance * (globalRewardIndex - userIndexSnapshot[account])) / INDEX_PRECISION;
    }

    /**
     * @notice Get current global reward index
     * @dev This index increases as rewards are added to the pool
     * @return Current global reward index (scaled by INDEX_PRECISION = 1e12)
     */
    function rewardPerToken() external view returns (uint256) {
        return globalRewardIndex;
    }

    /**
     * @notice Get user's share of total staked pool
     * @param user Address to check
     * @return User's percentage share in basis points (10000 = 100%)
     */
    function getUserShare(address user) external view returns (uint256) {
        if (totalStaked == 0) return 0;
        return (balanceOf[user] * 10000) / totalStaked;
    }

    /**
     * @notice Calculate user's total balance including pending rewards
     * @dev This is what they would receive if they unstaked right now
     * @param user Address to check
     * @return Total balance (current stake + pending compounded rewards)
     */
    function balanceWithPendingRewards(address user) external view returns (uint256) {
        uint256 currentBalance = balanceOf[user];
        uint256 pendingRewards = this.earned(user);
        return currentBalance + pendingRewards;
    }

    /**
     * @notice Get available rewards in contract ready for distribution
     * @dev Contract balance minus total staked amounts
     * @return Amount of HLG available for future reward distributions
     */
    function getAvailableRewards() external view returns (uint256) {
        uint256 contractBalance = HLG.balanceOf(address(this));
        return contractBalance > totalStaked ? contractBalance - totalStaked : 0;
    }

    /* -------------------------------------------------------------------------- */
    /*                              Admin Functions                               */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Set FeeRouter address for future automation
     * @param _feeRouter New FeeRouter address
     */
    function setFeeRouter(address _feeRouter) external onlyOwner {
        if (_feeRouter == address(0)) revert ZeroAddress();
        feeRouter = _feeRouter;
        emit FeeRouterUpdated(_feeRouter);
    }

    /**
     * @notice Set burn percentage for reward distribution
     * @param _burnPercentage Percentage of rewards to burn (in basis points, 10000 = 100%)
     * @dev Remaining percentage (10000 - _burnPercentage) goes to stakers as rewards
     */
    function setBurnPercentage(uint256 _burnPercentage) external onlyOwner {
        if (_burnPercentage > MAX_PERCENTAGE) revert InvalidBurnPercentage();

        uint256 oldPercentage = burnPercentage;
        burnPercentage = _burnPercentage;

        emit BurnPercentageUpdated(oldPercentage, _burnPercentage);
    }

    /**
     * @notice Pause staking operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause staking operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency function to recover tokens (not HLG)
     * @dev Useful if someone accidentally sends wrong tokens to this contract
     * @param token Token address to recover
     * @param to Address to send recovered tokens to
     * @param amountMinimum Minimum amount that must be available to recover
     */
    function recoverToken(address token, address to, uint256 amountMinimum) external onlyOwner nonReentrant {
        if (token == address(HLG)) revert CannotRecoverStakeToken();
        if (to == address(0)) revert ZeroAddress();

        uint256 amount = IERC20(token).balanceOf(address(this));
        if (amount < amountMinimum) revert InsufficientToken();

        IERC20(token).safeTransfer(to, amount);
        emit TokensRecovered(token, amount, to);
    }

    /**
     * @notice Sweep ETH that may have been force-sent to the contract
     * @dev Protects against selfdestruct attacks that force ETH into the contract
     * @param to Address to send the ETH to
     */
    function sweepETH(address payable to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();

        uint256 balance = address(this).balance;
        if (balance == 0) revert ZeroAmount();

        (bool success,) = to.call{value: balance}("");
        if (!success) revert EthTransferFailed();

        emit EthSwept(balance, to);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Fallback Functions                              */
    /* -------------------------------------------------------------------------- */

    /// @notice Reject direct ETH transfers (but allow forced transfers from selfdestruct)
    receive() external payable {
        revert NoEtherAccepted();
    }

    /// @notice Reject fallback calls
    fallback() external payable {
        revert InvalidCall();
    }
}
