// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title StakingRewards
 * @notice Single-token HLG staking with auto-compounding rewards and configurable burn/reward split
 * @dev Uses MasterChef V2 cumulative reward index for O(1) gas efficiency. Configurable burn percentage splits incoming tokens between burn and rewards. First staker receives genesis bonus from any pre-existing unallocated buffer. While paused, stake() and stakeFromDistributor() revert; unstake() and emergencyExit() remain available. Burn uses transfer(address(0)) and HLG at 0x740dF024Ce73F589AcD5E8756B377eF8C6558BaB reduces totalSupply in its implementation.
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
    /*                              Distributor Registry                          */
    /* -------------------------------------------------------------------------- */

    /// @notice Registry of approved distributors (Merkle drop contracts, quest engines, etc.)
    /// @dev Distributors can call stakeFromDistributor() to credit user stakes
    mapping(address => bool) public isDistributor;

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

        // Transfer tokens from user with fee-on-transfer protection
        uint256 actualAmount = _pullHLG(msg.sender, amount);

        // Auto-compound any pending rewards (after token transfer)
        updateUser(msg.sender);

        // Handle genesis bonus: first staker gets any buffered rewards
        bool isFirstStaker = (totalStaked == 0);
        balanceOf[msg.sender] += actualAmount;
        totalStaked += actualAmount;

        if (isFirstStaker && unallocatedBuffer > 0) {
            uint256 bufferedRewards = unallocatedBuffer;
            unallocatedBuffer = 0;
            balanceOf[msg.sender] += bufferedRewards;
            totalStaked += bufferedRewards;
            emit RewardsCompounded(msg.sender, bufferedRewards);
        }

        emit Staked(msg.sender, actualAmount);
    }

    /**
     * @notice Unstake entire HLG balance including all accumulated rewards
     * @dev Auto-compounds first, then transfers full balance. Can be called while paused.
     */
    function unstake() external nonReentrant {
        // Auto-compound any pending rewards first
        updateUser(msg.sender);

        uint256 userBalance = balanceOf[msg.sender];
        if (userBalance == 0) revert NoStake();

        // Reset user's state and transfer full balance
        balanceOf[msg.sender] = 0;
        userIndexSnapshot[msg.sender] = 0;
        unchecked { totalStaked -= userBalance; }
        HLG.safeTransfer(msg.sender, userBalance);
        emit Unstaked(msg.sender, userBalance);
    }

    /**
     * @notice Emergency exit without compounding pending rewards
     * @dev Does not call updateUser; returns current recorded balance. Can be called while paused.
     */
    function emergencyExit() external nonReentrant {
        uint256 userBalance = balanceOf[msg.sender];
        if (userBalance == 0) revert NoStake();

        // Reset user's state without updating rewards (emergency exit)
        balanceOf[msg.sender] = 0;
        userIndexSnapshot[msg.sender] = 0;
        unchecked { totalStaked -= userBalance; }
        HLG.safeTransfer(msg.sender, userBalance);
        emit EmergencyExit(msg.sender, userBalance);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Bootstrap Operations                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Deposit HLG and distribute according to burn/reward percentage split
     * @param hlgAmount Total HLG to process (will be split according to burnPercentage)
     */
    function depositAndDistribute(uint256 hlgAmount) external onlyOwner nonReentrant {
        if (hlgAmount == 0) revert ZeroAmount();

        // Transfer HLG from caller with fee-on-transfer protection
        uint256 actualAmount = _pullHLG(msg.sender, hlgAmount);

        // Calculate burn/reward split based on burnPercentage
        uint256 burnAmount = (actualAmount * burnPercentage) / MAX_PERCENTAGE;
        uint256 rewardAmount = actualAmount - burnAmount;
        
        // Burn tokens (true burn via HLG implementation)
        HLG.safeTransfer(address(0), burnAmount);
        
        // Distribute remaining portion as auto-compounding rewards
        _addRewards(rewardAmount);
        emit RewardsDistributed(actualAmount, burnAmount, rewardAmount);
    }

    /* -------------------------------------------------------------------------- */
    /*                      Future Automated Integration                          */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Add rewards from FeeRouter (automated flow)
     * @param amount Total amount of HLG to process (will be split according to burnPercentage)
     */
    function addRewards(uint256 amount) external nonReentrant {
        if (msg.sender != feeRouter) revert Unauthorized();
        if (amount == 0) revert ZeroAmount();

        // Transfer HLG from FeeRouter with fee-on-transfer protection
        uint256 actualAmount = _pullHLG(msg.sender, amount);

        // Calculate burn/reward split based on burnPercentage
        uint256 burnAmount = (actualAmount * burnPercentage) / MAX_PERCENTAGE;
        uint256 rewardAmount = actualAmount - burnAmount;
        
        // Burn tokens (true burn via HLG implementation)
        HLG.safeTransfer(address(0), burnAmount);
        
        // Distribute remaining portion as auto-compounding rewards
        _addRewards(rewardAmount);
        emit RewardsDistributed(actualAmount, burnAmount, rewardAmount);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Internal Helpers                              */
    /* -------------------------------------------------------------------------- */

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

    /* -------------------------------------------------------------------------- */
    /*                      Core Auto-Compounding Functions                       */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Update user's reward state and auto-compound pending rewards
     * @param account Address to update rewards for
     */
    function updateUser(address account) public {
        uint256 userBalance = balanceOf[account];
        if (userBalance > 0) {
            // Calculate pending rewards using MasterChef V2 formula
            uint256 pendingRewards = (userBalance * (globalRewardIndex - userIndexSnapshot[account])) / INDEX_PRECISION;
            
            if (pendingRewards > 0) {
                // Auto-compound: add rewards directly to user's balance
                balanceOf[account] += pendingRewards;
                totalStaked += pendingRewards;
                emit RewardsCompounded(account, pendingRewards);
            }
        }
        
        // Update user's snapshot to current global index (prevents double-claiming)
        userIndexSnapshot[account] = globalRewardIndex;
    }

    /**
     * @notice Add rewards to the pool with buffer-aware distribution
     * @param rewardAmount Amount of HLG rewards to distribute to stakers
     */
    function _addRewards(uint256 rewardAmount) internal {
        if (rewardAmount == 0) return;

        // Handle unallocated buffer first (rewards received when no stakers)
        if (unallocatedBuffer > 0 && totalStaked > 0) {
            // Distribute previously buffered rewards now that we have stakers
            uint256 bufferedRewards = unallocatedBuffer;
            unallocatedBuffer = 0;
            globalRewardIndex += (bufferedRewards * INDEX_PRECISION) / totalStaked;
        }

        if (totalStaked == 0) {
            // No stakers - add to buffer for later distribution
            unallocatedBuffer += rewardAmount;
            return;
        }
        globalRewardIndex += (rewardAmount * INDEX_PRECISION) / totalStaked;
    }

    /* -------------------------------------------------------------------------- */
    /*                              View Functions                                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Internal helper to calculate pending rewards for a user
     * @param account Address to check
     * @return Pending rewards not yet compounded
     */
    function _pendingRewards(address account) internal view returns (uint256) {
        uint256 bal = balanceOf[account];
        if (bal == 0) return 0;
        return (bal * (globalRewardIndex - userIndexSnapshot[account])) / INDEX_PRECISION;
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
     * @param user Address to check
     * @return Total balance (current stake + pending compounded rewards)
     */
    function balanceWithPendingRewards(address user) external view returns (uint256) {
        return balanceOf[user] + _pendingRewards(user);
    }

    /**
     * @notice Returns HLG.balanceOf(this) - totalStaked
     * @dev Includes any unallocatedBuffer. This is an operational metric (e.g., funding status), not a claimable amount.
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
    /*                       Owner Batch Credit Operations                        */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Credit HLG stake on behalf of a user (owner-only, paused-only)
     * @dev Pulls tokens from owner; compounds existing rewards before adding new stake
     * @param user Address to receive the stake credit
     * @param amount Amount of HLG to stake
     */
    function stakeFor(address user, uint256 amount) public nonReentrant onlyOwner whenPaused {
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // Pull tokens from owner (ensures actual HLG transfer)
        _pullHLG(msg.sender, amount);
        
        // Auto-compound any pending rewards first
        updateUser(user);
        
        // Update user balance and total staked
        balanceOf[user] += amount;
        totalStaked += amount;

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
        // Validate inputs
        if (users.length != amounts.length) revert ArrayLengthMismatch();
        if (endIndex > users.length) revert EndIndexOutOfBounds();
        if (startIndex >= endIndex) revert InvalidIndexRange();
        uint256 totalAmount;
        for (uint256 i = startIndex; i < endIndex;) {
            if (users[i] == address(0)) revert ZeroAddress();
            if (amounts[i] == 0) revert ZeroAmount();
            totalAmount += amounts[i];
            unchecked {
                ++i;
            }
        }

        // Single transfer for entire batch (gas optimization)
        _pullHLG(msg.sender, totalAmount);
        
        // Process each user in the batch
        for (uint256 i = startIndex; i < endIndex;) {
            address user = users[i];
            uint256 amount = amounts[i];

            // Auto-compound any existing rewards
            updateUser(user);
            
            // Update balances
            balanceOf[user] += amount;
            totalStaked += amount;

            emit Staked(user, amount);

            unchecked {
                ++i;
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                            Distributor System                              */
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
     * @dev Pull-only; prevents idle balance usage; respects pause
     * @param user Wallet to receive the staked HLG
     * @param amount HLG amount to stake (pulled from distributor)
     */
    function stakeFromDistributor(address user, uint256 amount) external nonReentrant whenNotPaused {
        if (!isDistributor[msg.sender]) revert NotWhitelistedDistributor();
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // Pull tokens from distributor with fee-on-transfer protection
        _pullHLG(msg.sender, amount);
        
        // Auto-compound any pending rewards first
        updateUser(user);
        
        // Credit new stake to user
        balanceOf[user] += amount;
        totalStaked += amount;

        emit Staked(user, amount);
        emit BoostedStake(msg.sender, user, amount);
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
