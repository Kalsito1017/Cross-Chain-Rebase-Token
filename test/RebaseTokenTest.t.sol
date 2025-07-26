// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {RebaseToken} from "src/RebaseToken.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {console} from "lib/forge-std/src/console.sol";

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    uint256 public SEND_VALUE = 1e5;

    uint256 private constant LIMITED_AMOUNT_TO_DEPOSIT = 1e5; // 100,000 wei

    /// @notice Send ETH to vault (e.g., to simulate rewards)
    function addRewardsToVault(uint256 amount) public {
        (bool success, ) = payable(address(vault)).call{value: amount}("");
        require(success, "Sending rewards to vault failed");
    }

    /// @notice Set up contracts before each test
    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    /// @notice Tests that the user's rebase token balance increases linearly over time after depositing ETH
    /// @dev
    /// - Deposits a bounded ETH amount into the vault
    /// - Simulates time progression using `vm.warp`
    /// - Checks that balance grows linearly over each hour due to rebase
    /// @param amount The ETH amount to deposit, bounded between a constant and uint80 max
    function testDepositLinear(uint256 amount) public {
        // Bound the amount to ensure it is within a safe testing range
        amount = bound(amount, LIMITED_AMOUNT_TO_DEPOSIT, type(uint80).max);

        // Begin acting as the `user` address
        vm.startPrank(user);

        // Give the user the test ETH to deposit
        vm.deal(user, amount);

        // Deposit ETH into the vault — should mint rebase tokens
        vault.deposit{value: amount}();

        // Capture the user’s balance immediately after deposit
        uint256 startingBalance = rebaseToken.balanceOf(user);
        console.log("User's starting balance: ", startingBalance);

        // Ensure the minted rebase tokens equal the amount deposited
        assertEq(startingBalance, amount);

        // Advance time by 1 hour
        vm.warp(block.timestamp + 1 hours);

        // Check balance after 1 hour — should have increased due to rebase
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startingBalance);

        // Advance time by another hour (2 hours total)
        vm.warp(block.timestamp + 1 hours);

        // Check balance after 2 hours — should be greater than after 1 hour
        uint256 endingBalance = rebaseToken.balanceOf(user);
        assertGt(endingBalance, middleBalance);

        // Ensure the increase is linear (same amount per hour) within ±1 unit
        assertApproxEqAbs(
            endingBalance - middleBalance,
            middleBalance - startingBalance,
            1
        );

        // Stop acting as `user`
        vm.stopPrank();
    }

    /// @notice User redeems right after deposit, so no rebase should occur
    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);

        vault.redeem(type(uint256).max); // Redeem all tokens
        assertEq(rebaseToken.balanceOf(user), 0); // Token balance should be 0
        assertEq(address(user).balance, amount); // User should receive ETH back

        vm.stopPrank();
    }

    /// @notice User redeems after time passes and rewards are added
    function testRedeemAfterTimeHasPassed(
        uint256 depositAmount,
        uint256 time
    ) public {
        time = bound(time, 1000, type(uint96).max); // this is a crazy number of years - 2^96 seconds is a lot
        depositAmount = bound(depositAmount, 1e5, type(uint96).max); // this is an Ether value of max 2^78 which is crazy

        // Deposit funds
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        // check the balance has increased after some time has passed
        vm.warp(time);

        // Get balance after time has passed
        uint256 balance = rebaseToken.balanceOf(user);

        // Add rewards to the vault
        vm.deal(owner, balance - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balance - depositAmount);
        vm.prank(user);
        vault.redeem(balance);

        uint256 ethBalance = address(user).balance;

        assertEq(balance, ethBalance);
        assertGt(balance, depositAmount);
    }

    /// @notice Test transferring tokens and effect on balances and interest rate
    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 2e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");

        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);

        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        // Owner reduces the interest rate (simulate decrease)
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // Transfer tokens to user2
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);

        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);

        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        // Check interest rates stayed fixed after transfer
        assertEq(rebaseToken.getInterestRate(), 4e10); // Check updated global rate
    }
    /// @notice Tests that only the owner can set the interest rate; expects revert if called by non-owner.
    /// @param newInteresetRate The new interest rate to attempt to set.

    function testCannotSetInteresetRate(uint256 newInteresetRate) public {
        vm.prank(user); // Set the caller to 'user' (not the contract owner)

        vm.expectPartialRevert(
            bytes4(Ownable.OwnableUnauthorizedAccount.selector) // Expect a revert with the Ownable unauthorized account selector
        );
        rebaseToken.setInterestRate(newInteresetRate); // Attempt to set the interest rate as a non-owner
    }
    /// @notice Tests that calling `mint` directly on the rebaseToken contract reverts
    /// @dev The user tries to mint directly, which should not be allowed
    function testCannotCallMint() public {
        // Set the sender of the next transaction to `user`
        vm.startPrank(user);

        // Get the current interest rate from the rebaseToken
        uint256 interestRate = rebaseToken.getInterestRate();

        // Expect the next call to revert (i.e., it should fail)
        vm.expectRevert();

        // Attempt to call mint directly; this should fail
        rebaseToken.mint(user, SEND_VALUE, interestRate);

        // Stop impersonating `user`
        vm.stopPrank();
    }

    /// @notice Tests that calling `burn` directly on the rebaseToken contract reverts
    /// @dev The user tries to burn tokens directly, which should not be allowed
    function testCannotCallBurn() public {
        // Set the sender of the next transaction to `user`
        vm.startPrank(user);

        // Expect the next call to revert (i.e., it should fail)
        vm.expectRevert();

        // Attempt to call burn directly; this should fail
        rebaseToken.burn(user, SEND_VALUE);

        // Stop impersonating `user`
        vm.stopPrank();
    }

    /// @notice Tests that principalBalanceOf returns the correct principal amount after deposit and after time passes.
    /// @param amount The amount to deposit and check principal for.
    function testGetPrincipleAmount(uint256 amount) public {
        // Bound the deposit amount to a reasonable range
        amount = bound(amount, 1e5, type(uint96).max);
        // Give the user the deposit amount
        vm.deal(user, amount);
        // Set the caller to 'user'
        vm.prank(user);
        // Deposit the amount into the vault
        vault.deposit{value: amount}();
        // Assert that the principal balance equals the deposited amount
        assertEq(rebaseToken.principalBalanceOf(user), amount);

        // Warp time forward by 1 hour
        vm.warp(block.timestamp + 1 hours);
        // Assert that the principal balance remains unchanged after time passes
        assertEq(rebaseToken.principalBalanceOf(user), amount);
    }

    /// @notice Tests that the vault returns the correct rebase token address.
    function testGetRebaseTokenAddress() public view {
        // Assert that the vault's rebase token address matches the deployed rebaseToken address
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    /// @notice Tests that the interest rate can only be decreased, not increased.
    /// @param newInterestRate The new interest rate to attempt to set (should be higher than current).
    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        // Get the initial interest rate
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        // Bound the new interest rate to be greater than the initial rate
        newInterestRate = bound(
            newInterestRate,
            initialInterestRate + 1, //REVERT ERROR FIX -> +1
            type(uint96).max
        );
        // Set the caller to 'owner'
        vm.prank(owner);
        // Expect a revert with the custom error selector when trying to increase the rate
        vm.expectPartialRevert(
            bytes4(RebaseToken.RebaseToken__InterestRateDecreaseOnly.selector)
        );
        // Attempt to set the interest rate to a higher value
        rebaseToken.setInterestRate(newInterestRate);
        // Assert that the interest rate remains unchanged
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }
}
