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
    /// @notice only the proxy contract has the authority to operate
    address public _proxy;
    /// @notice only the specified address has the authority to execute the `setProxy` function
    address public immutable DEPLOYER;

    modifier onlyProxy() {
        _onlyProxy();
        _;
    }

    constructor(string memory uri) ERC1155(uri) {
        DEPLOYER = msg.sender;
    }

    /// @notice once the proxy contract address is set, it cannot be changed
    function setProxy(address proxyAddr) external {
        if (msg.sender != DEPLOYER) {
            revert IGameAssets.Unauthorized();
        }
        if (_proxy != address(0)) {
            revert IGameAssets.ProxyAddressAlreadySet();
        }
        _proxy = proxyAddr;
    }

    function mint(address to, uint256 id, uint256 value, bytes memory data) external onlyProxy {
        super._mint(to, id, value, data);
    }

    function burn(address from, uint256 id, uint256 value) external onlyProxy {
        super._burn(from, id, value);
    }

    /// @notice batch mint assets
    function mintBatch(address to, uint256[] memory ids, uint256[] memory values, bytes memory data)
        external
        onlyProxy
    {
        super._mintBatch(to, ids, values, data);
    }

    /// @notice batch burn assets
    function burnBatch(address from, uint256[] memory ids, uint256[] memory values) external onlyProxy {
        super._burnBatch(from, ids, values);
    }

    function _onlyProxy() private view {
        if (msg.sender != _proxy) {
            revert IGameAssets.Unauthorized();
        }
    }
}
