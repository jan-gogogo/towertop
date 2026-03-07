// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IGameAssets} from "./interfaces/IGameAssets.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/**
 * @title Game assets contract
 * @author Jan
 * @notice Exposes some internal operations of the ERC1155 standard multi-token, such as mint and burn, for the proxy contract to call
 */
contract GameAssets is ERC1155, IGameAssets {
    /// @notice primary proxy (e.g. GameV1's proxy) with mint/burn authority
    address public _permit;

    modifier onlyPermit() {
        _onlyPermit();
        _;
    }

    constructor(string memory uri) ERC1155(uri) {}

    /// @notice once set, it cannot be changed
    function setProxy(address proxyAddr) external {
        if (_permit != address(0)) revert ProxyAddressAlreadySet();
        _permit = proxyAddr;
    }

    function mint(address to, uint256 id, uint256 value, bytes memory data) external onlyPermit {
        super._mint(to, id, value, data);
    }

    function burn(address from, uint256 id, uint256 value) external onlyPermit {
        super._burn(from, id, value);
    }

    /// @notice batch mint assets
    function mintBatch(address to, uint256[] memory ids, uint256[] memory values, bytes memory data)
        external
        onlyPermit
    {
        super._mintBatch(to, ids, values, data);
    }

    /// @notice batch burn assets
    function burnBatch(address from, uint256[] memory ids, uint256[] memory values) external onlyPermit {
        super._burnBatch(from, ids, values);
    }

    function _onlyPermit() private view {
        if (msg.sender != _permit) revert Unauthorized();
    }
}
