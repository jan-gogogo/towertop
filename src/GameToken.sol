// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IGameToken} from "./interfaces/IGameToken.sol";

/**
 * @title  Token contract
 * @author Jan
 * @notice ERC20Permit extends ERC20
 * @dev    We keep ERC20 in the list so constructor can call ERC20(name, symbol)
 */
contract GameToken is ERC20, ERC20Permit, IGameToken {
    /// @notice primary proxy (e.g. GameV1's proxy) with mint/burn authority
    address public _permit;

    address public _game;

    modifier onlyPermit() {
        _onlyPermit();
        _;
    }

    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {}

    function nonces(address owner) public view override(ERC20Permit, IERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }

    /// @notice once set, it cannot be changed
    function authorize(address _permit_, address _game_) external {
        if (_permit != address(0)) revert ProxyAddressAlreadySet();
        _permit = _permit_;
        _game = _game_;
    }

    function mint(address account, uint256 value) external onlyPermit {
        super._mint(account, value);
    }

    function burn(address account, uint256 value) external onlyPermit {
        super._burn(account, value);
    }

    function burnFromApprove(address account, uint256 value) external {
        if (msg.sender != _game) revert Unauthorized();
        super._spendAllowance(account, _msgSender(), value);
        super._burn(account, value);
    }

    function _onlyPermit() private view {
        if (msg.sender != _permit) revert Unauthorized();
    }
}
