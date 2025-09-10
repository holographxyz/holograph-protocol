// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title StakingRewards
 * @notice HLG staking with epoch-gated eligibility, automatic reward compounding, and configurable burn/reward split.
 * @dev
 * - Rewards compound automatically using a dual-index model:
 *   - `currentEpochRewardIndex` accrues rewards for the ongoing epoch using `eligibleTotal` as denominator
 *   - `globalRewardIndex` accumulates rewards of all fully-completed epochs
 * - Epochs are 7 days. Stakes activate next epoch; withdrawals finalize next epoch.
 * - Distributions are allowed while paused. Staking is blocked while paused.
 * - Extra HLG tokens sent directly to the contract can be recovered with `recoverExtraHLG`.
 * - If no eligible stake exists, reward distributions are skipped to save gas.
 * - Token burning works by calling ERC20Burnable burn. The HLG token at
 *   0x740dF024Ce73F589AcD5E8756B377eF8C6558BaB reduces its total supply when tokens are burned.
 */
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
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
    error Unauthorized();
    error CannotRecoverStakeToken();
    error NoEtherAccepted();
    error InvalidCall();
    error FeeOnTransferNotSupported();
    error InsufficientToken();
    error EthTransferFailed();
    error InvalidBurnPercentage();
    error ArrayLengthMismatch();
    error EndIndexOutOfBounds();
    error InvalidIndexRange();
    error NoTokensReceived();
    error NotWhitelistedDistributor();
    error BurnFailed();
    error NotEnoughExtraTokens();
    error NotEnoughRewardsAvailable();
    error ActiveStakeExists();
    error RewardTooSmall();
    error PendingWithdrawalExists();

    /* -------------------------------------------------------------------------- */
    /*                                  Storage                                   */
    /* -------------------------------------------------------------------------- */

    /// @notice Precision multiplier for reward calculations (1e12 scaling)
    uint256 private constant INDEX_PRECISION = 1e12;

    /// @notice Maximum percentage value in basis points (100%)
    uint256 public constant MAX_PERCENTAGE = 10000;

    /// @notice HLG token that users stake and receive as rewards
    IERC20 public immutable HLG;

    /// @notice Total HLG staked in the contract (includes compounded rewards)
    uint256 public totalStaked;

    /// @notice Count of unique addresses with nonzero stake
    uint256 public totalStakers;

    /// @notice User stake balances (includes original stake + compounded rewards)
    mapping(address => uint256) public balanceOf;

    /// @notice FeeRouter address (future automated rewards source)
    address public feeRouter;

    /// @notice Percentage of rewards that get burned (in basis points, 10000 = 100%)
    uint256 public burnPercentage;

    /// @notice Global cumulative reward index (scaled by INDEX_PRECISION for precision)
    uint256 public globalRewardIndex;

    /// @notice Tracks each user's reward snapshot to prevent double-claiming
    mapping(address => uint256) public userIndexSnapshot;

    /// @notice Rewards that have been distributed but not yet claimed by users
    uint256 public unallocatedRewards;

    /// @notice Registry of approved distributors (Merkle drop contracts, quest engines, etc.)
    mapping(address => bool) public isDistributor;

    /* -------------------------------------------------------------------------- */
    /*                          Epochs and Eligibility                            */
    /* -------------------------------------------------------------------------- */

    /// @notice Duration of a single epoch
    uint256 public constant EPOCH_DURATION = 7 days;

    /// @notice Timestamp when epoch 0 starts (set on first unpause)
    uint256 public epochStartTime;

    /// @notice Last matured epoch number (globalRewardIndex contains all deltas up to this epoch)
    uint256 public lastProcessedEpoch;

    /// @notice Accumulated reward-per-eligible-token for the currently ongoing epoch
    uint256 public currentEpochRewardIndex;

    /// @notice Total amount of tokens eligible for the current epoch's rewards
    uint256 public eligibleTotal;

    /// @notice Aggregate stake additions to apply on next epoch roll
    uint256 public scheduledAdditionsNextEpoch;

    /// @notice Aggregate stake removals to apply on next epoch roll
    uint256 public scheduledRemovalsNextEpoch;

    /// @notice Per-user eligible balance participating in the current epoch
    mapping(address => uint256) public eligibleBalanceOf;

    /// @notice Per-user amount scheduled to become eligible next epoch
    mapping(address => uint256) public pendingActivationAmount;

    /// @notice Epoch at which the pending activation takes effect
    mapping(address => uint256) public pendingActivationEpoch;

    /// @notice Per-user full-withdrawal amount scheduled to be withdrawable next epoch
    mapping(address => uint256) public pendingWithdrawalAmount;

    /// @notice Epoch when the scheduled withdrawal becomes eligible to finalize
    mapping(address => uint256) public pendingWithdrawalEpoch;

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
    event DistributorUpdated(address indexed distributor, bool status);
    event BoostedStake(address indexed distributor, address indexed user, uint256 amount);
    event UnstakeScheduled(address indexed user, uint256 amount, uint256 availableEpoch);
    event EpochAdvanced(uint256 indexed newEpoch, uint256 maturedIndexDelta, uint256 newEligibleTotal);
    event StakeActivated(address indexed user, uint256 amount, uint256 epoch);
    event EpochInitialized(uint256 startTime);
    event AccountingError(string reason, uint256 removals, uint256 eligibleBefore);

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
    /*                                    User                                    */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Stake HLG tokens to earn auto-compounding rewards
     * @param amount Amount of HLG to stake
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        _advanceEpoch();
        if (pendingWithdrawalAmount[msg.sender] != 0) revert PendingWithdrawalExists();

        uint256 actualAmount = _pullHLG(msg.sender, amount);
        updateUser(msg.sender);

        // Track new staker
        if (balanceOf[msg.sender] == 0) {
            totalStakers++;
        }

        balanceOf[msg.sender] += actualAmount;
        totalStaked += actualAmount;

        // Schedule activation next epoch
        uint256 activationEpoch = _currentEpoch() + 1;
        pendingActivationAmount[msg.sender] += actualAmount;
        pendingActivationEpoch[msg.sender] = activationEpoch;
        scheduledAdditionsNextEpoch += actualAmount;

        emit Staked(msg.sender, actualAmount);
    }

    /**
     * @notice Unstake entire HLG balance including all accumulated rewards
     * @dev Auto-compounds first, then transfers full balance. Can be called while paused.
     */
    function unstake() external nonReentrant {
        _advanceEpoch();
        updateUser(msg.sender);

        uint256 userBalance = balanceOf[msg.sender];
        if (userBalance == 0) revert NoStake();
        if (pendingWithdrawalAmount[msg.sender] != 0) revert PendingWithdrawalExists();

        // Cancel any scheduled activation for next epoch (e.g. recent stake or compounded rewards)
        uint256 pendingAdd = pendingActivationAmount[msg.sender];
        if (pendingAdd != 0) {
            scheduledAdditionsNextEpoch -= pendingAdd;
            pendingActivationAmount[msg.sender] = 0;
            pendingActivationEpoch[msg.sender] = 0;
        }

        // Schedule removal of the user's currently eligible balance to take effect next epoch
        uint256 nextEpoch = _currentEpoch() + 1;
        uint256 eligibleAmt = eligibleBalanceOf[msg.sender];
        if (eligibleAmt != 0) {
            scheduledRemovalsNextEpoch += eligibleAmt;
        }
        pendingWithdrawalAmount[msg.sender] = userBalance;
        pendingWithdrawalEpoch[msg.sender] = nextEpoch;

        emit UnstakeScheduled(msg.sender, userBalance, nextEpoch);
    }

    function finalizeUnstake() external nonReentrant {
        _advanceEpoch();
        updateUser(msg.sender);

        uint256 amt = pendingWithdrawalAmount[msg.sender];
        if (amt == 0) revert NoStake();
        if (_currentEpoch() < pendingWithdrawalEpoch[msg.sender]) revert ActiveStakeExists();

        // Zero out eligible balance and user state; transfer principal + compounded
        balanceOf[msg.sender] = 0;
        eligibleBalanceOf[msg.sender] = 0;
        userIndexSnapshot[msg.sender] = globalRewardIndex;
        pendingWithdrawalAmount[msg.sender] = 0;
        pendingWithdrawalEpoch[msg.sender] = 0;
        totalStaked -= amt;
        unchecked {
            totalStakers -= 1;
        }
        HLG.safeTransfer(msg.sender, amt);
        emit Unstaked(msg.sender, amt);
    }

    /**
     * @notice Emergency exit without compounding pending rewards
     * @dev Does not call updateUser; returns current recorded balance. Can be called while paused.
     */
    function emergencyExit() external nonReentrant {
        _advanceEpoch();
        // Do not compound; schedule exit for next epoch for invariant simplicity
        uint256 userBalance = balanceOf[msg.sender];
        if (userBalance == 0) revert NoStake();
        if (pendingWithdrawalAmount[msg.sender] != 0) revert PendingWithdrawalExists();

        // Cancel any scheduled activation for next epoch
        uint256 pendingAdd = pendingActivationAmount[msg.sender];
        if (pendingAdd != 0) {
            uint256 activationEpoch = pendingActivationEpoch[msg.sender];
            // If activation is still pending in a future epoch, remove it from schedule
            if (activationEpoch > lastProcessedEpoch) {
                scheduledAdditionsNextEpoch -= pendingAdd;
            }
            // If activation has matured but user never activated, schedule removal of ghost eligibility
            else if (activationEpoch <= lastProcessedEpoch) {
                scheduledRemovalsNextEpoch += pendingAdd;
            }
            // In all cases, clear the per-user pending activation state
            pendingActivationAmount[msg.sender] = 0;
            pendingActivationEpoch[msg.sender] = 0;
        }

        // Schedule removal of eligible balance next epoch
        uint256 nextEpoch = _currentEpoch() + 1;
        uint256 eligibleAmt = eligibleBalanceOf[msg.sender];
        if (eligibleAmt != 0) {
            scheduledRemovalsNextEpoch += eligibleAmt;
        }
        pendingWithdrawalAmount[msg.sender] = userBalance;
        pendingWithdrawalEpoch[msg.sender] = nextEpoch;

        emit EmergencyExit(msg.sender, userBalance);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Funding                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Deposit HLG and distribute according to burn/reward split.
     * @param hlgAmount HLG to pull from caller
     * @dev Splits burn/reward and updates the index. If there are no stakers,
     *      this call is a no-op.
     */
    function depositAndDistribute(uint256 hlgAmount) external onlyOwner nonReentrant {
        _advanceEpoch();
        uint256 eligible = eligibleTotal;
        if (eligible == 0) return;
        if (hlgAmount == 0) revert ZeroAmount();

        // Pull tokens first to get the exact received amount
        uint256 received = _pullHLG(msg.sender, hlgAmount);
        uint256 burnAmount = (received * burnPercentage) / MAX_PERCENTAGE;
        uint256 rewardAmount = received - burnAmount;

        // If there is a positive rewardAmount, ensure it will move the index
        if (rewardAmount > 0) {
            uint256 indexDelta = (rewardAmount * INDEX_PRECISION) / eligible;
            if (indexDelta == 0) revert RewardTooSmall();
            _addRewards(rewardAmount, indexDelta);
        }

        // Perform burn after validation to avoid partial side effects on revert
        _burnHLG(burnAmount);

        emit RewardsDistributed(received, burnAmount, rewardAmount);
    }

    /**
     * @notice Add rewards from FeeRouter (automated flow).
     * @param amount HLG to pull from FeeRouter
     * @dev Splits burn/reward and updates the index. If there are no stakers,
     *      this call is a no-op.
     */
    function addRewards(uint256 amount) external nonReentrant {
        if (msg.sender != feeRouter) revert Unauthorized();
        _advanceEpoch();
        uint256 eligible = eligibleTotal;
        if (eligible == 0) return;
        if (amount == 0) revert ZeroAmount();

        // Pull tokens first to get the exact received amount
        uint256 received = _pullHLG(msg.sender, amount);
        uint256 burnAmount = (received * burnPercentage) / MAX_PERCENTAGE;
        uint256 rewardAmount = received - burnAmount;

        // If there is a positive rewardAmount, ensure it will move the index
        if (rewardAmount > 0) {
            uint256 indexDelta = (rewardAmount * INDEX_PRECISION) / eligible;
            if (indexDelta == 0) revert RewardTooSmall();
            _addRewards(rewardAmount, indexDelta);
        }

        // Perform burn after validation to avoid partial side effects on revert
        _burnHLG(burnAmount);

        emit RewardsDistributed(received, burnAmount, rewardAmount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internals                                 */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Get active staked amount (excluding unallocated rewards)
     * @return Amount of HLG actively staked by users
     */
    function _activeStaked() internal view returns (uint256) {
        return totalStaked - unallocatedRewards;
    }

    /**
     * @notice Internal helper to pull HLG tokens with safety checks
     * @dev Rejects fee-on-transfer tokens; requires exact amount received
     * @param from Address to pull tokens from
     * @param amount Expected amount to receive
     * @return actualAmount Amount actually received (equals amount or reverts)
     */
    function _pullHLG(address from, uint256 amount) internal returns (uint256 actualAmount) {
        uint256 balanceBefore = HLG.balanceOf(address(this));
        HLG.safeTransferFrom(from, address(this), amount);
        uint256 balanceAfter = HLG.balanceOf(address(this));
        actualAmount = balanceAfter - balanceBefore;
        if (actualAmount == 0) revert NoTokensReceived();
        if (actualAmount != amount) revert FeeOnTransferNotSupported();
    }

    /**
     * @notice Updates reward state for an account, compounding any pending amount.
     * @dev Sets the snapshot to the current index after compounding.
     * @param account Address to update rewards for
     */
    function updateUser(address account) public {
        _advanceEpoch();
        _updateUserWithoutEpochAdvance(account);
    }

    /**
     * @dev Internal utility to update a user's state without advancing epochs.
     *      Used to avoid redundant epoch advances in batch flows.
     */
    function _updateUserWithoutEpochAdvance(address account) internal {
        // Read index/snapshot first for consistent compounding window
        uint256 currentIndex = globalRewardIndex;
        uint256 snapshot = userIndexSnapshot[account];

        // Compute compounding base as eligibility from prior matured epochs.
        // Include pending activation amount only if it matured before the last processed epoch.
        uint256 eligibleForCompounding = eligibleBalanceOf[account];
        uint256 activationEpoch = pendingActivationEpoch[account];
        uint256 cachedActivationAmount = pendingActivationAmount[account];
        if (activationEpoch != 0 && activationEpoch < lastProcessedEpoch) {
            eligibleForCompounding += cachedActivationAmount;
        }

        // Single activation point: activate if pending activation is for a matured epoch (<=)
        if (activationEpoch != 0 && activationEpoch <= lastProcessedEpoch) {
            uint256 activationAmount = cachedActivationAmount;
            if (activationAmount != 0) {
                eligibleBalanceOf[account] += activationAmount;
                pendingActivationAmount[account] = 0;
                pendingActivationEpoch[account] = 0;
                emit StakeActivated(account, activationAmount, activationEpoch);
            }
        }

        // Determine if user has a withdrawal that is active this epoch
        uint256 withdrawalEpoch = pendingWithdrawalEpoch[account];
        bool withdrawalActive = (withdrawalEpoch != 0 && _currentEpoch() >= withdrawalEpoch);

        // Compound matured rewards using the computed eligibility base
        if (eligibleForCompounding != 0 && !withdrawalActive) {
            uint256 indexDelta = currentIndex - snapshot;
            if (indexDelta != 0) {
                uint256 pendingRewards = (eligibleForCompounding * indexDelta) / INDEX_PRECISION;
                if (pendingRewards != 0) {
                    uint256 unallocated = unallocatedRewards;
                    if (pendingRewards > unallocated) revert NotEnoughRewardsAvailable();

                    // Increase principal balance
                    balanceOf[account] += pendingRewards;
                    unallocatedRewards = unallocated - pendingRewards;

                    // Schedule compounded rewards to become eligible next epoch
                    uint256 nextEpoch = _currentEpoch() + 1;
                    pendingActivationAmount[account] += pendingRewards;
                    pendingActivationEpoch[account] = nextEpoch;
                    scheduledAdditionsNextEpoch += pendingRewards;

                    emit RewardsCompounded(account, pendingRewards);
                }
            }
        }

        // Deactivate eligibility if withdrawal epoch reached
        if (withdrawalActive) {
            eligibleBalanceOf[account] = 0;
        }

        // Update snapshot to current index
        userIndexSnapshot[account] = currentIndex;
    }

    /**
     * @notice Safely burn HLG tokens with supply reduction verification
     * @param amount Amount of HLG to burn
     */
    function _burnHLG(uint256 amount) internal {
        if (amount == 0) return;

        // HolographERC20 has a burn() function that burns from msg.sender
        // At this point, the tokens have been pulled to this contract via _pullHLG
        uint256 supplyBefore = HLG.totalSupply();

        // Cast to ERC20Burnable interface and burn from this contract's balance
        ERC20Burnable(address(HLG)).burn(amount);
        uint256 supplyAfter = HLG.totalSupply();

        // Verify supply was reduced by the burn amount
        if (supplyBefore != supplyAfter + amount) revert BurnFailed();
    }

    /**
     * @notice Add rewards to the pool for immediate distribution
     * @param rewardAmount Amount of HLG rewards to distribute to stakers
     */
    function _addRewards(uint256 rewardAmount, uint256 indexDelta) internal {
        if (rewardAmount == 0) return;
        // Accrue into current epoch index; do not touch globalRewardIndex here
        currentEpochRewardIndex += indexDelta;
        // Track the full reward amount for distribution to users
        unallocatedRewards += rewardAmount;
        totalStaked += rewardAmount;
    }

    /// @notice Get current epoch number based on epochStartTime
    function _currentEpoch() internal view returns (uint256) {
        if (epochStartTime == 0) return 0;
        unchecked {
            return (block.timestamp - epochStartTime) / EPOCH_DURATION;
        }
    }

    /// @notice Advance to current epoch, maturing indices and applying scheduled changes
    function _advanceEpoch() internal {
        if (epochStartTime == 0) return;
        uint256 epochNow = _currentEpoch();
        if (epochNow <= lastProcessedEpoch) return;

        while (lastProcessedEpoch < epochNow) {
            // Mature current epoch into global index
            uint256 delta = currentEpochRewardIndex;
            if (delta != 0) {
                globalRewardIndex += delta;
                currentEpochRewardIndex = 0;
            }

            // Apply aggregated scheduled additions/removals for the new epoch window
            uint256 additionAmount = scheduledAdditionsNextEpoch;
            uint256 removalAmount = scheduledRemovalsNextEpoch;
            if (additionAmount != 0 || removalAmount != 0) {
                uint256 newEligible = eligibleTotal + additionAmount;
                if (removalAmount > newEligible) {
                    emit AccountingError("Removals exceed eligible total", removalAmount, newEligible);
                    newEligible = 0;
                } else if (removalAmount != 0) {
                    newEligible -= removalAmount;
                }
                eligibleTotal = newEligible;
                scheduledAdditionsNextEpoch = 0;
                scheduledRemovalsNextEpoch = 0;
            }

            lastProcessedEpoch += 1;
            emit EpochAdvanced(lastProcessedEpoch, delta, eligibleTotal);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Views                                   */
    /* -------------------------------------------------------------------------- */

    function _pendingRewards(address account) internal view returns (uint256) {
        // If a withdrawal is active this epoch or later, user is not eligible
        uint256 withdrawalEpoch = pendingWithdrawalEpoch[account];
        if (withdrawalEpoch != 0 && _currentEpoch() >= withdrawalEpoch) {
            return 0;
        }
        uint256 effectiveEligible = eligibleBalanceOf[account];
        uint256 activationEpoch = pendingActivationEpoch[account];
        if (activationEpoch != 0 && activationEpoch < lastProcessedEpoch) {
            effectiveEligible += pendingActivationAmount[account];
        }
        if (effectiveEligible == 0) return 0;
        return (effectiveEligible * (globalRewardIndex - userIndexSnapshot[account])) / INDEX_PRECISION;
    }

    /**
     * @notice Calculate pending rewards for a user (not yet compounded)
     * @param account Address to check pending rewards for
     * @return Amount of pending auto-compound rewards
     */
    function earned(address account) external view returns (uint256) {
        return _pendingRewards(account);
    }

    /**
     * @notice Get current global reward index
     * @return Current global reward index (1e12 scaling)
     */
    function rewardPerToken() external view returns (uint256) {
        return globalRewardIndex;
    }

    /// @notice Get current epoch index accumulator (for transparency)
    function rewardPerTokenCurrentEpoch() external view returns (uint256) {
        return currentEpochRewardIndex;
    }

    /**
     * @notice Get user's share of active staked pool (excluding unallocated rewards)
     * @param user Address to check
     * @return User's percentage share in basis points (10000 = 100%)
     */
    function getUserShareBps(address user) external view returns (uint256) {
        uint256 eligible = eligibleTotal;
        if (eligible == 0) return 0;
        return (eligibleBalanceOf[user] * MAX_PERCENTAGE) / eligible;
    }

    /**
     * @notice Calculate user's total balance including pending rewards
     * @param user Address to check
     * @return Total balance (current stake + pending compounded rewards)
     */
    function balanceWithPendingRewards(address user) external view returns (uint256) {
        return balanceOf[user] + _pendingRewards(user);
    }

    /// @notice Current epoch number
    function currentEpoch() external view returns (uint256) {
        return _currentEpoch();
    }

    /// @notice Time until next epoch boundary
    function timeUntilNextEpoch() external view returns (uint256) {
        if (epochStartTime == 0) return 0;
        uint256 elapsed = (block.timestamp - epochStartTime) % EPOCH_DURATION;
        return EPOCH_DURATION - elapsed;
    }

    /// @notice Epoch configuration
    function epochConfig() external view returns (uint256 startTime, uint256 duration) {
        return (epochStartTime, EPOCH_DURATION);
    }

    /**
     * @notice Returns extra HLG tokens that can be recovered
     * @dev Shows HLG.balanceOf(this) - totalStaked
     * @return Amount of extra HLG tokens available for recovery
     */
    function getExtraTokens() external view returns (uint256) {
        uint256 contractBalance = HLG.balanceOf(address(this));
        return contractBalance > totalStaked ? contractBalance - totalStaked : 0;
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Admin                                   */
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
        if (epochStartTime == 0) {
            epochStartTime = block.timestamp;
            lastProcessedEpoch = 0;
            emit EpochInitialized(epochStartTime);
        }
    }

    /**
     * @notice Emergency function to recover tokens (not HLG)
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
     * @notice Recover extra HLG tokens that were sent directly to contract
     * @param to Address to send extra HLG to
     * @param amount Amount of extra HLG to recover
     */
    function recoverExtraHLG(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = HLG.balanceOf(address(this));
        uint256 free = bal > totalStaked ? bal - totalStaked : 0;
        if (amount > free) revert NotEnoughExtraTokens();
        HLG.safeTransfer(to, amount);
        emit TokensRecovered(address(HLG), amount, to);
    }

    /**
     * @notice Reclaim unallocated rewards when there are no active stakers
     * @param to Address to send unallocated rewards to
     */
    function reclaimUnallocatedRewards(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (_activeStaked() != 0) revert ActiveStakeExists();

        uint256 unallocated = unallocatedRewards;
        if (unallocated == 0) revert ZeroAmount();

        unallocatedRewards = 0;
        unchecked {
            totalStaked -= unallocated;
        }
        HLG.safeTransfer(to, unallocated);

        emit TokensRecovered(address(HLG), unallocated, to);
    }

    /**
     * @notice Sweep ETH that may have been force-sent to the contract
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

    /**
     * @notice Credit HLG stake on behalf of a user (owner-only, paused-only)
     * @param user Address to receive the stake credit
     * @param amount Amount of HLG to stake
     */
    function stakeFor(address user, uint256 amount) public nonReentrant onlyOwner whenPaused {
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        _advanceEpoch();
        if (pendingWithdrawalAmount[user] != 0) revert PendingWithdrawalExists();

        _pullHLG(msg.sender, amount);
        updateUser(user);

        // Track new staker
        if (balanceOf[user] == 0) {
            totalStakers++;
        }

        balanceOf[user] += amount;
        totalStaked += amount;

        // Schedule activation next epoch
        uint256 activationEpoch = _currentEpoch() + 1;
        pendingActivationAmount[user] += amount;
        pendingActivationEpoch[user] = activationEpoch;
        scheduledAdditionsNextEpoch += amount;

        emit Staked(user, amount);
    }

    /**
     * @notice Batch stake HLG tokens for multiple users (gas optimized)
     * @param users Array of user addresses to stake for
     * @param amounts Array of amounts to stake for each user
     * @param startIndex Starting index in the arrays to process
     * @param endIndex Ending index (exclusive) in the arrays to process
     */
    function batchStakeFor(address[] calldata users, uint256[] calldata amounts, uint256 startIndex, uint256 endIndex)
        external
        onlyOwner
        whenPaused
        nonReentrant
    {
        if (users.length != amounts.length) revert ArrayLengthMismatch();
        if (endIndex > users.length) revert EndIndexOutOfBounds();
        if (startIndex >= endIndex) revert InvalidIndexRange();

        // Validate all inputs and calculate total amount
        uint256 totalAmount;
        for (uint256 i = startIndex; i < endIndex;) {
            if (users[i] == address(0)) revert ZeroAddress();
            if (amounts[i] == 0) revert ZeroAmount();
            totalAmount += amounts[i];
            unchecked {
                ++i;
            }
        }

        _pullHLG(msg.sender, totalAmount);

        // Sync epoch once for the entire batch to save gas
        _advanceEpoch();

        // Process each user: compound existing rewards, add new stake
        for (uint256 i = startIndex; i < endIndex;) {
            address user = users[i];
            uint256 amount = amounts[i];

            if (pendingWithdrawalAmount[user] != 0) revert PendingWithdrawalExists();
            _updateUserWithoutEpochAdvance(user);

            // Track new staker
            if (balanceOf[user] == 0) {
                totalStakers++;
            }

            balanceOf[user] += amount;
            totalStaked += amount;

            // Schedule activation next epoch
            uint256 activationEpoch = _currentEpoch() + 1;
            pendingActivationAmount[user] += amount;
            pendingActivationEpoch[user] = activationEpoch;
            scheduledAdditionsNextEpoch += amount;

            emit Staked(user, amount);
            unchecked {
                ++i;
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                Distributors                                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Whitelist/delist a distributor contract for future campaigns
     * @param distributor Address of the distributor contract
     * @param status True to whitelist, false to delist
     */
    function setDistributor(address distributor, bool status) external onlyOwner {
        if (distributor == address(0)) revert ZeroAddress();
        isDistributor[distributor] = status;
        emit DistributorUpdated(distributor, status);
    }

    /**
     * @notice Credit stake on behalf of user (called by whitelisted distributors)
     * @param user Wallet to receive the staked HLG
     * @param amount HLG amount to stake (pulled from distributor)
     */
    function stakeFromDistributor(address user, uint256 amount) external nonReentrant whenNotPaused {
        if (!isDistributor[msg.sender]) revert NotWhitelistedDistributor();
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        _advanceEpoch();
        if (pendingWithdrawalAmount[user] != 0) revert PendingWithdrawalExists();

        _pullHLG(msg.sender, amount);
        updateUser(user);

        // Track new staker
        if (balanceOf[user] == 0) {
            totalStakers++;
        }

        balanceOf[user] += amount;
        totalStaked += amount;

        // Schedule activation next epoch
        uint256 activationEpoch = _currentEpoch() + 1;
        pendingActivationAmount[user] += amount;
        pendingActivationEpoch[user] = activationEpoch;
        scheduledAdditionsNextEpoch += amount;

        emit Staked(user, amount);
        emit BoostedStake(msg.sender, user, amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Fallback                                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Reject ETH sent to the contract
     * @dev Prevents accidental ETH transfers to the contract
     */
    receive() external payable {
        revert NoEtherAccepted();
    }

    /**
     * @notice Reject calls to the contract
     * @dev Prevents accidental calls to the contract
     */
    fallback() external payable {
        revert InvalidCall();
    }
}
