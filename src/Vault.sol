//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";

contract Vault {
    IRebaseToken private immutable i_rebaseToken;
    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);
    error Vault__RedeemFailed();
    constructor(IRebaseToken _rebaseTokenAddress) {
        i_rebaseToken = _rebaseTokenAddress; // Set the rebase token address
    }

    receive() external payable {}
    /**
     * @notice Deposit ether into the vault and mint rebase tokens to the sender.
     * @notice The sender will receive rebase tokens equivalent to the amount of ether deposited.
     */
    function deposit() external payable {
        i_rebaseToken.mint(msg.sender, msg.value); // Mint rebase tokens to the sender
        emit Deposit(msg.sender, msg.value); // Emit a deposit event
    }
    /**
     * @notice Get the address of the rebase token contract.
     * @return The address of the rebase token contract.
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken); // Return the rebase token address
    }
    /**
     * @notice Redeem rebase tokens for ether.
     * @notice The sender will burn their rebase tokens and receive ether equivalent to the amount of rebase tokens burned.
     * @param _amount The amount of rebase tokens to redeem.
     */
    function redeem(uint256 _amount) external {
        i_rebaseToken.burn(msg.sender, _amount); // Burn the rebase tokens from the sender
        (bool success, ) = msg.sender.call{value: _amount}(""); // Transfer the ether to the sender
        if (!success) {
            revert Vault__RedeemFailed(); // Revert if the transfer fails
        }
        emit Redeem(msg.sender, _amount); // Emit a redeem event
    }
}
