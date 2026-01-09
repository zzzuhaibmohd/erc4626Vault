// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SignedDepositVaultV1} from "../src/SignedDepositVaultV1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20Mock} from "../test/SignedDepositVaultBase.t.sol";

/// @notice Helper library for deploying SignedDepositVaultV1
/// @dev Can be used in both deployment scripts and tests
library DeploySignedDepositVaultHelper {
    /// @notice Deployment result structure
    struct DeploymentResult {
        ERC20Mock asset;
        SignedDepositVaultV1 vault;
    }

    /// @notice Deploys a SignedDepositVaultV1 with a mock ERC20 asset
    /// @param assetName Name of the asset token
    /// @param assetSymbol Symbol of the asset token
    /// @param vaultName Name of the vault
    /// @param vaultSymbol Symbol of the vault
    /// @return result Deployment result containing asset and vault addresses
    function deploy(
        string memory assetName,
        string memory assetSymbol,
        string memory vaultName,
        string memory vaultSymbol
    ) internal returns (DeploymentResult memory result) {
        // Step 1: Deploy mock ERC20 asset token
        result.asset = new ERC20Mock(assetName, assetSymbol);

        // Step 2: Deploy V1 implementation
        SignedDepositVaultV1 implementation = new SignedDepositVaultV1();

        // Step 3: Encode initialize function call
        bytes memory initData =
            abi.encodeWithSelector(SignedDepositVaultV1.initialize.selector, vaultName, vaultSymbol, result.asset);

        // Step 4: Deploy proxy with initialization
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        // Step 5: Cast proxy to vault
        result.vault = SignedDepositVaultV1(payable(address(proxy)));
    }
}

