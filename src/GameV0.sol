// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GameLogic} from "./GameLogic.sol";
import {IGameToken} from "./interfaces/IGameToken.sol";
import {IGameAssets} from "./interfaces/IGameAssets.sol";

/**
 * @title  GameV0 contract
 * @author Jan
 * @notice Non-upgradeable game entrypoint: deploys directly and wires
 *         token + assets in constructor. Token and assets should set
 *         their proxy to this contract's address after deployment.
 */
contract GameV0 is GameLogic {
    constructor(address _gameToken_, address _gameAssets_) {
        _gameToken = IGameToken(_gameToken_);
        _gameAssets = IGameAssets(_gameAssets_);

        // Initialize storage next-IDs for equipment and items.
        _initNextIds();
    }
}
