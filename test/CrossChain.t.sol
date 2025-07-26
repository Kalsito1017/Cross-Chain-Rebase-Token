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
    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));
    }
}
