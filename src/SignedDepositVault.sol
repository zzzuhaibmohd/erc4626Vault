//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title  SignedDepositVault
 * @author
 * @notice ERC4626 vault with EIP-712 signed deposit and mint operations
 * @dev    This contract extends ERC4626 to support meta-transactions via EIP-712 signatures.
 *         Users can sign deposit/mint intents off-chain and have them executed by any relayer.
 *         The contract uses nonces to prevent replay attacks and includes deadline checks.
 */
contract SignedDepositVault is
    ERC4626Upgradeable,
    EIP712Upgradeable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard
{
    using ECDSA for bytes32;

    //Custom Errors
    error DeadlineExpired();
    error InvalidNonce();
    error InvalidSignature();

    // Event
    event Deposit(address indexed depositor, uint256 amount, uint256 shares);
    event Mint(address indexed minter, uint256 amount, uint256 shares);

    // EIP 712 Variables
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

    bytes32 internal constant DEPOSIT_INTENT_TYPEHASH =
        keccak256("DepositIntent(address depositor,uint256 assets,uint256 nonce,uint256 deadline)");

    /// @notice EIP-712 typehash for mint intents
    bytes32 internal constant MINT_INTENT_TYPEHASH =
        keccak256("MintIntent(address minter,uint256 shares,uint256 nonce,uint256 deadline)");

    // Nonces
    mapping(address => uint256) internal _nonces;

    function nonce(address account) public view returns (uint256) {
        return _nonces[account];
    }

    constructor()
        ERC4626Upgradeable()
        EIP712Upgradeable()
        Ownable2StepUpgradeable()
        UUPSUpgradeable()
        ReentrancyGuard()
    {
        _disableInitializers();
    }

    function initialize(string memory name, string memory symbol, IERC20 asset) public initializer {
        __ERC20_init(name, symbol);
        __ERC4626_init(asset);
        __EIP712_init("SignedDepositVault", "1");
        __Ownable_init(msg.sender);
    }

    /// @notice Executes a deposit using an EIP-712 signed intent
    /// @param intent The deposit intent containing depositor, amount, nonce, and deadline
    /// @param signature The ECDSA signature of the intent
    /// @return shares The amount of shares minted to the depositor
    function depositWithSig(DepositIntent memory intent, bytes memory signature) public nonReentrant returns (uint256) {
        if (block.timestamp > intent.deadline) {
            revert DeadlineExpired();
        }

        if (intent.nonce != nonce(intent.depositor)) {
            revert InvalidNonce();
        }
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(DEPOSIT_INTENT_TYPEHASH, intent.depositor, intent.assets, intent.nonce, intent.deadline)
            )
        );

        if (digest.recover(signature) != intent.depositor) {
            revert InvalidSignature();
        }

        _nonces[intent.depositor]++;

        IERC20(asset()).transferFrom(intent.depositor, address(this), intent.assets);
        uint256 shares = previewDeposit(intent.assets);
        _mint(intent.depositor, shares);
        emit Deposit(intent.depositor, intent.assets, shares);
        return shares;
    }

    /// @notice Executes a mint using an EIP-712 signed intent
    /// @param intent The mint intent containing minter, shares, nonce, and deadline
    /// @param signature The ECDSA signature of the intent
    /// @return assets The amount of assets deposited
    function mintWithSig(MintIntent memory intent, bytes memory signature) public nonReentrant returns (uint256) {
        if (block.timestamp > intent.deadline) {
            revert DeadlineExpired();
        }

        if (intent.nonce != nonce(intent.minter)) {
            revert InvalidNonce();
        }

        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(MINT_INTENT_TYPEHASH, intent.minter, intent.shares, intent.nonce, intent.deadline))
        );

        if (digest.recover(signature) != intent.minter) {
            revert InvalidSignature();
        }

        _nonces[intent.minter]++;

        uint256 assets = previewMint(intent.shares);
        IERC20(asset()).transferFrom(intent.minter, address(this), assets);
        _mint(intent.minter, intent.shares);
        emit Mint(intent.minter, intent.shares, assets);
        return assets;
    }

    // UUPS functions
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[49] private __gap;
}
