// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {RebaseToken} from "src/RebaseToken.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {Vault} from "src/Vault.sol";
import {Register} from "lib/chainlink-local/src/ccip/Register.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {console} from "lib/forge-std/src/console.sol";
import {IERC20} from "lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {RebaseTokenPool} from "src/RebaseTokenPool.sol";
import {CCIPLocalSimulatorFork} from "lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {RegistryModuleOwnerCustom} from "lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "lib/ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {Client} from "lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
contract CrossChainTest is Test {
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    uint256 public SEND_VALUE = 1e5;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    RebaseToken destRebaseToken;
    RebaseToken sourceRebaseToken;

    RebaseTokenPool destPool;
    RebaseTokenPool sourcePool;

    TokenAdminRegistry tokenAdminRegistrySepolia;
    TokenAdminRegistry tokenAdminRegistryarbSepolia;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    RegistryModuleOwnerCustom registryModuleOwnerCustomSepolia;
    RegistryModuleOwnerCustom registryModuleOwnerCustomarbSepolia;

    Vault vault;
    /// @notice Sets up the test environment with multiple forks and a persistent local CCIP simulator
    /// @dev Initializes Sepolia and Arbitrum Sepolia forks, and deploys a persistent CCIPLocalSimulatorFork instance
    function setUp() public {
        address[] memory allowlist = new address[](0);

        // sourceDeployer = new SourceDeployer();

        // 1. Setup the Sepolia and arb forks
        sepoliaFork = vm.createSelectFork("eth");
        arbSepoliaFork = vm.createFork("arb");

        //NOTE: what does this do?
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // 2. Deploy and configure on the source chain: Sepolia
        //sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        //(sourceRebaseToken, sourcePool, vault) = sourceDeployer.run(owner);
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        vm.startPrank(owner);
        sourceRebaseToken = new RebaseToken();
        console.log("source rebase token address");
        console.log(address(sourceRebaseToken));
        console.log("Deploying token pool on Sepolia");
        sourcePool = new RebaseTokenPool(
            IERC20(address(sourceRebaseToken)),
            allowlist,
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        // deploy the vault
        vault = new Vault(IRebaseToken(address(sourceRebaseToken)));
        // add rewards to the vault
        vm.deal(address(vault), 1e18);
        // Set pool on the token contract for permissions on Sepolia
        sourceRebaseToken.grantMintAndBurnRole(address(sourcePool));
        sourceRebaseToken.grantMintAndBurnRole(address(vault));
        // Claim role on Sepolia
        registryModuleOwnerCustomSepolia = RegistryModuleOwnerCustom(
            sepoliaNetworkDetails.registryModuleOwnerCustomAddress
        );
        registryModuleOwnerCustomSepolia.registerAdminViaOwner(
            address(sourceRebaseToken)
        );
        // Accept role on Sepolia
        tokenAdminRegistrySepolia = TokenAdminRegistry(
            sepoliaNetworkDetails.tokenAdminRegistryAddress
        );
        tokenAdminRegistrySepolia.acceptAdminRole(address(sourceRebaseToken));
        // Link token to pool in the token admin registry on Sepolia
        tokenAdminRegistrySepolia.setPool(
            address(sourceRebaseToken),
            address(sourcePool)
        );
        vm.stopPrank();

        // 3. Deploy and configure on the destination chain: Arbitrum
        // Deploy the token contract on Arbitrum
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        console.log("Deploying token on Arbitrum");
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        destRebaseToken = new RebaseToken();
        console.log("dest rebase token address");
        console.log(address(destRebaseToken));
        // Deploy the token pool on Arbitrum
        console.log("Deploying token pool on Arbitrum");
        destPool = new RebaseTokenPool(
            IERC20(address(destRebaseToken)),
            allowlist,
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        // Set pool on the token contract for permissions on Arbitrum
        destRebaseToken.grantMintAndBurnRole(address(destPool));
        // Claim role on Arbitrum
        registryModuleOwnerCustomarbSepolia = RegistryModuleOwnerCustom(
            arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress
        );
        registryModuleOwnerCustomarbSepolia.registerAdminViaOwner(
            address(destRebaseToken)
        );
        // Accept role on Arbitrum
        tokenAdminRegistryarbSepolia = TokenAdminRegistry(
            arbSepoliaNetworkDetails.tokenAdminRegistryAddress
        );
        tokenAdminRegistryarbSepolia.acceptAdminRole(address(destRebaseToken));
        // Link token to pool in the token admin registry on Arbitrum
        tokenAdminRegistryarbSepolia.setPool(
            address(destRebaseToken),
            address(destPool)
        );
        vm.stopPrank();
    }
    /// @notice Configures a local token pool to recognize and interact with a remote token pool on another chain.
    /// @dev Adds a remote chain/pool mapping with basic (disabled) rate limiter configs.
    /// @param fork The fork ID representing the local blockchain network to select.
    /// @param localPool The address of the TokenPool contract deployed on the local chain.
    /// @param remoteChainSelector The Chain Selector ID of the remote chain (used by CCIP).
    /// @param remotePool The address of the TokenPool contract deployed on the remote chain.
    /// @param remoteTokenAddress The address of the token on the remote chain associated with the pool.
    function configureTokenPool(
        uint256 fork,
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteTokenAddress
    ) public {
        // Select the local fork to simulate actions on the source chain
        vm.selectFork(fork);

        // Simulate the transaction as the contract owner
        vm.prank(owner);

        // Prepare array containing the encoded remote pool address
        bytes;
        remotePoolAddresses[0] = abi.encode(remotePool);

        // Define the remote chain config to be added to the local pool
        TokenPool.ChainUpdate;
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector, // Unique ID of the remote chain
            remotePoolAddresses: remotePoolAddresses, // Encoded remote pool address(es)
            remoteTokenAddress: abi.encode(remoteTokenAddress), // Encoded remote token address
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false, // No outbound rate limiting
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false, // No inbound rate limiting
                capacity: 0,
                rate: 0
            })
        });

        // Apply the remote chain configuration to the local TokenPool contract
        // No removals; only additions
        TokenPool(localPool).applyChainUpdates(new uint64, chainsToAdd);
    }

    /// @notice Simulates bridging tokens between two forks using Chainlink CCIP in a local test environment.
    /// @dev This function simulates a cross-chain token transfer, checks balances and user interest rates pre- and post-bridge.
    /// @param amountToBridge The amount of tokens to bridge from the local to the remote chain.
    /// @param localFork The fork ID of the source chain.
    /// @param remoteFork The fork ID of the destination chain.
    /// @param localNetworkDetails Metadata for the local network (router, LINK, etc).
    /// @param remoteNetworkDetails Metadata for the remote network (router, LINK, etc).
    /// @param localToken The RebaseToken instance deployed on the local fork.
    /// @param remoteToken The RebaseToken instance deployed on the remote fork.
    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        // Switch to local fork
        vm.selectFork(localFork);

        // Start simulating transactions from the user address
        vm.startPrank(user);

        // Prepare token transfer array
        Client.EVMTokenAmount;
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(localToken),
            amount: amountToBridge
        });

        // Construct the CCIP message with empty payload and token transfer
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user), // Address to receive tokens on remote chain
            data: "", // No extra data
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress, // Use LINK to pay for the CCIP fee
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0})) // Default extra args
        });

        // End prank
        vm.stopPrank();

        // Get estimated LINK fee from the router for the message
        uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(
            remoteNetworkDetails.chainSelector,
            message
        );

        // Request LINK from faucet for the user
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);

        // Approve LINK for router to cover fee
        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(
            localNetworkDetails.routerAddress,
            fee
        );

        // Approve token transfer to router
        vm.prank(user);
        IERC20(address(localToken)).approve(
            localNetworkDetails.routerAddress,
            amountToBridge
        );

        // Record balance before bridging
        uint256 localBalanceBefore = localToken.balanceOf(user);

        // Send the CCIP message
        vm.prank(user);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend{value: 0}(
            remoteNetworkDetails.chainSelector,
            message
        );

        // Confirm that the local token balance decreased by the bridged amount
        uint256 localBalanceAfter = localToken.balanceOf(user);
        assertEq(localBalanceAfter, localBalanceBefore - amountToBridge);

        // Capture user interest rate before switching forks
        uint256 localUserInteresetRate = localToken.getUserInterestRate(user);

        // Switch to remote fork (destination chain)
        vm.selectFork(remoteFork);

        // Simulate time passing to accrue interest (if any)
        vm.warp(block.timestamp + 20 minutes);

        // Capture balance before routing message
        uint256 remoteBalanceBefore = remoteToken.balanceOf(user);

        // Route the message (simulate CCIP delivery)
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

        // Capture balance after routing
        uint256 remoteBalanceAfter = remoteToken.balanceOf(user);

        // Confirm that the remote token balance increased correctly
        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);

        // Capture and verify that the user's interest rate carried over
        uint256 remoteUserInteresetRate = remoteToken.getUserInterestRate(user);
        assertEq(remoteUserInteresetRate, localUserInteresetRate);
    }
}
