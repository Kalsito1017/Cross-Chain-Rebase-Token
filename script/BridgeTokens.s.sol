// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {IRouterClient} from "lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Script} from "lib/forge-std/src/Script.sol";
import {CCIPLocalSimulatorFork} from "lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Client} from "lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

/// @title BridgeTokens
/// @notice A Foundry script to bridge tokens using Chainlink CCIP from one EVM chain to another.
/// @dev This script constructs and sends a cross-chain message with token transfer.
contract BridgeTokens is Script {
    /// @notice Executes a token bridge operation via CCIP.
    /// @param receiverAddress The address that will receive the bridged tokens on the destination chain.
    /// @param destinationChainSelector Chainlink's chain selector ID of the destination chain.
    /// @param tokenToSendAddress Address of the token being bridged.
    /// @param amountToSend Amount of the token to bridge.
    /// @param linkTokenAddress Address of the LINK token used to pay for the CCIP fee.
    /// @param routerAddress Address of the CCIP router contract on the source chain.
    function run(
        address receiverAddress,
        uint64 destinationChainSelector,
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress,
        address routerAddress
    ) public {
        // Create a 1-element array for tokenAmounts to be sent
        Client.EVMTokenAmount;

        // Populate the token amount (token address and value)
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: tokenToSendAddress, // ERC20 token to bridge
            amount: amountToSend // Amount to bridge
        });

        // Begin broadcasting transactions (Foundry-specific command to send txs)
        vm.startBroadcast();

        // Construct the CCIP message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress), // Encoded address of receiver on destination chain
            data: "", // No custom calldata
            tokenAmounts: tokenAmounts, // Token transfer info
            feeToken: linkTokenAddress, // LINK token used to pay fee
            extraArgs: Client._argsToBytes( // Optional args (gasLimit = 0)
                    Client.EVMExtraArgsV1({gasLimit: 0}) // Could set allowOutOfOrderExecution = true in V2
                )
        });

        // Calculate the CCIP fee using router’s fee estimation
        uint256 ccipFee = IRouterClient(routerAddress).getFee(
            destinationChainSelector,
            message
        );

        // Approve LINK fee to router
        IERC20(linkTokenAddress).approve(routerAddress, ccipFee);

        // Approve token transfer to router
        IERC20(tokenToSendAddress).approve(routerAddress, amountToSend);

        // Send the cross-chain message
        IRouterClient(routerAddress).ccipSend(
            destinationChainSelector,
            message
        );

        // Stop broadcasting (Foundry)
        vm.stopBroadcast();
    }
}
