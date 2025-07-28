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
    /**
     * @notice Configures a token pool for cross-chain communication.
     * @dev Sets up the remote pool and token addresses for a given fork and chain selector.
     * @param fork The fork ID to select (chain to configure).
     * @param localPool The address of the local token pool contract.
     * @param remoteChainSelector The chain selector for the remote chain.
     * @param remotePool The address of the remote token pool contract.
     * @param remoteTokenAddress The address of the remote token contract.
     */
    function configureTokenPool(
        uint256 fork, // The fork ID to select
        address localPool, // The address of the local token pool
        uint64 remoteChainSelector, // The selector for the remote chain
        address remotePool, // The address of the remote pool
        address remoteTokenAddress // The address of the remote token
    ) public {
        vm.selectFork(fork); // Switch to the specified fork (chain)
        vm.prank(owner); // Execute the following as the owner

        bytes[] memory remotePoolAddresses = new bytes[](1); // Create an array for remote pool addresses
        remotePoolAddresses[0] = abi.encode(remotePool); // Encode the remote pool address

        TokenPool.ChainUpdate[]
            memory chainsToAdd = new TokenPool.ChainUpdate[](1); // Create an array for chain updates
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector, // Set the remote chain selector
            remotePoolAddresses: remotePoolAddresses, // Set the remote pool addresses
            remoteTokenAddress: abi.encode(remoteTokenAddress), // Encode and set the remote token address
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false, // Disable outbound rate limiter
                capacity: 0, // Set outbound capacity to 0
                rate: 0 // Set outbound rate to 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false, // Disable inbound rate limiter
                capacity: 0, // Set inbound capacity to 0
                rate: 0 // Set inbound rate to 0
            })
        });

        TokenPool(localPool).applyChainUpdates(new uint64[](0), chainsToAdd); // Apply the chain updates to the local pool
    }
    /**
     * @notice Bridges tokens from a local chain to a remote chain using CCIP.
     * @dev Handles approval, fee payment, and message routing for cross-chain token transfer.
     * @param amountToBridge The amount of tokens to bridge.
     * @param localFork The fork ID of the local chain.
     * @param remoteFork The fork ID of the remote chain.
     * @param localNetworkDetails Network details for the local chain.
     * @param remoteNetworkDetails Network details for the remote chain.
     * @param localToken The token contract on the local chain.
     * @param remoteToken The token contract on the remote chain.
     */
    function bridgeTokens(
        uint256 amountToBridge, // Amount of tokens to bridge
        uint256 localFork, // Fork ID for the local chain
        uint256 remoteFork, // Fork ID for the remote chain
        Register.NetworkDetails memory localNetworkDetails, // Local chain network details
        Register.NetworkDetails memory remoteNetworkDetails, // Remote chain network details
        RebaseToken localToken, // Local chain token contract
        RebaseToken remoteToken // Remote chain token contract
    ) public {
        vm.selectFork(localFork); // Switch to the local chain fork
        vm.startPrank(user); // Start transaction as the user

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1); // Create array for token amounts
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(localToken), // Set token address
            amount: amountToBridge // Set amount to bridge
        });

        // Construct the CCIP message for cross-chain transfer
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user), // Encode user address as receiver on destination chain
            data: "", // No additional data payload
            tokenAmounts: tokenAmounts, // Token transfer details
            feeToken: localNetworkDetails.linkAddress, // Use LINK as fee token
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0})) // Extra arguments (gas limit 0)
        });

        vm.stopPrank(); // Stop transaction as the user

        uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(
            remoteNetworkDetails.chainSelector, // Destination chain selector
            message // CCIP message
        ); // Query the fee for the cross-chain message

        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee); // Fund user with LINK for fee

        vm.prank(user); // Next call as user
        IERC20(localNetworkDetails.linkAddress).approve(
            localNetworkDetails.routerAddress, // Approve router to spend LINK
            fee // Amount to approve
        );

        vm.prank(user); // Next call as user
        IERC20(address(localToken)).approve(
            localNetworkDetails.routerAddress, // Approve router to spend tokens
            amountToBridge // Amount to approve
        );

        uint256 localBalanceBefore = localToken.balanceOf(user); // Record user's local token balance before bridging

        vm.prank(user); // Next call as user
        IRouterClient(localNetworkDetails.routerAddress).ccipSend{value: 0}(
            remoteNetworkDetails.chainSelector, // Destination chain selector
            message // CCIP message
        ); // Send the cross-chain message

        uint256 localBalanceAfter = localToken.balanceOf(user); // Record user's local token balance after bridging

        assertEq(localBalanceAfter, localBalanceBefore - amountToBridge); // Assert tokens were deducted locally

        uint256 localUserInteresetRate = localToken.getUserInterestRate(user); // Get user's interest rate on local chain

        vm.selectFork(remoteFork); // Switch to the remote chain fork

        vm.warp(block.timestamp + 20 minutes); // Advance time to simulate message arrival

        uint256 remoteBalanceBefore = remoteToken.balanceOf(user); // Record user's remote token balance before bridging

        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork); // Route the CCIP message to the remote chain

        uint256 remoteBalanceAfter = remoteToken.balanceOf(user); // Record user's remote token balance after bridging

        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge); // Assert tokens were credited remotely

        uint256 remoteUserInteresetRate = remoteToken.getUserInterestRate(user); // Get user's interest rate on remote chain

        assertEq(remoteUserInteresetRate, localUserInteresetRate); // Assert interest rate is preserved across chains
    }
}
