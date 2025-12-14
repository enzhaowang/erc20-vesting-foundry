// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice ERC20 Vesting
/// - 12 months cliff
/// - linear vesting over next 24 months
/// - from month 13, release 1/24 every month
contract Vesting {
    /* -------------------------------------------------------------------------- */
    /*                                   Constants                                */
    /* -------------------------------------------------------------------------- */

    // 使用 30 days 作为“月”，便于 Foundry 时间模拟
    uint256 public constant MONTH = 30 days;
    uint256 public constant CLIFF_MONTHS = 12;
    uint256 public constant VESTING_MONTHS = 24;

    /* -------------------------------------------------------------------------- */
    /*                                  Immutable                                 */
    /* -------------------------------------------------------------------------- */

    address public immutable beneficiary;
    IERC20 public immutable token;

    uint256 public immutable start;
    uint256 public immutable cliff;
    uint256 public immutable end;
    uint256 public immutable totalAllocation;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    uint256 public released;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error NothingToRelease();
    error TransferFailed();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    event Released(uint256 amount, uint256 totalReleased);

    constructor(
        address _beneficiary,
        IERC20 _token,
        uint256 _totalAllocation
    ) {
        require(_beneficiary != address(0), "beneficiary=0");
        require(address(_token) != address(0), "token=0");
        require(_totalAllocation > 0, "allocation=0");

        beneficiary = _beneficiary;
        token = _token;

        start = block.timestamp;
        cliff = start + CLIFF_MONTHS * MONTH;
        end = cliff + VESTING_MONTHS * MONTH;

        totalAllocation = _totalAllocation;
    }

    /* -------------------------------------------------------------------------- */
    /*                              View Functions                                */
    /* -------------------------------------------------------------------------- */

    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        if (timestamp < cliff) return 0;
        if (timestamp >= end) return totalAllocation;

        // cliff 后的第几个月（从 0 开始）
        uint256 elapsedMonths = (timestamp - cliff) / MONTH;

        // 第13个月开始算第1期
        uint256 vestedPeriods = elapsedMonths + 1;
        if (vestedPeriods > VESTING_MONTHS) {
            vestedPeriods = VESTING_MONTHS;
        }

        return (totalAllocation * vestedPeriods) / VESTING_MONTHS;
    }

    function releasable() public view returns (uint256) {
        uint256 vested = vestedAmount(block.timestamp);
        if (vested <= released) return 0;
        return vested - released;
    }

    /* -------------------------------------------------------------------------- */
    /*                              State-changing                                */
    /* -------------------------------------------------------------------------- */

    function release() external {
        uint256 amount = releasable();
        if (amount == 0) revert NothingToRelease();

        released += amount;

        bool ok = token.transfer(beneficiary, amount);
        if (!ok) revert TransferFailed();

        emit Released(amount, released);
    }
}
