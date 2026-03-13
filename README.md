## Aoka Tower GameFI

Aoka Tower is an Ethereum‑based tower‑climbing GameFI project.  
The player starts on floor 1 and climbs up to floor 100 by defeating monsters, challenging BOSSes, and acquiring or upgrading equipment.

**status:** In Development, deployed on Ronin Testnet(Saigon)

**GameProxy:** [0xea8cf0099674B6c8DF6EefB767b0cA3C0227BF81](https://saigon-explorer.roninchain.com/address/0xea8cf0099674B6c8DF6EefB767b0cA3C0227BF81)

**GameV1:** [0x0A92Fc7847FE4471cB4b388d55D7e2Cbe5c367b8](https://saigon-explorer.roninchain.com/address/0x0A92Fc7847FE4471cB4b388d55D7e2Cbe5c367b8)

**HeroProxy:** [0x0841105ecbcb7B58682AF70d3CDDCf87010ad423](https://saigon-explorer.roninchain.com/address/0x0841105ecbcb7B58682AF70d3CDDCf87010ad423)

**HeroV1:** [0x2219537CDcdc442603e2800E489263D5C73Dc6e5](https://saigon-explorer.roninchain.com/address/0x2219537CDcdc442603e2800E489263D5C73Dc6e5)

**InventoryProxy:** [0x4422Ef25B46d897722D588F64a0978922fb56235](https://saigon-explorer.roninchain.com/address/0x4422Ef25B46d897722D588F64a0978922fb56235)

**InventoryV1:** [0xB784Fc267c71D6b03199bc5F77136Be451c4Bd11](https://saigon-explorer.roninchain.com/address/0xB784Fc267c71D6b03199bc5F77136Be451c4Bd11)

**ERC20:** [0xE9c53Da34e0FE05817fc2506402b18c79B2a5250](https://saigon-explorer.roninchain.com/address/0xE9c53Da34e0FE05817fc2506402b18c79B2a5250)

**ERC1155:** [0x6d798A5D4B01a3bB4E73C07F62e2A041CdF5004F](https://saigon-explorer.roninchain.com/address/0x6d798A5D4B01a3bB4E73C07F62e2A041CdF5004F)

### Core Gameplay

- **Tower Progression**
  - 100 floors in total, player starts from floor 1.
  - Every 5th floor (5/10/15/…) is a BOSS floor; defeating the BOSS unlocks the next segment of floors.

- **Combat & Growth**
  - On normal floors, the player sees several options (monsters, shop, forge, etc.) and can enter **only one** per floor.
  - Defeating monsters and BOSSes grants experience, gold, and items; leveling up increases HP, attack, and defense.
  - Combat includes critical hits, block, stun, and elemental advantage; all numbers are aligned with on‑chain contracts.

- **Items & Equipment**
  - Items: books (grant experience), potions (restore HP), refresh stones, and more.
  - Equipment: swords (attack), shields (block/defense), and armors (defense), with level 1–25 and rarity C/B/A/S.
  - Materials (Wooden / Iron / Obsidian) interact with enemy elements (Fire / Earth / Electric) to provide damage bonuses when advantageous.

- **Economy**
  - Gold is the in‑game currency, used for shop purchases and forge upgrades/merges.
  - Spending can partially burn gold and partially feed a reward pool for leaderboards and future GameFI mechanics.
  - A Puppet periodically accumulates a small amount of gold for the player and decays if not claimed for a long time.

### Documentation

- **[Game design document 游戏设计文档](docs/GAME_DESIGN.md)** – Full game design (mechanics, formulas, economy, combat, floors, shop/forge). Includes technical notes on TransparentUpgradeableProxy, Game/Hero/Inventory split, and contract architecture.

---

## Contracts & Architecture
![Architecture](docs/img/architecture.png)

The game uses **three proxies** (Game, Hero, Inventory), each with logic/storage separation. Users interact only with the **Game proxy**; Hero and Inventory are callable only by the Game proxy (`setPermit`).

### Entry point (behind proxy)

| Contract   | Path              | Description |
|-----------|-------------------|-------------|
| **GameV1** | `src/GameV1.sol`  | Game logic implementation: inherits GameLogic, `initialize(heroLogic, inventoryLogic, gameToken, gameAssets)`. Deployed as implementation behind a TransparentUpgradeableProxy; proxy admin can upgrade via `upgradeToAndCall`. |

### Core contracts

| Contract       | Path                | Description |
|----------------|---------------------|-------------|
| **GameLogic**  | `src/GameLogic.sol` | Abstract: single entry for born, battle, nextFloor, buy, equip, deposit/withdraw, etc.; delegates to HeroLogic and InventoryLogic, and mints/burns token and assets. |
| **HeroLogic** / **HeroV1** | `src/HeroLogic.sol`, `src/HeroV1.sol` | Player state, floor state, equipped slots, combat. HeroV1 is the logic contract behind the Hero proxy; only the Game proxy may call it after `setPermit(gameProxy)`. |
| **InventoryLogic** / **InventoryV1** | `src/InventoryLogic.sol`, `src/InventoryV1.sol` | Bag, warehouse, equipment/items, shop and forge logic. InventoryV1 is behind the Inventory proxy; only the Game proxy may call it. |
| **TransparentUpgradeableProxy** | `src/TransparentUpgradeableProxy.sol` | ERC1967 transparent proxy used for Game, Hero, and Inventory. Admin calls `upgradeToAndCall` on the proxy to upgrade the implementation. |
| **GameAssets** | `src/GameAssets.sol`| ERC1155: equipment, items, gold. Only the Game proxy can mint/burn after `setProxy(gameProxy)`. |
| **GameToken**  | `src/GameToken.sol` | ERC20 “Aoka Tower Token” (ATT). Only the Game proxy can mint/burn after `setProxy(gameProxy)`. |

### Interfaces

| Interface     | Path                        | Description |
|---------------|-----------------------------|-------------|
| **IGameLogic**| `src/interfaces/IGameLogic.sol` | External game API (born, battle, nextFloor, buy, equip, deposit, etc.) and custom errors. |
| **IHeroLogic**| `src/interfaces/IHeroLogic.sol` | Hero module: getPlayer, getFloor, getEquippedIds, setPermit; used by Game and tests. |
| **IInventoryLogic**| `src/interfaces/IInventoryLogic.sol` | Inventory module: getBag, getWarehouse, getEquipment, setPermit; used by Game. |
| **IGameToken**| `src/interfaces/IGameToken.sol` | Token operations and permit; used by game for mint/burn. |
| **IGameAssets**| `src/interfaces/IGameAssets.sol`| Asset mint/burn; used by game. |

### Libraries

| Library        | Path                          | Description |
|----------------|-------------------------------|-------------|
| **Battle**    | `src/libraries/Battle.sol`    | Turn‑based combat, damage formula, reward generation. |
| **Character** | `src/libraries/Character.sol` | Player struct, level‑up and circle logic. |
| **Enemy**     | `src/libraries/Enemy.sol`     | Enemy (Aoka) struct and floor enemy generation. |
| **Property**  | `src/libraries/Property.sol`  | Equipment/item IDs, stats, merge/upgrade cost and probability. |
| **Environment**| `src/libraries/Environment.sol`| Floor, shop, forge, and floor‑option generation. |
| **Attribute** | `src/libraries/Attribute.sol` | Rarity enum and related types. |
| **FloorIndex**| `src/libraries/FloorIndex.sol` | Boss‑floor check (`isBossFloor`). |
| **Seed**      | `src/libraries/Seed.sol`      | Seed mixing for reproducible on‑chain randomness. |

### Randomness

| Contract | Path                | Description |
|----------|---------------------|-------------|
| **Oracle** | `src/random/Oracle.sol` | Wraps `Randao`; currently uses `block.prevrandao` for combat/shop/forge RNG. Can be swapped for an external oracle later. |

---

## Scripts

| Script | Description |
|--------|-------------|
| **DeployGame** | `script/DeployGame.s.sol` – Deploy GameToken, GameAssets, GameV1, HeroV1, InventoryV1 and their TransparentUpgradeableProxies; initialize and wire `setPermit` / `setProxy` so the game proxy is the single entry. |

---

## Tests

Tests use **RouterTestBase**, which deploys the full stack: Game, Hero, and Inventory proxies plus GameToken and GameAssets. All under `test/`:

| Test file | Coverage |
|-----------|----------|
| `Born.t.sol` | Player creation (born), initial state, floor 0. |
| `Battle.t.sol` | Combat, damage, level‑up, BOSS, death, not‑registered reverts. |
| `Buy.t.sol` | Shop purchase (items, equipment), reverts. |
| `DepositWithdraw.t.sol` | Deposit, withdraw, 5% burn, depositWithPermit. |
| `EquipUnequip.t.sol` | Equip / unequip equipment and puppet. |
| `FullHeal.t.sol` | Full‑heal cost and reverts. |
| `UseItems.t.sol` | Use items (potions, books), slot rules. |
| `Circle.t.sol` | Circle (rebirth at floor 100), reverts. |
| `TowerTopSimulation.t.sol` | End‑to‑end simulation: one player climbs and fights until cap or level 100. |
| `GameInvariant.t.sol` | Invariant: player level and floor index bounded. |

Run: `forge test`

---

## Local Development (Foundry)

This project uses [Foundry](https://book.getfoundry.sh/) (`forge`, `cast`, `anvil`, etc.) as the main development and testing toolkit.

### Prerequisites

Install Foundry by following the official guide:

- https://book.getfoundry.sh/

### Common Commands

- **Build**

  ```shell
  forge build
  ```

- **Run Tests**

  ```shell
  forge test
  ```

- **Run battle simulation** (TowerTopSimulation: one player climbs and fights until top or stuck; uses books, potions, fullHeal, buy/upgrade when possible; prints final state)

  ```shell
  forge test --match-path test/TowerTopSimulation.t.sol -vv
  ```

- **Format Solidity**

  ```shell
  forge fmt
  ```

- **Gas Snapshots**

  ```shell
  forge snapshot --match-test "test_.*_for_snapshot"   
  ```

- **Local Node (Anvil)**

  ```shell
  anvil
  ```

- **Scripts / Deployment**

  Deploy script: `script/DeployGame.s.sol` deploys GameToken, GameAssets, GameV1, HeroV1, InventoryV1 and their TransparentUpgradeableProxies, wires `setPermit` and `setProxy`, then the game proxy is the single entry for users. Set env vars (e.g. `OWNER_ADDRESS`, deployer keys) or use `--private-key` as needed:

  ```shell
  forge script script/DeployGame.s.sol --rpc-url <your_rpc_url> --broadcast
  ```

- **Cast Utility**

  ```shell
  cast <subcommand>
  ```

For more details about Foundry itself, please refer to the official documentation:  
https://book.getfoundry.sh/
