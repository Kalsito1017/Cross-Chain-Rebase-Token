// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {Script} from "lib/forge-std/src/Script.sol";

import {TokenPool} from "lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "lib/ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

/// @title Configure
/// @notice A Foundry script to configure a local TokenPool to recognize and route to a remote TokenPool.
/// @dev Sets up a remote pool with chain selector and optional rate limiters.
contract Configure is Script {
    /// @notice Configures cross-chain settings for a local token pool.
    /// @param localPool The address of the local token pool to configure.
    /// @param remoteChainSelector Chainlink's selector ID of the remote chain.
    /// @param remotePool Address of the token pool on the remote chain.
    /// @param remoteToken The token address on the remote chain.
    /// @param outboundRateLimiterIsEnable Whether to enable outbound rate limiting.
    /// @param outboundRateLimiterCapacity Capacity for outbound rate limiter.
    /// @param outboundRateLimiterRate Rate (tokens per second) for outbound limiter.
    /// @param inboundRateLimiterIsEnabled Whether to enable inbound rate limiting.
    /// @param inboundRateLimiterCapacity Capacity for inbound rate limiter.
    /// @param inboundRateLimiterRate Rate (tokens per second) for inbound limiter.
    function run(
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteToken,
        bool outboundRateLimiterIsEnable,
        uint128 outboundRateLimiterCapacity,
        uint128 outboundRateLimiterRate,
        bool inboundRateLimiterIsEnabled,
        uint128 inboundRateLimiterCapacity,
        uint128 inboundRateLimiterRate
    ) public {
        vm.startBroadcast(); // Start broadcasting transactions to the network (for Foundry scripts)
        bytes[] memory remotePoolAddress = new bytes[](1); // Create a dynamic array to hold the encoded remote pool address
        remotePoolAddress[0] = abi.encode(remotePool); // Encode the remote pool address and store it in the array
        TokenPool.ChainUpdate[]
            memory chainsToAdd = new TokenPool.ChainUpdate[](1); // Create an array for chain updates (only one in this case)
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector, // Set the remote chain selector (Chainlink chain ID)
            remotePoolAddresses: remotePoolAddress, // Set the encoded remote pool address array
            remoteTokenAddress: abi.encode(remoteToken), // Encode and set the remote token address
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outboundRateLimiterIsEnable, // Enable/disable outbound rate limiter
                capacity: outboundRateLimiterCapacity, // Set outbound rate limiter capacity
                rate: outboundRateLimiterRate // Set outbound rate limiter rate (tokens per second)
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inboundRateLimiterIsEnabled, // Enable/disable inbound rate limiter
                capacity: inboundRateLimiterCapacity, // Set inbound rate limiter capacity
                rate: inboundRateLimiterRate // Set inbound rate limiter rate (tokens per second)
            })
        });
        TokenPool(localPool).applyChainUpdates(new uint64[](0), chainsToAdd); // Apply the chain update to the local token pool (no removals, only additions)
        vm.stopBroadcast(); // Stop broadcasting transactions
    }
}
