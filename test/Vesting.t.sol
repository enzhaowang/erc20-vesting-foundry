// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "../src/Vesting.sol";

contract VestingTest is Test {
    ERC20PresetMinterPauser token;
    Vesting vesting;

    address beneficiary = address(0xBEEF);
    address minter = address(this);

    uint256 constant TOTAL = 1_000_000e18;

    function setUp() public {
        token = new ERC20PresetMinterPauser("MockToken", "MTK");

        vesting = new Vesting(
            beneficiary,
            IERC20(address(token)),
            TOTAL
        );

        // mint + transfer 100万 token 到 vesting 合约
        token.mint(address(this), TOTAL);
        token.transfer(address(vesting), TOTAL);
    }

    function test_BeforeCliff_NoRelease() public {
        vm.warp(vesting.start() + 11 * Vesting.MONTH());

        assertEq(vesting.releasable(), 0);
        vm.expectRevert(Vesting.NothingToRelease.selector);
        vesting.release();
    }

    function test_FirstMonthAfterCliff() public {
        vm.warp(vesting.cliff() + 1);

        uint256 expected = TOTAL / 24;
        assertEq(vesting.releasable(), expected);

        vesting.release();
        assertEq(token.balanceOf(beneficiary), expected);
    }

    function test_SixMonthsAfterCliff() public {
        vm.warp(vesting.cliff() + 5 * Vesting.MONTH() + 1);

        uint256 expected = (TOTAL * 6) / 24;
        vesting.release();

        assertEq(token.balanceOf(beneficiary), expected);
    }

    function test_End_ReleasesAll() public {
        vm.warp(vesting.end() + 1);

        vesting.release();

        assertEq(token.balanceOf(beneficiary), TOTAL);
        assertEq(token.balanceOf(address(vesting)), 0);
    }
}
