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
    address user = makeAddr("user");
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    uint256 public SEND_VALUE = 1e5;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    RebaseToken arbSepoliaToken;
    RebaseToken sepoliaToken;

    RebaseTokenPool arbSepoliaPool;
    RebaseTokenPool sepoliaPool;

    TokenAdminRegistry tokenAdminRegistrySepolia;
    TokenAdminRegistry tokenAdminRegistryarbSepolia;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    RegistryModuleOwnerCustom registryModuleOwnerCustomSepolia;
    RegistryModuleOwnerCustom registryModuleOwnerCustomarbSepolia;

    Vault vault;

    // SourceDeployer sourceDeployer;
    /// @notice Sets up the test environment by deploying contracts and configuring forks for Sepolia and Arbitrum Sepolia.
    function setUp() public {
        address[] memory allowlist = new address[](0); // Create an empty allowlist array

        sepoliaFork = vm.createSelectFork("eth"); // Create and select Sepolia fork
        arbSepoliaFork = vm.createFork("arb"); // Create Arbitrum Sepolia fork

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork(); // Deploy CCIP local simulator
        vm.makePersistent(address(ccipLocalSimulatorFork)); // Make simulator persistent across forks

        // Deploy and configure contracts on Sepolia fork
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        ); // Get Sepolia network details
        vm.startPrank(owner); // Start impersonating owner
        sepoliaToken = new RebaseToken(); // Deploy Sepolia RebaseToken
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)), // Use Sepolia token as ERC20
            allowlist, // Pass empty allowlist
            sepoliaNetworkDetails.rmnProxyAddress, // Set RMN proxy address
            sepoliaNetworkDetails.routerAddress // Set router address
        );
        vault = new Vault(IRebaseToken(address(sepoliaToken))); // Deploy Vault for Sepolia token
        vm.deal(address(vault), 1e18); // Fund the vault with ETH
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool)); // Grant pool mint/burn role
        sepoliaToken.grantMintAndBurnRole(address(vault)); // Grant vault mint/burn role
        registryModuleOwnerCustomSepolia = RegistryModuleOwnerCustom(
            sepoliaNetworkDetails.registryModuleOwnerCustomAddress // Get registry module owner custom address
        );
        registryModuleOwnerCustomSepolia.registerAdminViaOwner(
            address(sepoliaToken)
        ); // Register admin for token
        tokenAdminRegistrySepolia = TokenAdminRegistry(
            sepoliaNetworkDetails.tokenAdminRegistryAddress // Get token admin registry address
        );
        tokenAdminRegistrySepolia.acceptAdminRole(address(sepoliaToken)); // Accept admin role for token
        tokenAdminRegistrySepolia.setPool(
            address(sepoliaToken),
            address(sepoliaPool)
        ); // Set pool for token
        vm.stopPrank(); // Stop impersonating owner

        // Deploy and configure contracts on Arbitrum Sepolia fork
        vm.selectFork(arbSepoliaFork); // Switch to Arbitrum Sepolia fork
        vm.startPrank(owner); // Start impersonating owner
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        ); // Get Arbitrum Sepolia network details
        arbSepoliaToken = new RebaseToken(); // Deploy Arbitrum Sepolia RebaseToken
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)), // Use Arbitrum Sepolia token as ERC20
            allowlist, // Pass empty allowlist
            arbSepoliaNetworkDetails.rmnProxyAddress, // Set RMN proxy address
            arbSepoliaNetworkDetails.routerAddress // Set router address
        );
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool)); // Grant pool mint/burn role
        registryModuleOwnerCustomarbSepolia = RegistryModuleOwnerCustom(
            arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress // Get registry module owner custom address
        );
        registryModuleOwnerCustomarbSepolia.registerAdminViaOwner(
            address(arbSepoliaToken)
        ); // Register admin for token
        tokenAdminRegistryarbSepolia = TokenAdminRegistry(
            arbSepoliaNetworkDetails.tokenAdminRegistryAddress // Get token admin registry address
        );
        tokenAdminRegistryarbSepolia.acceptAdminRole(address(arbSepoliaToken)); // Accept admin role for token
        tokenAdminRegistryarbSepolia.setPool(
            address(arbSepoliaToken),
            address(arbSepoliaPool)
        ); // Set pool for token
        vm.stopPrank(); // Stop impersonating owner
    }

    /// @notice Configures a local token pool to recognize a remote pool and token for cross-chain operations.
    /// @param fork The fork identifier to select.
    /// @param localPool The local token pool to configure.
    /// @param remotePool The remote token pool to link.
    /// @param remoteToken The remote token contract.
    /// @param remoteNetworkDetails Network details for the remote chain.
    function configureTokenPool(
        uint256 fork,
        TokenPool localPool,
        TokenPool remotePool,
        IRebaseToken remoteToken,
        Register.NetworkDetails memory remoteNetworkDetails
    ) public {
        vm.selectFork(fork); // Select the target fork
        vm.startPrank(owner); // Start impersonating owner
        TokenPool.ChainUpdate[] memory chains = new TokenPool.ChainUpdate[](1); // Prepare chain update array
        bytes[] memory remotePoolAddresses = new bytes[](1); // Prepare remote pool addresses array
        remotePoolAddresses[0] = abi.encode(address(remotePool)); // Encode remote pool address
        chains[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteNetworkDetails.chainSelector, // Set remote chain selector
            remotePoolAddresses: remotePoolAddresses, // Set remote pool addresses
            remoteTokenAddress: abi.encode(address(remoteToken)), // Encode remote token address
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false, // Disable outbound rate limiter
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false, // Disable inbound rate limiter
                capacity: 0,
                rate: 0
            })
        });
        uint64[] memory remoteChainSelectorsToRemove = new uint64[](0); // No chains to remove
        localPool.applyChainUpdates(remoteChainSelectorsToRemove, chains); // Apply chain updates to local pool
        vm.stopPrank(); // Stop impersonating owner
    }

    /// @notice Bridges tokens from a local chain to a remote chain using CCIP.
    /// @param amountToBridge The amount of tokens to bridge.
    /// @param localFork The fork identifier for the local chain.
    /// @param remoteFork The fork identifier for the remote chain.
    /// @param localNetworkDetails Network details for the local chain.
    /// @param remoteNetworkDetails Network details for the remote chain.
    /// @param localToken The token contract on the local chain.
    /// @param remoteToken The token contract on the remote chain.
    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        vm.selectFork(localFork); // Select the local fork
        vm.startPrank(user); // Start impersonating user
        Client.EVMTokenAmount[]
            memory tokenToSendDetails = new Client.EVMTokenAmount[](1); // Prepare token amount array
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(localToken), // Set token address
            amount: amountToBridge // Set amount to bridge
        });
        tokenToSendDetails[0] = tokenAmount; // Assign token amount
        IERC20(address(localToken)).approve(
            localNetworkDetails.routerAddress,
            amountToBridge
        ); // Approve router to spend tokens
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user), // Set receiver address
            data: "",
            tokenAmounts: tokenToSendDetails, // Set token amounts
            extraArgs: "",
            feeToken: localNetworkDetails.linkAddress // Set LINK as fee token
        });
        vm.stopPrank(); // Stop impersonating user
        ccipLocalSimulatorFork.requestLinkFromFaucet(
            user,
            IRouterClient(localNetworkDetails.routerAddress).getFee(
                remoteNetworkDetails.chainSelector,
                message
            )
        ); // Request LINK from faucet for fee
        vm.startPrank(user); // Start impersonating user again
        IERC20(localNetworkDetails.linkAddress).approve(
            localNetworkDetails.routerAddress,
            IRouterClient(localNetworkDetails.routerAddress).getFee(
                remoteNetworkDetails.chainSelector,
                message
            )
        ); // Approve router to spend LINK for fee
        uint256 balanceBeforeBridge = IERC20(address(localToken)).balanceOf(
            user
        ); // Get user token balance before bridge
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(
            remoteNetworkDetails.chainSelector,
            message
        ); // Send CCIP message to bridge tokens
        uint256 sourceBalanceAfterBridge = IERC20(address(localToken))
            .balanceOf(user); // Get user token balance after bridge
        assertEq(
            sourceBalanceAfterBridge,
            balanceBeforeBridge - amountToBridge
        ); // Assert tokens were deducted
        vm.stopPrank(); // Stop impersonating user

        vm.selectFork(remoteFork); // Switch to remote fork
        vm.warp(block.timestamp + 900); // Advance time to simulate message arrival
        uint256 initialArbBalance = IERC20(address(remoteToken)).balanceOf(
            user
        ); // Get user token balance on remote chain
        vm.selectFork(localFork); // Switch back to local fork
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork); // Route CCIP message to remote fork

        uint256 destBalance = IERC20(address(remoteToken)).balanceOf(user); // Get user token balance after bridge on remote chain
        assertEq(destBalance, initialArbBalance + amountToBridge); // Assert tokens were received
    }

    /// @notice Tests bridging all tokens from Sepolia to Arbitrum Sepolia.
    function testBridgeAllTokens() public {
        configureTokenPool(
            sepoliaFork,
            sepoliaPool,
            arbSepoliaPool,
            IRebaseToken(address(arbSepoliaToken)),
            arbSepoliaNetworkDetails
        ); // Configure Sepolia pool to recognize Arbitrum Sepolia pool
        configureTokenPool(
            arbSepoliaFork,
            arbSepoliaPool,
            sepoliaPool,
            IRebaseToken(address(sepoliaToken)),
            sepoliaNetworkDetails
        ); // Configure Arbitrum Sepolia pool to recognize Sepolia pool
        vm.selectFork(sepoliaFork); // Select Sepolia fork
        vm.deal(user, SEND_VALUE); // Fund user with tokens
        vm.startPrank(user); // Start impersonating user
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}(); // Deposit tokens into vault
        uint256 startBalance = IERC20(address(sepoliaToken)).balanceOf(user); // Get user token balance after deposit
        assertEq(startBalance, SEND_VALUE); // Assert deposit was successful
        vm.stopPrank(); // Stop impersonating user
        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaToken,
            arbSepoliaToken
        ); // Bridge all tokens from Sepolia to Arbitrum Sepolia
    }
}
