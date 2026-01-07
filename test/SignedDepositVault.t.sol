// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {SignedDepositVault} from "../src/SignedDepositVault.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}

contract SignedDepositVaultTest is Test {
    SignedDepositVault public vault;
    ERC20Mock public asset;

    //Setup users
    uint256 userOnePk = 0xA11CE;
    uint256 userTwoPk = 0xB0B;
    uint256 userThreePk = 0xC0DE;

    address userOne = vm.addr(userOnePk);
    address userTwo = vm.addr(uint256(userTwoPk));
    address userThree = vm.addr(uint256(userThreePk));

    function setUp() public {
        asset = new ERC20Mock("ezUSD Token", "ezUSD");

        // Deploy implementation
        SignedDepositVault implementation = new SignedDepositVault();

        // Encode initialize function call
        bytes memory initData =
            abi.encodeWithSelector(SignedDepositVault.initialize.selector, "ezUSD Vault", "ezUSDV", asset);

        // Deploy proxy with initialization
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        // Cast proxy to SignedDepositVault interface
        vault = SignedDepositVault(payable(address(proxy)));

        //Mint assets to users and approve the vault to spend them
        asset.mint(userOne, 1000 ether);
        asset.mint(userTwo, 1000 ether);
        asset.mint(userThree, 1000 ether);
        asset.mint(address(this), 10000 ether);

        vm.prank(userOne);
        asset.approve(address(vault), 1000 ether);
        vm.prank(userTwo);
        asset.approve(address(vault), 1000 ether);
        vm.prank(userThree);
        asset.approve(address(vault), 1000 ether);
        vm.prank(address(this));
        asset.approve(address(vault), 10000 ether);
    }

    function test_VaultInitializesCorrectly() public {
        assertEq(vault.name(), "ezUSD Vault");
        assertEq(vault.symbol(), "ezUSDV");
        assertEq(vault.asset(), address(asset));
    }

    // ### Deposit Tests ###
    function testFuzz_DepositWithSig(uint256 _assets) public {
        vm.assume(_assets > 0);
        _assets = bound(_assets, 1 wei, 1000 ether);
        uint256 shares = internal_depositWithSig(userOne, _assets, 0, block.timestamp + 1 hours, userOnePk, userThree);

        assertGt(shares, 0);
        assertGt(vault.balanceOf(userOne), 0);
    }

    function testFuzz_DepositWithSig_ReplayAttackFails(uint256 _assets) public {
        vm.assume(_assets > 0);
        _assets = bound(_assets, 1 wei, 1000 ether);
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;

        // First deposit should succeed
        internal_depositWithSig(userOne, _assets, nonce, deadline, userOnePk, userThree);

        // Second deposit with same nonce should fail
        SignedDepositVault.DepositIntent memory intent =
            SignedDepositVault.DepositIntent({depositor: userOne, assets: _assets, nonce: nonce, deadline: deadline});
        bytes memory sig = signDeposit(intent, userOnePk);

        vm.expectRevert(SignedDepositVault.InvalidNonce.selector);
        vm.prank(userTwo);
        vault.depositWithSig(intent, sig);
    }

    function testFuzz_DepositWithSig_DeadlineExpiredFails(uint256 _assets) public {
        vm.assume(_assets > 0);
        _assets = bound(_assets, 1 wei, 1000 ether);
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;

        // Warp time past deadline
        vm.warp(deadline + 2 hours);

        // Mint with same nonce should fail
        SignedDepositVault.DepositIntent memory intent =
            SignedDepositVault.DepositIntent({depositor: userOne, assets: _assets, nonce: nonce, deadline: deadline});
        bytes memory sig = signDeposit(intent, userOnePk);

        vm.expectRevert(SignedDepositVault.DeadlineExpired.selector);
        vm.prank(userThree);
        vault.depositWithSig(intent, sig);
    }

    function testFuzz_DepositWithSig_InvalidSignatureFails(uint256 _assets) public {
        vm.assume(_assets > 0);
        _assets = bound(_assets, 1 wei, 1000 ether);
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;

        // Use wrong signer (userTwoPk instead of userOnePk)
        SignedDepositVault.DepositIntent memory intent =
            SignedDepositVault.DepositIntent({depositor: userOne, assets: _assets, nonce: nonce, deadline: deadline});
        bytes memory invalidSig = signDeposit(intent, userTwoPk);

        vm.expectRevert(SignedDepositVault.InvalidSignature.selector);
        vm.prank(userThree);
        vault.depositWithSig(intent, invalidSig);
    }

    // ### Mint Tests ###
    function testFuzz_MintWithSig(uint256 _shares) public {
        vm.assume(_shares > 0);
        _shares = bound(_shares, 1 wei, 1000 ether);
        uint256 assets = internal_mintWithSig(userOne, _shares, 0, block.timestamp + 1 hours, userOnePk, userThree);

        assertGt(assets, 0);
        assertGt(vault.balanceOf(userOne), 0);
    }

    function testFuzz_MintWithSig_ReplayAttackFails(uint256 _shares) public {
        vm.assume(_shares > 0);
        _shares = bound(_shares, 1 wei, 1000 ether);
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;

        // First deposit should succeed
        internal_mintWithSig(userOne, _shares, nonce, deadline, userOnePk, userThree);

        // Second deposit with same nonce should fail
        SignedDepositVault.MintIntent memory intent =
            SignedDepositVault.MintIntent({minter: userOne, shares: _shares, nonce: nonce, deadline: deadline});
        bytes memory sig = signMint(intent, userOnePk);

        vm.expectRevert(SignedDepositVault.InvalidNonce.selector);
        vm.prank(userTwo);
        vault.mintWithSig(intent, sig);
    }

    function testFuzz_MintWithSig_DeadlineExpiredFails(uint256 _shares) public {
        vm.assume(_shares > 0);
        _shares = bound(_shares, 1 wei, 1000 ether);
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;

        // Warp time past deadline
        vm.warp(deadline + 2 hours);

        // Mint with same nonce should fail
        SignedDepositVault.MintIntent memory intent =
            SignedDepositVault.MintIntent({minter: userOne, shares: _shares, nonce: nonce, deadline: deadline});
        bytes memory sig = signMint(intent, userOnePk);

        vm.expectRevert(SignedDepositVault.DeadlineExpired.selector);
        vm.prank(userThree);
        vault.mintWithSig(intent, sig);
    }

    function testFuzz_MintWithSig_InvalidSignatureFails(uint256 _shares) public {
        vm.assume(_shares > 0);
        _shares = bound(_shares, 1 wei, 1000 ether);
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;

        // Use wrong signer (userTwoPk instead of userOnePk)
        SignedDepositVault.MintIntent memory intent =
            SignedDepositVault.MintIntent({minter: userOne, shares: _shares, nonce: nonce, deadline: deadline});
        bytes memory invalidSig = signMint(intent, userTwoPk);

        vm.expectRevert(SignedDepositVault.InvalidSignature.selector);
        vm.prank(userThree);
        vault.mintWithSig(intent, invalidSig);
    }

    // ### Yield Tests ###
    function test_AccureYield() public {
        internal_depositWithSig(userOne, 1000 ether, 0, block.timestamp + 1 hours, userOnePk, userThree);

        uint256 oldPrice = vault.getSharePrice();
        vault.accureYield(250 ether);

        uint256 newPrice = vault.getSharePrice();
        assertGt(newPrice, oldPrice);
    }

    function test_SlashYield() public {
        internal_depositWithSig(userOne, 1000 ether, 0, block.timestamp + 1 hours, userOnePk, userThree);

        uint256 oldPrice = vault.getSharePrice();
        vault.slashYield(250 ether);

        uint256 newPrice = vault.getSharePrice();
        assertGt(oldPrice, newPrice);
    }

    //### Helper Functions ###

    /// @notice Internal helper function to execute a deposit with signature
    /// @param depositor The address that will receive the shares
    /// @param assets The amount of assets to deposit
    /// @param nonce The nonce for this deposit (should match vault.nonce(depositor))
    /// @param deadline The deadline timestamp for the deposit
    /// @param signerPk The private key to sign the deposit intent
    /// @param relayer The address that will execute the deposit (can be address(0) to use msg.sender)
    /// @return shares The amount of shares minted to the depositor
    function internal_depositWithSig(
        address depositor,
        uint256 assets,
        uint256 nonce,
        uint256 deadline,
        uint256 signerPk,
        address relayer
    ) internal returns (uint256) {
        SignedDepositVault.DepositIntent memory intent = SignedDepositVault.DepositIntent({
            depositor: depositor, assets: assets, nonce: nonce, deadline: deadline
        });

        bytes memory signature = signDeposit(intent, signerPk);

        if (relayer != address(0)) {
            vm.prank(relayer);
        }

        return vault.depositWithSig(intent, signature);
    }

    function internal_mintWithSig(
        address minter,
        uint256 shares,
        uint256 nonce,
        uint256 deadline,
        uint256 signerPk,
        address relayer
    ) internal returns (uint256) {
        SignedDepositVault.MintIntent memory intent = SignedDepositVault.MintIntent({
            minter: minter, shares: shares, nonce: nonce, deadline: deadline
        });

        bytes memory signature = signMint(intent, signerPk);

        if (relayer != address(0)) {
            vm.prank(relayer);
        }

        return vault.mintWithSig(intent, signature);
    }

    function signDeposit(SignedDepositVault.DepositIntent memory intent, uint256 signerPk)
        internal
        view
        returns (bytes memory)
    {
        // 1. create struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("DepositIntent(address depositor,uint256 assets,uint256 nonce,uint256 deadline)"),
                intent.depositor,
                intent.assets,
                intent.nonce,
                intent.deadline
            )
        );

        //2. hash the struct hash with the domain separator to get EIP-712 digest
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", vault.DOMAIN_SEPARATOR(), structHash));

        //3. sign the digest with the signer's private key (must match intent.depositor)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);

        return abi.encodePacked(r, s, v);
    }

    function signMint(SignedDepositVault.MintIntent memory intent, uint256 signerPk)
        internal
        view
        returns (bytes memory)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("MintIntent(address minter,uint256 shares,uint256 nonce,uint256 deadline)"),
                intent.minter,
                intent.shares,
                intent.nonce,
                intent.deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", vault.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);

        return abi.encodePacked(r, s, v);
    }
}
