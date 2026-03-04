# BattleGameLogic 测试用例

## 被测对象

- **合约**: GameLogic
- **函数**: `battle(uint256 enemySlot) external`
- **说明**: 与当前楼层指定槽位的敌人（Aoka）战斗；`enemySlot < floor.enemies.length`。结算后更新玩家/敌人血量；击败敌人时发放 ERC1155 奖励并计算经验（可能触发升级）。

## 前置与环境

- **setUp**: 部署 GameToken、GameAssets、GameV1BattleHarness 实现与 ERC1967Proxy，配置 `token.setProxy` / `assets.setProxy`，`gameLogic` 指向 proxy；固定 owner、user 地址。
- **Harness**: `GameV1BattleHarness` 暴露 `exposedSetPlayerHealth(address, uint16)`，用于将玩家血量设为指定值（如 1）以构造死亡场景。
- **楼层**: 默认 floor 0，敌人数量由种子决定（1～4 个），故 slot 0 一定存在；slot 取 `enemies.length` 或更大必越界。
- **随机性**: 测试用例通过 `vm.prevrandao(...)` 固定 `block.prevrandao`，保证战斗与掉落可复现。


## 测试用例列表

### 1. Happy path

| ID  | 函数名                               | 场景简述                 | 前置条件                      | 操作              | 预期结果 |
| --- | ---------------------------------- | -------------------- | ------------------------- | --------------- | ------ |
| H-1 | test_battle_playerWins_enemySlot0  | 打 slot 0 并获胜          | user 已 born，固定 prevrandao | battle(0)       | 不 revert，`floor.enemies[0].health == 0` |
| H-2 | test_battle_playerHealthAndEnemyUpdated | 战斗后玩家/敌人状态被更新         | user 已 born               | battle(0)       | 敌人被击败；玩家血量减少或经验增加（或两者兼有） |
| H-3 | test_battle_validSlotWithinEnemyCount | 打当前楼层最后一个有效槽位         | user 已 born               | battle(count-1) | 不 revert，该槽位敌人 `health == 0` |

### 2. 玩家被攻击扣血

| ID  | 函数名                                   | 场景简述           | 前置条件                       | 操作        | 预期结果 |
| --- | --------------------------------------- | ----------------- | ----------------------------- | ----------- | -------- |
| H-4 | test_battle_playerTakesDamage_whenEnemyHits | 敌人攻击时玩家扣血正常 | 推进到 BOSS 层 4，固定 prevrandao | battle(0)   | `player.health` 较战前减少 |

### 3. BOSS 层：数值与掉落

| ID  | 函数名                                | 场景简述               | 前置条件                     | 操作      | 预期结果 |
| --- | ------------------------------------ | --------------------- | ---------------------------- | --------- | -------- |
| H-5 | test_battle_bossFloor_dropsAndExperience | BOSS 击败后金币与经验正常 | 推进到 floor 4（BOSS 层）      | battle(0) | BOSS `health == 0`；金币余额增加；经验增加（奖励以 ERC1155 mint 发放） |

### 4. 玩家升级属性

| ID  | 函数名                                   | 场景简述             | 前置条件               | 操作                     | 预期结果 |
| --- | --------------------------------------- | ------------------- | ---------------------- | ------------------------ | -------- |
| H-6 | test_battle_playerLevelUp_attributesIncrement | 升级后属性增量符合公式 | born，清空 floor 0 获经验 | 清空当前层并在必要时下一层打一战 | `level==2`；`healthMax/attack/defense` 按 `Character.levelUpAttributesIncrement(1)` 增加；`experience` 为剩余经验 |

### 5. 玩家死亡：无奖励

| ID  | 函数名                                   | 场景简述                       | 前置条件                                      | 操作                       | 预期结果 |
| --- | --------------------------------------- | ----------------------------- | --------------------------------------------- | -------------------------- | -------- |
| H-7 | test_battle_playerDeath_noDropsNoCoinNoExp | 玩家死亡时无掉落、无金币、无经验 | 推进到 BOSS 层 4；harness 将 `health` 设为 1；固定 prevrandao | battle(0)（种子使 BOSS 先造成伤害） | `player.health==0`；coin/experience/level 均不变；不触发奖励 mint |

### 6. Reverts: access

| ID  | 函数名                             | 场景简述       | 预期 revert |
| --- | --------------------------------- | ------------- | ----------- |
| R-1 | test_battle_revertWhenNotRegistered | 未 born 即调用 | `PlayerNotFound(user)` |

### 7. Reverts: enemy slot

| ID  | 函数名                                        | 场景简述                   | 预期 revert |
| --- | -------------------------------------------- | -------------------------- | ----------- |
| R-2 | test_battle_revertWhenEnemyNotFound_slotOutOfRange | `slot == enemies.length`  | `EnemyNotFound(outOfRangeSlot)` |
| R-3 | test_battle_revertWhenEnemyNotFound_largeSlot      | slot 远大于有效范围（如 10） | `EnemyNotFound(10)` |

## 辅助方法

| 方法 | 用途 |
| --- | --- |
| _clearCurrentFloorWithSeed(uint256 baseSeed) | 按槽位使用 `baseSeed+slotIndex` 作为 prevrandao 依次 `battle`，清空当前层所有敌人 |
| _advanceToFloor(uint8 targetIndex, uint256 seedBase) | 循环清空当前层并 `nextFloor`，直到到达目标楼层索引（如 4 为 BOSS 层） |
| harness.exposedSetPlayerHealth(addr, h) | 将指定玩家的血量设为 `h`（仅用于构造死亡等测试场景） |

---

