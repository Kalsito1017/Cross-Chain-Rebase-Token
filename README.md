# 🌉 Cross‑Chain Rebase Token

A cross‑chain rebase token built with **Foundry** and **Chainlink CCIP**.  
Users deposit ETH to mint rebasing tokens that increase linearly over time.  
Cross-chain bridging retains yield and interest rate using Chainlink's CCIP protocol.

---

## 📚 Table of Contents

- [🚀 Features](#-features)
- [📦 Requirements](#-requirements)
- [🛠️ Quickstart](#️-quickstart)
- [🧪 Tests](#-tests)
- [🧩 Deployment](#-deployment)
- [🧾 Usage](#-usage)
- [🧠 Notes & Assumptions](#-notes--assumptions)

---

## 🚀 Features

- 💰 **ETH deposits** mint rebasing tokens (1:1 value)
- ⏱️ **Linear yield accrual** over time (non-compounding)
- 🌉 **Cross-chain bridging** using Chainlink CCIP
- 🔒 **Immutable interest rate** per deposit
- 🔄 **Yield continuity across chains**
- 🧪 Full fuzz-tested with Foundry

---

## 📦 Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `cast`, `anvil`)
- Node provider keys for RPC access (e.g. Infura, Alchemy)
- `.env` file with the following variables:

```env
SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_KEY"
ARB_SEPOLIA_RPC_URL="https://arb-sepolia.g.alchemy.com/v2/YOUR_KEY"
ETHERSCAN_API_KEY="your_etherscan_key" # optional
```

---

## 🛠️ Quickstart

```bash
# Clone the repo
git clone https://github.com/Kalsito1017/Cross-Chain-Rebase-Token.git
cd Cross-Chain-Rebase-Token

# Install dependencies
forge install smartcontractkit/chainlink-local

# Build contracts
forge build
```

---

## 🧪 Tests

Run all tests with fuzzing and coverage:

```bash
forge test --fork-url $SEPOLIA_RPC_URL --coverage -vvvv
```

### Key Test Functions

- `testDepositLinear`:  
  Checks linear balance increase over time after ETH deposit

- `testCannotCallMint` & `testCannotCallBurn`:  
  Ensure direct minting/burning is restricted

- `testBridgePreservesYield`:  
  Simulates bridging and validates interest continuity

---

## 🧩 Deployment

### 1. Start local node (optional)

```bash
anvil
```

### 2. Deploy to Sepolia or Arbitrum Sepolia

```bash
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

Or for Arbitrum:

```bash
forge script script/Deploy.s.sol --rpc-url $ARB_SEPOLIA_RPC_URL --broadcast
```

Ensure your `.env` is configured correctly for the target chain.

---

## 🧾 Usage

### Deposit ETH

```bash
cast send <VaultAddress> "deposit()" \
  --value 0.1ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Simulate Time Passing (for testing only)

```solidity
vm.warp(block.timestamp + 1 hours);
```

### Redeem ETH (Withdraw)

```bash
cast send <VaultAddress> "withdraw(uint256)" 100000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Bridge Tokens via CCIP (Simulated)

Interact with the local CCIP simulator or real Chainlink Router depending on environment.

---

## 🧠 Notes & Assumptions

- Rebasing is **linear**, not compounding
- Yield accrues over time but **pauses during bridging**
- Interest rate is **locked** at deposit time and used in cross-chain minting

---

## 👷 Built With

- [Foundry](https://book.getfoundry.sh/)
- [Chainlink CCIP](https://chain.link/cross-chain)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)

