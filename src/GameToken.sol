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
    /// @notice only the proxy contract has the authority to operate
    address public _proxy;
    /// @notice only the specified address has the authority to execute the `setProxy` function
    address public immutable DEPLOYER;

    modifier onlyProxy() {
        _onlyProxy();
        _;
    }

    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {
        DEPLOYER = msg.sender;
    }

    function nonces(address owner) public view override(ERC20Permit, IERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }

    /// @notice once the proxy contract address is set, it cannot be changed
    function setProxy(address proxyAddr) external {
        if (msg.sender != DEPLOYER) {
            revert IGameToken.Unauthorized();
        }
        if (_proxy != address(0)) {
            revert IGameToken.ProxyAddressAlreadySet();
        }
        _proxy = proxyAddr;
    }

    function mint(address account, uint256 value) external onlyProxy {
        super._mint(account, value);
    }

    function burn(address account, uint256 value) external onlyProxy {
        super._burn(account, value);
    }

    function _onlyProxy() private view {
        if (msg.sender != _proxy) {
            revert IGameToken.Unauthorized();
        }
    }
}
