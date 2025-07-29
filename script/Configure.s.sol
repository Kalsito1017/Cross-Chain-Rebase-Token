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
        // Begin broadcasting the transaction
        vm.startBroadcast();

        // Encode the remote pool address as bytes (required by TokenPool)
        bytes;
        remotePoolAddress[0] = abi.encode(remotePool);

        // Create an array with 1 ChainUpdate instruction
        TokenPool.ChainUpdate;

        // Fill in the ChainUpdate structure with remote details and rate limiter config
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector, // Remote chain ID (Chainlink selector)
            remotePoolAddresses: remotePoolAddress, // Encoded remote pool address
            remoteTokenAddress: abi.encode(remoteToken), // Encoded token address on remote chain
            outboundRateLimiterConfig: RateLimiter.Config({ // Outbound rate limiter settings
                    isEnabled: outboundRateLimiterIsEnable,
                    capacity: outboundRateLimiterCapacity,
                    rate: outboundRateLimiterRate
                }),
            inboundRateLimiterConfig: RateLimiter.Config({ // Inbound rate limiter settings
                    isEnabled: inboundRateLimiterIsEnabled,
                    capacity: inboundRateLimiterCapacity,
                    rate: inboundRateLimiterRate
                })
        });

        // Apply the configuration to the local pool
        // (removes nothing, adds the one new config)
        TokenPool(localPool).applyChainUpdates(new uint64, chainsToAdd);

        // Stop broadcasting the transaction
        vm.stopBroadcast();
    }
}
