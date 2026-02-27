// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface IGameToken is IERC20, IERC20Permit {
    error Unauthorized();
    error ProxyAddressAlreadySet();

    function setProxy(address proxyAddr) external;

    function mint(address account, uint256 value) external;
    function burn(address account, uint256 value) external;
}
