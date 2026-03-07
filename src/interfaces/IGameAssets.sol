// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IGameAssets is IERC1155 {
    error Unauthorized();
    error ProxyAddressAlreadySet();

    function setProxy(address proxyAddr) external;
    function mint(address to, uint256 id, uint256 value, bytes memory data) external;
    function burn(address from, uint256 id, uint256 value) external;
    function mintBatch(address to, uint256[] memory ids, uint256[] memory values, bytes memory data) external;
    function burnBatch(address from, uint256[] memory ids, uint256[] memory values) external;
}
