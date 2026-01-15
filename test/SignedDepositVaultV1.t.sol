// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SignedDepositVaultBaseTest, ISignedDepositVault} from "./SignedDepositVaultBase.t.sol";
import {DeploySignedDepositVaultHelper} from "../script/DeploySignedDepositVaultHelper.sol";
import {console2} from "forge-std/console2.sol";

/// @notice Test contract for SignedDepositVaultV1
/// @dev Inherits all test logic from SignedDepositVaultBaseTest and only overrides setUp() to deploy V1
contract SignedDepositVaultV1Test is SignedDepositVaultBaseTest {
    using DeploySignedDepositVaultHelper for *;

    function setUp() public override {
        // Deploy using the shared helper (same as deployment script)
        DeploySignedDepositVaultHelper.DeploymentResult memory result =
            DeploySignedDepositVaultHelper.deploy("ezUSD Token", "ezUSD", "ezUSD Vault", "ezUSDV");

        // Set the asset and vault from the deployment result
        asset = result.asset;
        vault = ISignedDepositVault(payable(address(result.vault)));
    }

    // ### Deposit and Mint Tests ###
    function testFuzz_DepositDirectly(uint64 _pk, uint256 _assets) public {
        _pk = uint64(bound(_pk, 1, type(uint64).max));
        address _depositor = vm.addr(_pk);
        _assets = bound(_assets, 1 ether, type(uint128).max);
        asset.mint(_depositor, _assets);
        vm.startPrank(_depositor);
        asset.approve(address(vault), _assets);
        uint256 shares = vault.deposit(_assets, _depositor);
        vm.stopPrank();
        assertGt(shares, 0);
        assertGt(vault.balanceOf(_depositor), 0);
    }

    function testFuzz_MintDirectly(uint64 _pk, uint256 _shares) public {
        _pk = uint64(bound(_pk, 1, type(uint64).max));
        address _minter = vm.addr(_pk);
        _shares = bound(_shares, 1 wei, 1000 ether);
        asset.mint(_minter, 1000 ether);
        vm.startPrank(_minter);
        asset.approve(address(vault), 1000 ether);
        uint256 assets = vault.mint(_shares, _minter);
        vm.stopPrank();
        assertGt(assets, 0);
        assertGt(vault.balanceOf(_minter), 0);
    }

    // ### Yield Tests ###

    // @notice Test function to accure yield via deposit
    // @param _pk: The private key of the depositor
    // @param _assets: The amount of assets to deposit
    // @param _relayer: The address of the relayer
    // @param _yieldPercent: The percentage of the deposit to accure as yield
    // @dev This test deposits assets into the vault and then accures yield. It then checks that the share price has increased.
    function testFuzz_AccureYield_viaDeposit(uint64 _pk, uint256 _assets, address _relayer, uint256 _yieldPercent)
        public
    {
        _pk = uint64(bound(_pk, 1, type(uint64).max));
        vm.assume(_relayer != address(0) && _relayer != address(this));
        address _depositor = vm.addr(_pk);
        _assets = bound(_assets, 1 ether, type(uint128).max);
        asset.mint(_depositor, _assets);
        vm.prank(_depositor);
        asset.approve(address(vault), _assets);
        internal_depositWithSig(_depositor, _assets, block.timestamp + 1 hours, _pk, _relayer);

        // Bound yield to be between 0.1% and 50% of the deposit to ensure meaningful price increase
        _yieldPercent = bound(_yieldPercent, 1, 500); // 0.1% to 50% (scaled by 1000)
        uint256 _yield = (_assets * _yieldPercent) / 1000;
        // Ensure minimum yield of 1 wei to avoid zero yield
        if (_yield == 0) _yield = 1 wei;

        asset.mint(address(this), _yield);
        asset.approve(address(vault), _yield);
        uint256 oldPrice = vault.convertToAssets(1 ether);
        console2.log("Old price", oldPrice);
        console2.log("Yield", _yield);
        vault.accureYield(_yield);
        console2.log("New price", vault.convertToAssets(1 ether));

        uint256 newPrice = vault.convertToAssets(1 ether);
        assertGt(newPrice, oldPrice, "New price is not greater than old price");
    }

    // @notice Test function to slash yield via deposit
    // @param _pk: The private key of the depositor
    // @param _assets: The amount of assets to deposit
    // @param _relayer: The address of the relayer
    // @param _slashPercent: The percentage of the deposit to slash
    // @dev This test deposits assets into the vault and then slashes yield. It then checks that the share price has decreased.
    function testFuzz_SlashYield_viaDeposit(uint64 _pk, uint256 _assets, address _relayer, uint256 _slashPercent)
        public
    {
        _pk = uint64(bound(_pk, 1, type(uint64).max));
        vm.assume(_relayer != address(0) && _relayer != address(this));
        address _depositor = vm.addr(_pk);
        _assets = bound(_assets, 1 ether, type(uint128).max);
        asset.mint(_depositor, _assets);
        vm.prank(_depositor);
        asset.approve(address(vault), _assets);
        internal_depositWithSig(_depositor, _assets, block.timestamp + 1 hours, _pk, _relayer);

        // Bound slash to be between 0.1% and 50% of the deposit to ensure meaningful price decrease
        _slashPercent = bound(_slashPercent, 1, 500); // 0.1% to 50% (scaled by 1000)
        uint256 _slash = (_assets * _slashPercent) / 1000;
        // Ensure minimum slash of 1 wei to avoid zero slash
        if (_slash == 0) _slash = 1 wei;

        uint256 oldPrice = vault.convertToAssets(1 ether);
        console2.log("Old price", oldPrice);
        console2.log("Slash", _slash);
        vault.slashYield(_slash);
        console2.log("New price", vault.convertToAssets(1 ether));

        uint256 newPrice = vault.convertToAssets(1 ether);
        assertGt(oldPrice, newPrice, "Old price is not greater than new price");
    }
}
