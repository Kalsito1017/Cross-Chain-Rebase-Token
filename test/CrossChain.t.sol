// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {RebaseToken} from "src/RebaseToken.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {console} from "lib/forge-std/src/console.sol";

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {RebaseTokenPool} from "src/RebaseTokenPool.sol";
import {CCIPLocalSimulatorFork} from "lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";

contract CrossChainTest is Test {
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    CCIPLocalSimulatorFork ccipLocalSimulatorFork;
    /// @notice Sets up the test environment with multiple forks and a persistent local CCIP simulator
    /// @dev Initializes Sepolia and Arbitrum Sepolia forks, and deploys a persistent CCIPLocalSimulatorFork instance
    function setUp() public {
        // Create and select the Sepolia fork as the active fork
        sepoliaFork = vm.createSelectFork("sepolia");

        // Create an Arbitrum Sepolia fork (not selected by default)
        arbSepoliaFork = vm.createFork("arb-sepolia");

        // Deploy the local CCIP simulator used for testing CCIP behavior without real networks
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();

        // Make the simulator persistent so its state is retained across test functions
        vm.makePersistent(address(ccipLocalSimulatorFork));
    }
}
