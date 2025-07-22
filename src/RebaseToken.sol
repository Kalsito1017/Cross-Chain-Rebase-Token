// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
/*
 * @title RebaseToken
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault.
 * @notice The intereset rate in the smart contract can only decrease.
 * @notice Each user will have its own interest rate that is a global intereset rate at the time of the depositing.
 */

contract RebaseToken is ERC20 {
    error RebasaToken__InterestRateDecreaseOnly(
        uint256 oldInteresetRate,
        uint256 newInterestRate
    );
    uint256 private s_interestRate = 5e10; // 5% interest rate
    uint256 private constant PRECISION_FACTOR = 1e18; // Precision factor for interest calculations
    mapping(address => uint256) private s_InterestRate; // User specific interest rate
    mapping(address => uint256) private s_UserLastUpdatedTimeStamp; // User specific last updated timestamp

    event InteresetRateSet(uint256 newInterestRate);
    constructor() ERC20("Rebase", "RBT") {}
    /*
     * @notice Set the interest rate for the rebase token.
     * @notice The interest rate can only be decreased.
     * @param _newInteresetRate The new interest rate to be set.
     */
    function setInterestRate(uint256 _newInteresetRate) external {
        if (_newInteresetRate < s_interestRate) {
            revert RebasaToken__InterestRateDecreaseOnly(
                s_interestRate,
                _newInteresetRate
            );
        }
        s_interestRate = _newInteresetRate; // Set the interest rate
        emit InteresetRateSet(_newInteresetRate);
    }
    /*
     * @notice Mint new tokens to the user.
     * @notice The user will also receive the interest that has accumulated since the last update.
     * @param _to The address to mint the tokens to.
     * @param _amount The amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccuredInterest(_to); // Mint accured interest before minting new tokens
        s_interestRate[_to] = s_interestRate; // Set the interest rate for the user
        _mint(_to, _amount); // Mint the new tokens to the user
    }
    /*
     * @notice Burn tokens from the user.
     * @notice The user will also receive the interest that has accumulated since the last update.
     * @param _from The address to burn the tokens from.
     * @param _amount The amount of tokens to burn.
     */
    function burn(address _from, uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from); // If the amount is max, burn all tokens
        }
        _mintAccuredInterest(_from); // Mint accured interest before burning tokens
        _burn(_from, _amount); // Burn the tokens from the user
    }
    /*
     * @notice Calculate the interest that has accumulated since the last update.
     * @param user The user to calculate the interest accumulated for.
     * @return The amount of interest that has accumulated since the last update.
     */
    function _calculateUserAccumulatedInteresetSinceLastUpdate(
        address _user
    ) internal view returns (uint256 linearIntereset) {
        uint256 lastUpdatedTimeStamp = block.timestamp -
            s_UserLastUpdatedTimeStamp[_user];
        linearIntereset =
            PRECISION_FACTOR +
            (s_interestRate[_user] * lastUpdatedTimeStamp); // Calculate the linear interest based on the last updated timestamp
    }
    /*
     * @notice Mint the accrued interest to the user since the last time they interact with the protocl.
     * @param _user The user to mint the accrued interest rate to.
     */
    function _mintAccuredInterest(address _user) internal {
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance; // Calculate the balance increase since the last update
        s_UserLastUpdatedTimeStamp[_user] = block.timestamp; // Update the last updated timestamp for the user
        _mint(_user, balanceIncrease); // Mint the accrued interest to the user
    }
    /*
     * @notice Calculate the balance for the user including the intereset that has accumulated since the last update.
     * @param _user The user to calculate the balance for.
     * @return The balance of the user including the interest.
     */
    function balanceOf(address _user) public view override returns (uint256) {
        //get the current balance of the user
        return
            super.balanceOf(_user) +
            _calculateUserAccumulatedInteresetSinceLastUpdate(_user) /
            PRECISION_FACTOR; // Return the balance of the user including the interest
    }
}
