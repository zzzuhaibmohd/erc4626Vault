// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {SignedDepositVaultV1} from "../src/SignedDepositVaultV1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Mock ERC20 token for deployment
contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}

/// @notice Deploy script for SignedDepositVaultV1 (Localhost/Anvil version)
/// @dev Uses the default anvil account (0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266)
///      No PRIVATE_KEY environment variable needed
contract DeploySignedDepositVaultLocal is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("LOCAL_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deploying SignedDepositVaultV1 to localhost/anvil...");
        console2.log("Deployer address:", deployer);

        // Step 1: Deploy mock ERC20 asset token
        console2.log("\n1. Deploying ERC20Mock asset token...");
        ERC20Mock asset = new ERC20Mock("ezUSD Token", "ezUSD");
        console2.log("Asset token deployed at:", address(asset));

        // Step 2: Deploy V1 implementation
        console2.log("\n2. Deploying SignedDepositVaultV1 implementation...");
        SignedDepositVaultV1 implementation = new SignedDepositVaultV1();
        console2.log("Implementation deployed at:", address(implementation));

        // Step 3: Encode initialize function call
        console2.log("\n3. Encoding initialization data...");
        bytes memory initData =
            abi.encodeWithSelector(SignedDepositVaultV1.initialize.selector, "ezUSD Vault", "ezUSDV", asset);

        // Step 4: Deploy proxy with initialization
        console2.log("\n4. Deploying ERC1967Proxy...");
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console2.log("Proxy deployed at:", address(proxy));

        // Step 5: Cast proxy to vault
        SignedDepositVaultV1 vault = SignedDepositVaultV1(payable(address(proxy)));

        vm.stopBroadcast();

        // Log deployment summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("Asset Token:", address(asset));
        console2.log("Implementation:", address(implementation));
        console2.log("Proxy (Vault):", address(proxy));
        console2.log("Vault Name:", vault.name());
        console2.log("Vault Symbol:", vault.symbol());
        console2.log("Vault Owner:", vault.owner());
        console2.log("Domain Separator:", vm.toString(vault.DOMAIN_SEPARATOR()));
        console2.log("========================\n");
    }
}

