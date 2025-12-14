// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Vesting.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}


contract VestingTest is Test {
    MockToken token;
    Vesting vesting;

    address beneficiary = address(0xBEEF);
    address minter = address(this);

    uint256 constant TOTAL = 1_000_000e18;

    function setUp() public {
        token = new MockToken("MockToken", "MTK");

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
        vm.warp(vesting.start() + 11 * vesting.MONTH());

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
        vm.warp(vesting.cliff() + 5 * vesting.MONTH() + 1);

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
