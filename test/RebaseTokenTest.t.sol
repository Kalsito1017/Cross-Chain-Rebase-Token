// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {RebaseToken} from "src/RebaseToken.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {console} from "lib/forge-std/src/console.sol";
import {StdAssertions} from "lib/forge-std/test/StdAssertions.t.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    uint256 private constant LIMITED_AMOUNT_TO_DEPOSIT = 1e5; // 100,000 wei
    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault)); // Grant the vault mint and burn permissions
        vm.stopPrank();
    }
    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, LIMITED_AMOUNT_TO_DEPOSIT, type(uint80).max);
        vm.startPrank(user);
        vm.deal(user, amount); // Give the user some ether
        vault.deposit{value: amount}(); // User deposits ether into the vault
        uint256 startingBalance = rebaseToken.balanceOf(user);
        console.log("User's starting balance: ", startingBalance);
        assertEq(startingBalance, amount); // Check if the user's balance matches the deposited amount
        vm.warp(block.timestamp + 1 hours); // Simulate time passing
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startingBalance); // Check if the balance has increased due to rebase
        vm.warp(block.timestamp + 1 hours); // Simulate more time passing
        uint256 endingBalance = rebaseToken.balanceOf(user);
        assertGt(endingBalance, middleBalance); // Check if the balance has increased again due to rebase
        assertApproxEqAbs(
            endingBalance - middleBalance,
            middleBalance - startingBalance,
            1
        ); // Check if the increase is consistent

        vm.stopPrank();
    }
    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }
}
