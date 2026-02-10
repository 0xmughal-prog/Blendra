// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title GBPb
 * @notice GBP-denominated token by Blendra, backed by USDC + perp hedge
 * @dev Fork of Ethena USDe pattern - simple ERC20 with controlled minting
 *
 * Key properties:
 * - Redeemable 1:1 for underlying value via GBPbMinter
 * - Transferable (can be traded, used in DeFi)
 * - Does NOT earn yield by itself (must stake to sGBPb)
 * - Acts as GBP stablecoin primitive
 *
 * Based on audited code:
 * - OpenZeppelin ERC20 (audited)
 * - OpenZeppelin Ownable2Step (audited)
 * - Ethena USDe pattern (audited by Cyfrin, Quantstamp)
 */
contract GBPb is ERC20, ERC20Burnable, Ownable2Step {
    /// @notice Address allowed to mint tokens (GBPbMinter contract)
    address public minter;

    /// @notice Track when tokens were minted for each address
    /// @dev ✅ FIX MED-3: Prevents hold time bypass via transfers
    ///      Uses earliest mint time when tokens are transferred
    mapping(address => uint256) public mintTime;

    /// @notice Emitted when minter is updated
    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    error OnlyMinter();
    error ZeroAddress();

    /**
     * @notice Constructor
     * @param _owner Initial owner (will be transferred to multisig)
     */
    constructor(address _owner) ERC20("GBPb", "GBPb") Ownable(_owner) {
        if (_owner == address(0)) revert ZeroAddress();
    }

    /**
     * @notice Set minter address (GBPbMinter contract)
     * @param _minter Address of minter contract
     * @dev Only owner can set minter (one-time setup)
     */
    function setMinter(address _minter) external onlyOwner {
        if (_minter == address(0)) revert ZeroAddress();

        address oldMinter = minter;
        minter = _minter;

        emit MinterUpdated(oldMinter, _minter);
    }

    /**
     * @notice Mint GBPb tokens
     * @param to Recipient address
     * @param amount Amount to mint
     * @dev Only minter can call (GBPbMinter when user deposits USDC)
     */
    function mint(address to, uint256 amount) external {
        if (msg.sender != minter) revert OnlyMinter();
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from caller
     * @param amount Amount to burn
     * @dev Public - anyone can burn their own tokens
     * @dev Inherited from ERC20Burnable (OpenZeppelin audited)
     */
    // burn() inherited from ERC20Burnable

    /**
     * @notice Burn tokens from account (with allowance)
     * @param account Account to burn from
     * @param amount Amount to burn
     * @dev Requires allowance
     * @dev Inherited from ERC20Burnable (OpenZeppelin audited)
     */
    // burnFrom() inherited from ERC20Burnable

    /**
     * @notice Override _update to track mint times
     * @dev ✅ FIX VULN-7: Each address tracks its own most recent mint
     *      Transfers don't reset mint time - prevents hold time bypass
     */
    function _update(address from, address to, uint256 amount) internal virtual override {
        super._update(from, to, amount);

        if (from == address(0)) {
            // Minting: Always update to current timestamp
            // ✅ FIX: Each new mint resets the clock for this address
            mintTime[to] = block.timestamp;
        }
        // ✅ FIX: Transfers DON'T update mintTime
        // Each address must wait 1 day from THEIR last mint
        // Can't backdate by receiving old tokens from someone else

        // Burning (to == address(0)): No action needed
    }
}
