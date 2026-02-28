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

---

## Contracts & Architecture

### Core Contracts

- `GameV1`  
  UUPS‑upgradeable logic contract responsible for initialization, upgrades, and access control.

- `GameLogic`  
  Main game logic (combat, rewards, floor progression, etc.). It is not deployed directly, but used behind a proxy.

- `GameStorage`  
  Storage layout for players, floors, equipment, and related game state.

- `GameAssets`  
  ERC1155 assets contract managing equipment, items, and gold as multi‑token IDs.

- `GameToken`  
  ERC20 token used for depositing value into the game and other token‑level logic.

### Libraries

- `libraries/Battle.sol` – Turn‑based combat, damage calculation, and enemy RNG.
- `libraries/Character.sol` / `libraries/Enemy.sol` – Player and enemy data structures.
- `libraries/Property.sol` – Equipment and item IDs, plus stat calculation helpers.
- `libraries/Environment.sol` / `libraries/FloorIndex.sol` – Floor options and floor index utilities.
- `libraries/Seed.sol` – Shared seed‑mixing and hashing utilities to keep on‑chain randomness reproducible.

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

  Example: deploy the game proxy (adjust script parameters as needed):

  ```shell
  forge script script/DeployProxyGame.s.sol:DeployProxyGame \
    --rpc-url <your_rpc_url> \
    --private-key <your_private_key> \
    --broadcast
  ```

- **Cast Utility**

  ```shell
  cast <subcommand>
  ```

For more details about Foundry itself, please refer to the official documentation:  
https://book.getfoundry.sh/
