// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice Mock ERC20 token for testing
contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}

/// @notice Interface for SignedDepositVault - all versions must implement this
interface ISignedDepositVault {
    struct DepositIntent {
        address depositor;
        uint256 assets;
        uint256 nonce;
        uint256 deadline;
    }

    struct MintIntent {
        address minter;
        uint256 shares;
        uint256 nonce;
        uint256 deadline;
    }

    function initialize(string memory name, string memory symbol, ERC20 asset) external;
    function depositWithSig(DepositIntent memory intent, bytes memory signature) external returns (uint256);
    function mintWithSig(MintIntent memory intent, bytes memory signature) external returns (uint256);
    function nonce(address account) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function asset() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function accureYield(uint256 assets) external returns (uint256);
    function slashYield(uint256 assets) external returns (uint256);

    // Error selectors
    error DeadlineExpired();
    error InvalidNonce();
    error InvalidSignature();
}

/// @notice Base test contract with shared test logic for all SignedDepositVault versions
/// @dev Each version-specific test contract should inherit from this and override setUp()
abstract contract SignedDepositVaultBaseTest is Test {
    ISignedDepositVault public vault;
    ERC20Mock public asset;

    uint256 constant MIN_ASSET_DEPOSIT = 1 ether;

    /// @notice Override this in version-specific test contracts to deploy the specific version
    function setUp() public virtual {
        // @note: This is intentionally empty - child contracts must override
    }

    // ============ Test Functions ============

    function test_VaultInitializesCorrectly() public {
        assertEq(vault.name(), "ezUSD Vault");
        assertEq(vault.symbol(), "ezUSDV");
        assertEq(vault.asset(), address(asset));
    }

    // ### Deposit Tests ###
    function testFuzz_DepositWithSig(uint64 _pk, uint256 _assets, address _relayer) public {
        _pk = uint64(bound(_pk, 1, type(uint64).max));
        address _depositor = vm.addr(_pk);
        _assets = bound(_assets, MIN_ASSET_DEPOSIT, type(uint128).max);
        vm.assume(_relayer != address(0) && _relayer != address(this));
        asset.mint(_depositor, _assets);
        vm.prank(_depositor);
        asset.approve(address(vault), _assets);

        uint256 shares = internal_depositWithSig(_depositor, _assets, block.timestamp + 1 hours, _pk, _relayer);

        assertGt(shares, 0);
        assertGt(vault.balanceOf(_depositor), 0);
    }

    function testFuzz_DepositWithSig_ReplayAttackFails(uint64 _pk, uint256 _assets, address _relayer) public {
        _pk = uint64(bound(_pk, 1, type(uint64).max));
        address _depositor = vm.addr(_pk);
        _assets = bound(_assets, MIN_ASSET_DEPOSIT, type(uint128).max);
        vm.assume(_relayer != address(0) && _relayer != address(this));
        asset.mint(_depositor, _assets);
        vm.prank(_depositor);
        asset.approve(address(vault), _assets);

        uint256 deadline = block.timestamp + 1 hours;

        uint256 nonce = vault.nonce(_depositor);
        internal_depositWithSig(_depositor, _assets, deadline, _pk, _relayer);

        // Second deposit with same nonce should fail
        ISignedDepositVault.DepositIntent memory intent = ISignedDepositVault.DepositIntent({
            depositor: _depositor, assets: _assets, nonce: nonce, deadline: deadline
        });
        bytes memory sig = signDeposit(intent, _pk);

        vm.expectRevert(ISignedDepositVault.InvalidNonce.selector);
        vm.startPrank(_relayer);
        vault.depositWithSig(intent, sig);
        vm.stopPrank();
    }

    function testFuzz_DepositWithSig_DeadlineExpiredFails(uint64 _pk, uint256 _assets, address _relayer) public {
        _pk = uint64(bound(_pk, 1, type(uint64).max));
        address _depositor = vm.addr(_pk);
        _assets = bound(_assets, MIN_ASSET_DEPOSIT, type(uint128).max);
        vm.assume(_relayer != address(0) && _relayer != address(this));
        asset.mint(_depositor, _assets);
        vm.prank(_depositor);
        asset.approve(address(vault), _assets);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = vault.nonce(_depositor);

        // Warp time past deadline
        vm.warp(deadline + 2 hours);

        // Deposit with expired deadline should fail
        ISignedDepositVault.DepositIntent memory intent = ISignedDepositVault.DepositIntent({
            depositor: _depositor, assets: _assets, nonce: nonce, deadline: deadline
        });
        bytes memory sig = signDeposit(intent, _pk);

        vm.expectRevert(ISignedDepositVault.DeadlineExpired.selector);
        vm.startPrank(_relayer);
        vault.depositWithSig(intent, sig);
        vm.stopPrank();
    }

    function testFuzz_DepositWithSig_InvalidSignatureFails(
        uint64 _pk,
        uint256 _assets,
        address _relayer,
        uint64 _wrongPk
    ) public {
        _pk = uint64(bound(_pk, 1, type(uint64).max));
        _wrongPk = uint64(bound(_wrongPk, 1, type(uint64).max));
        vm.assume(_wrongPk != _pk);
        address _depositor = vm.addr(_pk);
        _assets = bound(_assets, MIN_ASSET_DEPOSIT, type(uint128).max);
        vm.assume(_relayer != address(0) && _relayer != address(this));
        asset.mint(_depositor, _assets);
        vm.prank(_depositor);
        asset.approve(address(vault), _assets);
        internal_depositWithSig(_depositor, _assets, block.timestamp + 1 hours, _pk, _relayer);

        uint256 nonce = vault.nonce(_depositor);
        uint256 deadline = block.timestamp + 1 hours;

        // Use wrong signer (_wrongPk instead of _pk)
        ISignedDepositVault.DepositIntent memory intent = ISignedDepositVault.DepositIntent({
            depositor: _depositor, assets: _assets, nonce: nonce, deadline: deadline
        });
        bytes memory invalidSig = signDeposit(intent, _wrongPk);

        vm.expectRevert(ISignedDepositVault.InvalidSignature.selector);
        vm.startPrank(_relayer);
        vault.depositWithSig(intent, invalidSig);
        vm.stopPrank();
    }

    // ### Mint Tests ###
    function testFuzz_MintWithSig(uint64 _pk, uint256 _shares, address _relayer) public {
        _pk = uint64(bound(_pk, 1, type(uint64).max));
        address _minter = vm.addr(_pk);
        vm.assume(_shares > 0);
        _shares = bound(_shares, 1 wei, 1000 ether);
        vm.assume(_relayer != address(0) && _relayer != address(this));
        asset.mint(_minter, 1000 ether);
        vm.prank(_minter);
        asset.approve(address(vault), 1000 ether);

        uint256 assets = internal_mintWithSig(_minter, _shares, block.timestamp + 1 hours, _pk, _relayer);

        assertGt(assets, 0);
        assertGt(vault.balanceOf(_minter), 0);
    }

    function testFuzz_MintWithSig_ReplayAttackFails(uint64 _pk, uint256 _shares, address _relayer) public {
        _pk = uint64(bound(_pk, 1, type(uint64).max));
        address _minter = vm.addr(_pk);
        vm.assume(_shares > 0);
        _shares = bound(_shares, 1 wei, 1000 ether);
        vm.assume(_relayer != address(0) && _relayer != address(this));
        asset.mint(_minter, 1000 ether);
        vm.prank(_minter);
        asset.approve(address(vault), 1000 ether);

        uint256 deadline = block.timestamp + 1 hours;

        uint256 nonce = vault.nonce(_minter);
        internal_mintWithSig(_minter, _shares, deadline, _pk, _relayer);

        // Second mint with same nonce should fail
        ISignedDepositVault.MintIntent memory intent =
            ISignedDepositVault.MintIntent({minter: _minter, shares: _shares, nonce: nonce, deadline: deadline});
        bytes memory sig = signMint(intent, _pk);

        vm.expectRevert(ISignedDepositVault.InvalidNonce.selector);
        vm.startPrank(_relayer);
        vault.mintWithSig(intent, sig);
        vm.stopPrank();
    }

    function testFuzz_MintWithSig_DeadlineExpiredFails(uint64 _pk, uint256 _shares, address _relayer) public {
        _pk = uint64(bound(_pk, 1, type(uint64).max));
        address _minter = vm.addr(_pk);
        vm.assume(_shares > 0);
        _shares = bound(_shares, 1 wei, 1000 ether);
        vm.assume(_relayer != address(0) && _relayer != address(this));
        asset.mint(_minter, 1000 ether);
        vm.prank(_minter);
        asset.approve(address(vault), 1000 ether);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = vault.nonce(_minter);

        // Warp time past deadline
        vm.warp(deadline + 2 hours);

        // Mint with expired deadline should fail
        ISignedDepositVault.MintIntent memory intent =
            ISignedDepositVault.MintIntent({minter: _minter, shares: _shares, nonce: nonce, deadline: deadline});
        bytes memory sig = signMint(intent, _pk);

        vm.expectRevert(ISignedDepositVault.DeadlineExpired.selector);
        vm.startPrank(_relayer);
        vault.mintWithSig(intent, sig);
        vm.stopPrank();
    }

    function testFuzz_MintWithSig_InvalidSignatureFails(uint64 _pk, uint256 _shares, address _relayer, uint64 _wrongPk)
        public
    {
        _pk = uint64(bound(_pk, 1, type(uint64).max));
        _wrongPk = uint64(bound(_wrongPk, 1, type(uint64).max));
        vm.assume(_wrongPk != _pk);
        address _minter = vm.addr(_pk);
        vm.assume(_shares > 0);
        _shares = bound(_shares, 1 wei, 1000 ether);
        vm.assume(_relayer != address(0) && _relayer != address(this));
        asset.mint(_minter, 1000 ether);
        vm.prank(_minter);
        asset.approve(address(vault), 1000 ether);
        internal_mintWithSig(_minter, _shares, block.timestamp + 1 hours, _pk, _relayer);

        uint256 nonce = vault.nonce(_minter);
        uint256 deadline = block.timestamp + 1 hours;

        // Use wrong signer (_wrongPk instead of _pk)
        ISignedDepositVault.MintIntent memory intent =
            ISignedDepositVault.MintIntent({minter: _minter, shares: _shares, nonce: nonce, deadline: deadline});
        bytes memory invalidSig = signMint(intent, _wrongPk);

        vm.expectRevert(ISignedDepositVault.InvalidSignature.selector);
        vm.startPrank(_relayer);
        vault.mintWithSig(intent, invalidSig);
        vm.stopPrank();
    }

    // ============ Helper Functions ============

    /// @notice Internal helper function to execute a deposit with signature
    /// @dev Automatically fetches the current valid nonce from the vault contract
    function internal_depositWithSig(
        address depositor,
        uint256 assets,
        uint256 deadline,
        uint256 signerPk,
        address relayer
    ) internal returns (uint256) {
        // Fetch the current valid nonce from the vault contract
        uint256 currentNonce = vault.nonce(depositor);

        ISignedDepositVault.DepositIntent memory intent = ISignedDepositVault.DepositIntent({
            depositor: depositor, assets: assets, nonce: currentNonce, deadline: deadline
        });

        bytes memory signature = signDeposit(intent, signerPk);

        vm.startPrank(relayer);
        uint256 shares = vault.depositWithSig(intent, signature);
        vm.stopPrank();

        return shares;
    }

    /// @notice Internal helper function to execute a mint with signature
    /// @dev Automatically fetches the current valid nonce from the vault contract
    function internal_mintWithSig(address minter, uint256 shares, uint256 deadline, uint256 signerPk, address relayer)
        internal
        returns (uint256)
    {
        // Fetch the current valid nonce from the vault contract
        uint256 currentNonce = vault.nonce(minter);

        ISignedDepositVault.MintIntent memory intent =
            ISignedDepositVault.MintIntent({minter: minter, shares: shares, nonce: currentNonce, deadline: deadline});

        bytes memory signature = signMint(intent, signerPk);

        vm.startPrank(relayer);
        uint256 assets = vault.mintWithSig(intent, signature);
        vm.stopPrank();

        return assets;
    }

    function signDeposit(ISignedDepositVault.DepositIntent memory intent, uint256 signerPk)
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

    function signMint(ISignedDepositVault.MintIntent memory intent, uint256 signerPk)
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

