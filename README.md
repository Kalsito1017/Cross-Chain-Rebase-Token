# 🚀 Cross Chain Rebase Token

**Cross Chain Rebase Token** is a customizable ERC-20 smart contract that implements a per-user linear rebasing interest mechanism. It’s designed for DeFi protocols that want to incentivize long-term holding or vault deposits, particularly in cross-chain environments.

## 📜 Description

This smart contract tracks a global interest rate that is locked per-user at the time of deposit. Interest accrues linearly over time and is minted automatically when users interact with the contract. The system ensures fairness and stability by allowing the interest rate to only decrease over time.

## 🔍 Features

- ✅ **ERC-20 compliant** using OpenZeppelin standards  
- 🧮 **Per-user interest calculation** based on their deposit timestamp  
- 📈 **Automatic interest minting** during any user interaction  
- 🛡️ **Decreasing-only interest rate** for economic integrity  
- 🔁 **Supports full balance operations** with `uint256.max` shorthand

## 🏗️ Built With

- [Solidity ^0.8.30](https://docs.soliditylang.org/)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Foundry (forge)](https://book.getfoundry.sh/) – recommended for testing and deployment

## 🧪 Example Usage

```solidity
// Minting tokens to a user (includes accrued interest)
rebaseToken.mint(userAddress, amount);

// Burning full balance
rebaseToken.burn(userAddress, type(uint256).max);

// Setting a new (lower) interest rate
rebaseToken.setInterestRate(4e10);
