// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {GameLogic} from "./GameLogic.sol";
import {IHeroLogic} from "./interfaces/IHeroLogic.sol";
import {IInventoryLogic} from "./interfaces/IInventoryLogic.sol";
import {IGameToken} from "./interfaces/IGameToken.sol";
import {IGameAssets} from "./interfaces/IGameAssets.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract GameV1 is GameLogic, Initializable {
    /**
     * @notice constructor function
     *  @dev Disable initializers on the logic contract so initialize() never runs in its context.
     *       The code in initialize() below is what would go in a constructor—but a constructor
     *       would store _heroLogic, _inventoryLogic, _gameToken, _gameAssets in GameV1, not in the proxy.
     *       We need the logic contract to hold no storage, so we run the real setup in the proxy's context
     *       when it's deployed; then all that state lives in the proxy.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice initialization function (called during proxy deployment)
     *  @dev This function is disabled on the logic contract; the proxy runs it in its own context when deployed.
     *       Because it runs in the proxy's context, msg.sender is the deployer,
     *       not the proxy—so we pass _owner_ explicitly instead of relying on auth.
     */
    function initialize(address _heroLogic_, address _inventoryLogic_, address _gameToken_, address _gameAssets_)
        external
        initializer
    {
        _heroLogic = IHeroLogic(_heroLogic_);
        _inventoryLogic = IInventoryLogic(_inventoryLogic_);
        _gameToken = IGameToken(_gameToken_);
        _gameAssets = IGameAssets(_gameAssets_);
    }
}
