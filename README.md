## Tower Top GameFI

Tower Top is an Ethereum‑based tower‑climbing GameFI project.  
The player starts on floor 1 and climbs up to floor 100 by defeating monsters, challenging BOSSes, and acquiring or upgrading equipment.

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

- **[Game design document 游戏设计文档](docs/GAME_DESIGN.md)** – Full game design (mechanics, formulas, economy, combat, floors, shop/forge). Includes technical notes on ERC1967 proxy, UUPS upgrades, and contract architecture.

---

## Contracts & Architecture

### Entry points

| Contract   | Path              | Description |
|-----------|-------------------|-------------|
| **GameV0** | `src/GameV0.sol`  | Non‑upgradeable entry: deploy directly with `GameV0(token, assets)`. Use for testnets or when upgrades are not needed. |
| **GameV1** | `src/GameV1.sol`  | UUPS‑upgradeable logic: used as implementation behind an ERC1967 proxy. Handles initialization, upgrade authorization, and two‑step ownership. |

### Core contracts

| Contract       | Path                | Description |
|----------------|---------------------|-------------|
| **GameLogic**  | `src/GameLogic.sol` | Abstract contract: combat, rewards, floors, shop, forge, deposit/withdraw. Inherited by GameV0 / GameV1. |
| **GameStorage**| `src/GameStorage.sol`| Abstract contract: storage layout for players, floors, equipment, bags, warehouse. Inherited by GameLogic. |
| **GameAssets** | `src/GameAssets.sol`| ERC1155: equipment, items, and gold (multi‑token IDs). Only the game contract (proxy or GameV0) can mint/burn after `setProxy`. |
| **GameToken**  | `src/GameToken.sol` | ERC20 “Tower Top Token” (TOP): deposit into game, in‑game Coin mint. Only the game contract can mint/burn after `setProxy`. |
| **ERC1967Proxy** | `src/ERC1967Proxy.sol` | Minimal ERC1967 proxy used to point to GameV1 implementation. |

### Interfaces

| Interface     | Path                        | Description |
|---------------|-----------------------------|-------------|
| **IGameLogic**| `src/interfaces/IGameLogic.sol` | External game API (born, battle, nextFloor, buy, equip, deposit, etc.) and custom errors. |
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
| **DeployGameV0** | `script/DeployGameV0.s.sol` – Deploy GameToken, GameAssets, GameV0; then `setProxy` on token and assets to GameV0. Env: `TOKEN_PRIVATE_KEY`, `ASSET_PRIVATE_KEY`, `GAME_V0_PRIVATE_KEY`. |
| **DeployGameV1Proxy** | `script/DeployGameV1Proxy.s.sol` – Deploy GameToken, GameAssets, GameV1, ERC1967Proxy; initialize proxy with `GameV1.initialize(token, assets, owner)`; then `setProxy` to proxy address. Env: `OWNER_ADDRESS`, `TOKEN_PRIVATE_KEY`, `ASSET_PRIVATE_KEY`, `GAME_V1_PRIVATE_KEY`, `PROXY_PRIVATE_KEY`. |

---

## Tests

Tests use **GameV0** (no proxy). All under `test/`:

| Test file | Coverage |
|-----------|----------|
| `Born.t.sol` | Player creation (born), initial state, floor 0. |
| `BattleGameLogic.t.sol` | Combat, damage, level‑up, BOSS, death. |
| `Buy.t.sol` | Shop purchase (items, equipment), reverts. |
| `DepositWithdraw.t.sol` | Deposit, withdraw, 5% burn, depositWithPermit. |
| `EquipUnequip.t.sol` | Equip / unequip equipment and puppet. |
| `FullHeal.t.sol` | Full‑heal cost and reverts. |
| `UseItems.t.sol` | Use items (potions, books), slot rules. |
| `GameStorage.t.sol` | Storage helpers, bags, warehouse, capacity. |

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

  Example: deploy the game with UUPS proxy (set env vars `OWNER_ADDRESS`, `TOKEN_PRIVATE_KEY`, etc., or use `--private-key` for a single key):

  ```shell
  forge script script/DeployGameV1Proxy.s.sol:DeployGameV1Proxy \
    --rpc-url <your_rpc_url> \
    --broadcast
  ```

  For a direct deploy without proxy (GameV0):

  ```shell
  forge script script/DeployGameV0.s.sol:DeployGameV0 --rpc-url <your_rpc_url> --broadcast
  ```

- **Cast Utility**

  ```shell
  cast <subcommand>
  ```

For more details about Foundry itself, please refer to the official documentation:  
https://book.getfoundry.sh/
