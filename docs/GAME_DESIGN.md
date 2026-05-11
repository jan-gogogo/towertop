# GameFI - Aoka Tower 设计文档

---

## 一、游戏概述

奥卡塔是一款爬塔游戏：共 100 层，玩家从第 1 层开始，通过击败小怪获取经验并升级，击败楼层所有小怪进入下一层。 每 5 层会有一名 BOSS，战胜 BOSS 后才能进入下一段楼层。

### 技术架构（合约层）：

- **代理模式**：游戏入口及英雄/背包模块均使用 **TransparentUpgradeableProxy（ERC1967）**，逻辑与存储分离。用户只与**游戏代理**地址交互；Hero、Inventory 仅允许游戏代理调用（`setPermit(gameProxy)`），玩家状态与资产不受影响。
- **升级能力**：游戏代理由 **proxy admin** 管理，admin 调用代理上的 `upgradeToAndCall(newImplementation, data)` 即可更换 Game 逻辑（GameV1 → GameV2 等）；Hero/Inventory 代理同样可由各自 admin 升级其逻辑合约（HeroV1、InventoryV1）。
- **权限与安全**：游戏逻辑合约（GameV1）仅负责 `initialize(heroLogic, inventoryLogic, gameToken, gameAssets)`，无自有存储；HeroV1/InventoryV1 通过 `setPermit` 将唯一调用方设为游戏代理，避免被任意地址直接调用。
- **资产与代币**：ERC20 游戏代币与 ERC1155 资产合约采用「仅游戏代理可操作」设计（`authorize(gameProxy)` 一次性绑定），由游戏合约统一 mint/burn，保证经济与掉落逻辑仅在受控入口执行。
- **随机数**：战斗、楼层生成、商店、锻造等核心随机逻辑使用 `block.prevrandao` 混合种子（`Randao.getSeed()`）；战斗奖励掉落使用Oracle **Chainlink VRF V2 Plus** 提供密码学安全的可验证随机数，详细说明见 **3.1 Chainlink VRF 随机数系统**。

------
**楼层与玩法**

- 第 5、10、15… 层为 BOSS 层，该层只有一个 BOSS 选项。
- 其余为普通层，会出现 3–4 个选项（如商店、锻造房、若干小怪），玩家每层每次只能选其中一项进入。
- 在前期，商店和锻造房出现得晚一些；随着楼层提高，商店里能买到的装备等级、锻造房能升级/合成的上限也会提高；在 BOSS 前一层的楼层可以适当提高商店/锻造房的出现权重。具体随机规则见后文 **6.1 楼层选项随机算法**。

**游戏性**

- 商店购买、锻造房升级与合成等操作都会消耗金币。
- 当前版本每层不做二维地图移动，而是用选项代替：例如某一层出现「血瓶 / 经验书 / BOSS」等，玩家从中选一项进入。
- **转生**：到达第 100 层后可转生；转生后回到 1 级、装备/物品/金币保留、courage+1，并从第 1 层重新开始（详见 **2.8 转生（Circle）**）。

**代码与结构索引**

| 内容         | 文件路径                              | 主要结构 / 职责                            |
|--------------|---------------------------------------|-------------------------------------------|
| 入口合约     | src/GameV1.sol                        | `contract GameV1`：游戏逻辑实现，继承 GameLogic，仅负责 `initialize(heroLogic, inventoryLogic, gameToken, gameAssets)`，无存储 |
| 游戏逻辑     | src/GameLogic.sol                     | `abstract contract GameLogic`：单一入口，将战斗/楼层/商店/锻造等委托给 HeroLogic、InventoryLogic，并管理代币与资产的 mint/burn |
| 英雄逻辑     | src/HeroLogic.sol, src/HeroV1.sol     | 玩家、楼层、装备槽、战斗调用；HeroV1 为代理背后的逻辑合约，仅允许 `setPermit` 后的游戏代理调用 |
| 背包逻辑     | src/InventoryLogic.sol, src/InventoryV1.sol | 背包、仓库、装备/物品、商店与锻造；InventoryV1 为代理背后逻辑，仅允许游戏代理调用 |
| 代理         | src/TransparentUpgradeableProxy.sol   | ERC1967 透明代理，用于 Game / Hero / Inventory，admin 可 `upgradeToAndCall` 更换实现 |
| 接口定义     | src/interfaces/IGameLogic.sol         | `interface IGameLogic`：对外游戏 API 与错误类型 |
| 英雄/背包接口 | src/interfaces/IHeroLogic.sol, IInventoryLogic.sol | 玩家与背包模块的只读与受控调用接口 |
| 玩家         | src/libraries/Character.sol           | `struct Player` 及升级/轮回等辅助函数       |
| 敌人         | src/libraries/Enemy.sol               | `struct Aoka` 敌人定义与生成逻辑           |
| 装备与物品   | src/libraries/Property.sol            | 装备/物品结构体、数值公式、价格/掉落相关工具函数 |
| 楼层与环境   | src/libraries/Environment.sol         | `struct Floor`、`Shop` 等楼层/环境生成逻辑  |
| 战斗计算     | src/libraries/Battle.sol              | 战斗回合流程、伤害计算、奖励生成等         |
| 属性枚举     | src/libraries/Attribute.sol           | 稀有度 `enum Rarity` 等基础枚举           |
| 随机数封装   | src/random/Oracle.sol, src/libraries/Seed.sol | 目前暂时基于 `block.prevrandao` 的随机种子与派生工具，后续可能接入Oracle（如Chainlink或Pyth） |
| 资产合约     | src/GameAssets.sol                    | ERC1155 资产合约（物品/装备/金币）         |
| 代币合约     | src/GameToken.sol                     | ERC20 游戏代币（用于兑换游戏内 Coin）      |

**文档结构索引（章节编号，便于交叉引用）**

| 章节 | 内容 |
|------|------|
| 一 | 游戏概述 |
| 二 | 游戏元素（2.1 持有物品～2.7 Puppet） |
| 三 | 战斗系统（3.1 战斗流程、3.2 伤害公式） |
| 四 | 数值设计（4.1 玩家升级～4.6 锻造房） |
| 五 | 经济与奖励（5.1 经济模型～5.3 打怪奖励） |
| 六 | 商店与锻造房（6.1 楼层选项随机～6.4 锻造房） |


---
>>>>>>> Stashed changes

## 二、游戏元素（物品、装备、玩家、敌人、建筑）

### 2.1 持有物品

- **书**：使用后增加经验，稀有度 C → S，难度由低到高。
- **血瓶**：使用后恢复血量，按稀有度有不同数值（见 **4.3 物品数值**）。
- **刷新石**：特殊消耗品，只能通过击败特殊敌人 Tin 获得；使用后玩家回到**当前十层段的起始层**（例如第 23 层回到第 21 层，第 15 层回到第 11 层），从而在本段内多打几层小怪、多拿经验。获取与使用细节见 **4.4.2 Tin 与刷新石**、**5.3.1 刷新石**。
- **金币（Gold）**：游戏内货币，与装备、物品共用同一套 ERC1155 合约，用专用 tokenId(301) 表示。用来在商店买东西、在锻造房升级/合成。获得途径见 **5.3 打怪奖励**、**5.2 Puppet**；经济模型与金币池见 **5.1 经济模型**。

### 2.2 装备（武器与防具）

- **剑**：主属性为攻击力。
- **盾**：主属性为格挡相关（格挡率等）。
- **盔甲**：主属性为防御力。

装备共通规则：

- 等级：1–25 级。
- 稀有度：C、B、A、S。
- 材料（类别）：木(Wooden)、铁(Iron)、黑曜石(Obsidian)，与 **2.6 属性相克** 对应。

具体数值与成长见 **4.2 装备数值**。

### 2.3 玩家属性

| 字段 | 含义 | 范围/说明 |
|------|------|------------|
| floor | 当前所在楼层 | — |
| level | 等级 | 1–100 |
| experience | 经验值 | — |
| healthMax | 最大血量 | — |
| health | 当前血量 | 归 0 即阵亡，阵亡会扣减部分经验作为惩罚 |
| attack | 攻击力 | 影响对敌人造成的伤害 |
| defense | 防御力 | 影响受到敌人伤害时的减免 |
| crit | 暴击倍数 | 0–5 倍 |
| critChance | 暴击率 | 0–100 |
| blockChance | 格挡率 | 0–100，一定机率减免部分伤害 |
| stunChance | 眩晕率 | 0–100，一定机率使对方本回合无法行动 |
| courage | 勇气值 | 0–100，保留字段供后续扩展 |
| createAt | 创建时间 | — |

暴击、格挡、眩晕在基础数值上主要由装备提供（见 **4.2**）。

### 2.4 敌人类型

- **小怪**：出现在普通层，战胜后获得经验、物品和少量金币；种类与属性见 **4.4.1**。
- **Tin（特殊敌人）**：在有小怪槽位的普通层，每个槽位有一定概率刷出 Tin 而不是普通小怪；Tin 比当层小怪更强，击败后**必定掉落 1 枚刷新石**。详见 **4.4.2**。
- **BOSS**：每 5 层一只（5、10、15… 层），为该段守护者；类型与数值见 **4.4 敌人数值**、**4.4.1**。

### 2.5 建筑

- **商店**：用金币购买装备与消耗品。低层只卖低级货，中高层逐渐开放更好装备，但无法在商店买到最高等级装备，楼层与商品对应关系见 **6.1**、**6.2**。
- **锻造房**：对装备进行升级、合成，消耗金币，有失败概率，失败时可能损失材料。概率与金币消耗见 **4.6**、**6.4**。

### 2.6 属性相克（材料与元素）

- 木(Wooden) → 克 雷(Electric)   
- 铁(Iron) → 克 土(Earth)   
- 黑曜石(Obsidian) → 克 火(Fire)   

以及：

- 雷(Electric) → 克铁(Iron)  
- 土(Earth) → 克黑曜石(Obsidian)  
- 火(Fire) → 克木(Wooden)  

战斗中若存在相克关系，伤害会按 **3.2 伤害公式** 中规则加成。

### 2.7 Puppet（木偶）

玩家可拥有木偶，定期积累少量金币；若长时间不执行「领取」操作，已积累的金币会随时间衰减。木偶稀有度分 C/B/A/S 四档，初始为 C 级。具体公式见 **5.2 Puppet**。

### 2.8 转生（Circle）

玩家到达**第 100 层**（floor index = 99）后可调用 `circle()` 进行转生。

**转生效果（与合约 `Character.circle`、`GameLogic._circle` 一致）**：

- **等级与基础属性重置**：level、experience、healthMax、health、attack、defense 重置为 1 级初始值（level=1, experience=0, healthMax=100, health=100, attack=10, defense=5）。
- **保留内容**：装备（已装备与仓库）、背包物品、金币（ERC1155 Coin）均**不销毁**，转生后继续保留。
- **勇气值**：courage 在转生时 **+1**（可多次转生累计）。
- **创建时间**：createAt 不变。
- **楼层**：当前楼层数据被清空并**按第 1 层（floor index 0）**重新生成（商店/锻造房/小怪等），玩家从第 1 层继续游戏。

**限制**：仅当玩家当前所在楼层为第 100 层（floor.index == 99）时可调用，否则 revert `NotAt100Floor`。

---

## 三、战斗系统

### 3.1 Chainlink VRF 随机数系统

**背景**：游戏中的战斗结果由链上 `block.prevrandao` 决定（可验证公平）；但战斗奖励（物品掉落、装备掉落）的随机性需要更强的保证，以防止验证者/节点预知结果。因此奖励掉落使用 **Chainlink VRF V2 Plus** 提供可验证的随机数。

**VRF 调用流程**：

1. **请求阶段**：`battle()` 中玩家获胜后，调用 `_requestRandomWordsForReward(addr, floorIndex)` 向 VRF Coordinator 发起请求。
2. **请求参数**：
   - `keyHash`：VRF 订阅对应的 key hash
   - `subId`：VRF 订阅 ID（由订阅管理员资助）
   - `requestConfirmations`：5（等待 5 个区块确认）
   - `callbackGasLimit`：250,000
   - `numWords`：1（每次请求 1 个随机数）
   - `extraArgs`：使用 `ExtraArgsV1({nativePayment: false})`（使用 LINK 而非原生代币支付）
3. **状态存储**：请求 ID 与 `RewardWinner({player, floorIndex})` 存入 `mapping(uint256 requestId => RewardWinner) private _rewards`。
4. **回调阶段**：VRF Coordinator 在约 2–3 个区块后回调 `fulfillRandomWords(requestId, randomWords)`。
5. **奖励发放**：`randomWords[0]` 作为种子传给 `InventoryLogic.rewardWinner(player, bytes32(random), floorIndex)`，计算掉落并通过 `_gameAssets.mintBatch()` 发放。
6. **防重入**：回调后删除 `_rewards[requestId]`，并将 `floorIndex` 设为 `type(uint256).max` 标记已处理。

**合约继承关系**：
- `GameLogic` 继承 `VRFConsumerBaseV2Upgradeable` 并实现 `fulfillRandomWords`。
- `GameV1.initialize()` 接收 `_vrfCoordinator_`、`_keyHash_`、`_subscription_` 三个参数并初始化 VRF consumer。

**安全性**：
- VRF 提供密码学安全的随机数，无法被区块生产者预测或操纵。
- 回调仅发行资产，不修改玩家核心状态（楼层、血量、经验），因此即使 VRF 回调延迟也不影响游戏进程。

**部署配置**（`.env`）：
```
VRF_COORDINATOR=<VRF Coordinator V2 Plus 地址>
VRF_KEY_HASH=<Key Hash>
VRF_SUBSCRIPTION=<订阅 ID>
```
测试环境使用 `VRFCoordinatorV2_5Mock`（`@chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol`），可 `fulfillRandomWordsWithOverride` 立即返回随机数。

**gas 成本**：VRF 回调约消耗 250,000 gas（含 `mintBatch` 写操作），由 VRF 订阅池支付；游戏中不向玩家额外收取 VRF 费用。

### 3.2 战斗流程（与 2.3 玩家属性、2.6 属性相克 对应）

战斗过程中所有随机数均使用链上 `block.prevrandao`（来自信标链的 RANDAO）混合种子生成。

1. 玩家先手。
2. 若本回合对方被眩晕，则对方跳过行动。
3. 计算本回合伤害（见下方伤害公式）。
4. 若存在属性相克（2.6），伤害 × 110 / 100。
5. 若暴击率 > 0：掷 0–100 随机数，若小于玩家 critChance，则伤害 = 伤害 + 伤害 × crit（crit 为暴击倍数 0–5）。
6. 若未暴击：再掷随机数，若小于玩家 stunChance，则下一回合对方停止行动。
7. 对方攻击时：掷随机数，若小于玩家 blockChance，则伤害减免为 `damage - (damage / 4 - rarity)`（rarity 0–3 对应 C–S），且保证 `damageTaken >= 0`（可用 `max(0, ...)`）。
8. 根据最终伤害扣减血量。

### 3.3 伤害公式（与 2.6 属性相克 一致）

**基础伤害（双方通用）**

- `rawDamage = attacker_attack - defender_defense`，**最终伤害** `damage = max(1, rawDamage)`。
- 即：攻击高于防御时按差值扣血；防御 ≥ 攻击时只扣 1 点（不做「按攻击力百分比」的最低伤，避免高防玩家被低级小怪打出大数字）。
- 攻击、防御取当前面板（玩家 = 基础 + 装备，敌人见 **4.4**）。
- 若有属性相克（2.6），则 `damage = damage * 110 / 100`。

**暴击**：若随机数 < critChance，则 `damage = damage + damage * crit`（crit 为倍数 0–5）。

**眩晕**：若未暴击且随机数 < stunChance，则下一回合对方行动跳过。

**格挡**：对方攻击时，若随机数 < blockChance，则  
`damageTaken = damage - (damage / 4 - rarity)`，rarity 0–3（C–S），且 `damageTaken >= 0`。

**最终扣血**：`health = health - damageTaken`（玩家与敌人各自用己方的格挡计算）。

---

## 四、数值设计（公式与约束）

**设计约束（与合约一致）**

- 玩家：experience / healthMax / health / attack / defense 为 uint16；level 1–100；courage 0–100。
- 敌人 Aoka：health / attack / defense 为 uint16；level 1–100；crit 0–5；critChance / blockChance / stunChance 0–100。
- 装备：level 1–25；Rarity C/B/A/S；材料 Wooden / Iron / Obsidian。
- 目标：1–20 层偏易，玩家只要击杀约一半以上的小怪即可升级，并较轻松打赢前 4 个 BOSS。

---

### 4.1 玩家升级与属性成长

**升级所需经验**

- `expToNextLevel = 5 * (current_level + 1)`  
- 1→2 需 10，2→3 需 15，…，99→100 需 500。  
- 从 1 级到 100 级总经验约 25750，在 uint16 范围内。

**升级后属性变更（基础值，不含装备）**

- 初始（1 级）基础属性（来自合约 `initPlayer`）：  
  - `healthMax = 100`，`health = 100`，`attack = 10`，`defense = 5`。
- 每次从 level = L 升到 L+1 时，基础属性增量为：  
  - `healthMax += 20`  
  - `attack += 3`  
  - `defense += 2`  
  （即等级越高，每次升级增加的数值越大；实际总值为在上述初始值基础上累加。）

暴击/格挡/眩晕由装备提供，见 4.2。

---

### 4.2 装备数值

装备 level 1–25，Rarity C/B/A/S，材料 Wooden / Iron / Obsidian（与 2.6 属性相克对应）。

**4.2.1 基础主属性（未升级、未合成前）**

- **剑（Sword，主属性 attack）**  
  `attack_base = level + rarityBonus`  
  - rarityBonus：C=0，B=2，A=4，S=6。  
  - 例：1 级 C 剑=1，25 级 S 剑=31。

- **盔甲（Armor，主属性 defense）**  
  `defense_base = level + rarityBonus`（同上）。

- **盾（Shield，主属性 defense）**  
  `defense_base = (level + 1) / 2 + rarityBonus`（数值略低于盔甲）。

**4.2.2 副属性与上限**

- 全局上限：crit 0–3；critChance 0–20；blockChance 0–20；stunChance 0–16。
- 初始副属性由稀有度与材料决定，且不超过上述上限；合成时只在上限内小幅提升（见 4.6）。

**4.2.3 升级与合成对属性的影响（与 4.6 配合）**

- **升级（只升 level）**：单件从 level L 升到 L+1，Rarity 不变；**只重算主属性**（剑的 attack，盔甲和盾的 defense），按 4.2.1 公式；副属性不变。
- **合成（升 Rarity）**：两件同类型、同材料、同 Rarity 合成为一件 Rarity+1（见 4.6）。  
  - 主属性：`main_new = main_base(level_new, rarity_new) + mainBonus`，`mainBonus = 1 + rarity_newIndex`（C/B/A/S → 0/1/2/3）。  
  - 副属性增量（每次合成成功需 clamp 到 4.2.2 上限）：  
    - 剑：`crit += 1`，`critChance += 2`，`stunChance += 1`；  
    - 盾：`blockChance += 2`，`stunChance += 1`；  
    - 盔甲：可仅 `stunChance += 1` 或不加，由实现定。

---

### 4.3 物品数值（书、血瓶）

- **书（Book）**：使用后增加经验。根据当前合约实现：C=10，B=20，A=40，S=80（固定值）。
- **血瓶（Potion）**：按稀有度恢复固定血量。根据当前合约实现：C=50，B=100，A=200，S=1000。使用后：`health = min(healthMax, health + value)`。

---

### 4.4 敌人数值（小怪与 BOSS）

以下为随机化前的**基础公式**（随机波动见 4.4.1）。与合约 `Enemy.sol` 一致；Aoka 的 health/attack/defense 为 uint16。

**小怪（非 BOSS）**

- level：`level = min(100, floorIndex + 1)`。
- health：`health = 12 + (floorIndex * 8)`（整数除）。
- attack：分段。  
  - `floorIndex < 20`（1–20 层）：`attack = 3 + floorIndex `。  
  - `floorIndex >= 20`（21 层起）：`attack = floorIndex * 2`。  
- defense：`defense = 2 + floorIndex / 3`。  
- 示例：1 层 atk=3；20 层 atk=13；30 层 atk=78；50 层 atk=98；100 层 atk=147。  
- **crit / critChance / blockChance / stunChance**（小怪，平衡：低层为 0，随楼层缓升）：  
  - **crit**（暴击倍数，0–5）：`crit = floorIndex < 30 ? 0 : (floorIndex < 60 ? 1 : 2)`。30 层前无暴击，30–59 层 1 倍，60 层起 2 倍。  
  - **critChance**（暴击率，0–100）：`critChance = min(15, floorIndex < 15 ? 0 : (floorIndex - 15) / 2)`。15 层前 0%，之后每约 2 层 +1%，上限 15%。  
  - **blockChance**（格挡率，0–100）：`blockChance = min(12, floorIndex < 20 ? 0 : (floorIndex - 20) / 3)`。20 层前 0%，之后每约 3 层 +1%，上限 12%。  
  - **stunChance**（眩晕率，0–100）：`stunChance = min(8, floorIndex < 40 ? 0 : (floorIndex - 40) / 5)`。40 层前 0%，之后每约 5 层 +1%，上限 8%。  
  - 实现时以上按 `floorIndex` 计算后 clamp 到对应上限。

**BOSS（每 5 层）**

- level：`level = min(100, (floorIndex + 1))`，与楼层一致。
- health：`health = 40 + floorIndex * 20`。
- attack：分段。  
  - `floorIndex < 20`（1–20 层）：`attack = 7 + floorIndex`。  
  - `floorIndex >= 20`（25 层起）：`attack = 30 + (floorIndex * 3)`（整数除）。  
- defense：`defense = 4 + floorIndex / 2`。  
- 示例：5 层（fi=4）atk=11；20 层（fi=19）atk=26；30 层（fi=29）atk=73；60 层（fi=59）atk=118；75 层（fi=74）atk=141。  
- **crit / critChance / blockChance / stunChance**（BOSS）：  
  - **crit**：`crit = floorIndex < 25 ? 1 : (floorIndex < 60 ? 2 : 3)`。  
  - **critChance**：`critChance = min(20, 5 + floorIndex / 5)`。  
  - **blockChance**：`blockChance = min(15, 5 + floorIndex / 6)`。  
  - **stunChance**：`stunChance = min(10, floorIndex < 20 ? 0 : (floorIndex - 20) / 5)`。  
  - 所有值实现时 clamp 到对应类型与上限。

**4.4.1 小怪 / BOSS 随机（种类、属性、数值波动）**

- **种类（AokaType）**  
  - 小怪：按 `floorIndex` 映射到该层允许的类型池（如 1–10 层只有 Slime/Goblin/Bat，随楼层解锁更多），用 `seed = keccak256(floorIndex, slot_index, block_or_timestamp)` 取模从池中随机选一个。  
  - BOSS：每 5 层可固定一个类型，或从该层 BOSS 池中按 seed 选一个。

- **属性（AokaTrait）**  
  - `trait = seed % 3` → Fire(0)、Earth(1)、Electric(2)，与玩家装备材料相克时约 1/3 有利、1/3 不利、1/3 无克。

- **数值波动**（仅小怪，BOSS 无波动；与 `Enemy._floatedHealth / _floatedAttack / _floatedDefense` 一致）  
  - 在基础 health/attack/defense 上加减随机偏移：`value_final = value_base + (random % (2*range+1)) - range`，再保证非负。  
  - **attack**：`range = floorIndex / 4`。  
  - **defense**：`range = floorIndex / 5`。  
  - **health**：`range = floorIndex / 5`，若为 0 则取 1。  
  - 同一敌人的 random 只生成一次，用于 type、trait 及三项波动，保证可复现。

**4.4.2 Tin（特殊敌人）与刷新石**

- **出现条件**  
  - 仅在**有小怪槽位的普通层**（非 BOSS 层）生效；每层在生成小怪前先做一次 Tin 判定（约 5%）。  
  - 合约实现：`uint8(random[0]) < 13` 即约 5.08%；若命中则**第一个小怪槽位**为 Tin，否则按 4.4.1 生成普通小怪。

- **Tin 数值**（与合约一致）  
  - **level**：与当层小怪相同，`level = floorIndex + 1`（不单独提高等级）。  
  - **health/attack/defense**：基础公式同 4.4 小怪，在**数值波动**后的结果上再 **+25%**（即 `value += value / 4`），使 Tin 明显强于同层普通小怪。  
  - trait、crit/critChance/blockChance/stunChance 与当层小怪相同。

- **击败 Tin 的奖励**  
  - 固定掉落 1 枚**刷新石**（实现时需在物品表或 ItemType 中增加该类型）。  
  - 经验与金币按 **5.3** 中小怪公式，用 Tin 的 `level_Tin` 与当前 `floorIndex` 计算（可与同等级普通小怪一致或略高）。  
  - 不再额外 roll 5.3 的「打败敌人获得物品」表，刷新石即本次战斗的固定掉落。

---

### 4.6 锻造房：升级与合成

锻造房对装备进行**升级**（单件 level +1）与**合成**（两件同类型、同材料、同 Rarity 合成为 Rarity+1）。数值结果与 4.2.1–4.2.3 一致；本节给出输入/输出、金币消耗与成功概率。

**4.6.1 升级（单件 L → L+1）**

- **输入**：一件装备，level = L，Rarity 与材料任意。
- **结果**：若成功，level 变为 L+1；**主属性**按 4.2.1 用新 level 重算；**副属性不变**。失败只扣金币，装备不变。
- **金币消耗**（操作时扣除，失败也扣）：`cost_upgrade = 3 + 2 * L`。示例：L=1→5 金币，L=10→23，L=20→43。
- **成功概率**：`P_upgrade = max(40%, 95% - 2% * L)`。L 低时接近 100%，随 L 上升逐渐下降，最低不低于 40%。实现时随机数范围 [0, 256)：`success = random < (P_int * 256 / 100)`（P_int 为 0～100 的整数百分比）。

**4.6.2 合成（两件 → 一件 Rarity+1）**

- **输入**：两件**同类型**（均为剑/均为盾/均为盔甲）、**同材料**、**同 Rarity** 的装备，level 分别为 L1、L2。
- **结果**（成功时）：  
  - `rarity_new = min(S, rarity_old + 1)`；`level_new = min(L1, L2)`。  
  - **主属性**与**副属性**按 4.2.3 计算，并 clamp 到 4.2.2 上限。  
- **金币消耗**：`cost_merge = 10 + 3 * level_new + 5 * rarity_oldIndex`（rarity_oldIndex：C/B/A → 0/1/2；S 不再参与合成）。  
  - 简化形式（按稀有度）：C=50，B=100，A=150（S 不再合成）。
- **成功概率**：`P_merge = max(20%, 90% - 3% * level_new)`。低等级接近 90%，高等级逐渐下降，不低于 20%。  
- **失败时**：随机销毁两件中的一件（各 50%），另一件保留；金币照扣。

**4.6.3 锻造房限制**

- 该层锻造房**最大 Rarity** 由 6.1 楼层选项中的 `Foundry.rarity` 决定。  
- 仅当装备当前 Rarity ≤ `Foundry.rarity` 时，才可在该层进行升级或合成（例如该层锻造房只开放到 B，则不能对 A 装操作）。  
- 所有 cost 需在 uint32 范围内；概率实现建议用 0–100 的整数判定。

---

## 五、经济与奖励

### 5.1 经济模型：金币与金币池

**金币（Gold）**

- 游戏内唯一流通货币，与装备、物品共用同一套 ERC1155，用专用 tokenId 表示。
- **产出**：打小怪/BOSS 掉落（见 5.3）、Puppet 领取（见 5.2）。  
- **消耗**：商店购买（见 **6.3**）、锻造房升级/合成（见 **4.6**）。  
- 购买/锻造时，玩家金币被扣除后**销毁**（burn）；也可以选择把其中一部分转入**金币池**（见下）。

**金币池（暂未开放）**

- 用途：奖励**排行榜前列玩家**（如每周/每季爬塔层数 Top N），以及后续可能扩展的 **PvP 胜利者**等。
- 发放：由合约或治理在固定周期内，按排行榜/PvP 结果，将池中金币 mint 给对应玩家。

**池子金币从哪里来**

使用ERC20 Token充值挖矿。

**5.1.1 满血（消耗金币）**

玩家可支付一定**金币**将当前血量恢复至 `healthMax`（满血）。仅当 `health < healthMax` 时可调用；已满血时调用无效或 revert。

**消耗公式（单位：Coin，与 ERC1155 余额一致，1 单位 = 1e18）**

- `cost = HEAL_BASE + level × HEAL_PER_LEVEL`
- 推荐常数：`HEAL_BASE = 5`，`HEAL_PER_LEVEL = 2`
- 示例：1 级 7 Coin，20 级 45 Coin，50 级 105 Coin，100 级 205 Coin

**平衡性考虑**

- **不能比血瓶便宜太多**：满血是“一次到位”的便利，若价格低于同等级多瓶血瓶的等效治疗，则血瓶失去存在意义。当前血瓶 C/B/A/S 恢复 15/30/50/100，高等级玩家 healthMax 可达数百至数千，等效满血若用血瓶需多瓶；满血定价应略高于“用 2～3 瓶中等血瓶补满”的等效成本，使血瓶在单次小补时仍有优势。
- **不能太贵**：否则玩家不愿使用，功能形同虚设。随等级线性增长（HEAL_PER_LEVEL = 2）保证前期可负担、后期有压力但不至于离谱。
- **只烧 Coin**：与 **5.1 经济模型** 一致，游戏内消耗只扣 Coin 并 burn，不直接动 ERC20。


---

### 5.2 Puppet 获得金币（暂未开放）

Puppet 按稀有度 C/B/A/S 获得金币，公式如下。

- **基础累积速率（每秒）**  
  `rate = baseRate * (1 + rarityIndex)`  
  - C=0 → baseRate，B=1 → 2×baseRate，A=2 → 3×baseRate，S=3 → 4×baseRate。  
  - 建议 `baseRate`：每秒 1/3600 金币（即每小时 1 金币，按 C 级计）。

- **单次领取量**  
  `claimable = min(accumulated, cap)`  
  - `accumulated`：自上次 `lastClaimAt` 起按 `rate` 线性累积。  
  - `cap`：单次领取上限，建议按稀有度 C=10，B=25，A=50，S=100（金币数）。

- **衰减（长时间不领取）**  
  - 若距离 `lastClaimAt` 超过 `decayStartHours`（建议 24 小时），则累积速率按时间衰减。  
  - 每超过 24 小时，有效速率乘以 `decayFactor`（如 0.9），即  
    `effectiveRate = rate * (decayFactor ^ max(0, (now - lastClaimAt - decayStartHours) / 24h))`  
  - 领取时按当前 `effectiveRate` 与时间差算 `accumulated`，再套用 `cap`。

- **小结（便于实现）**  
  - C：1 金币/h，单次上限 10，24h 后开始衰减。  
  - B：2 金币/h，单次上限 25。  
  - A：3 金币/h，单次上限 50。  
  - S：4 金币/h，单次上限 100。

---

### 5.3 打怪奖励（经验、金币、掉落）

**打败小怪**

- 经验：`exp = enemy_level / 2 + floorIndex + 1`（floor_index 0–99）。  
  - 例：1 层小怪 level=1 → 2 exp；20 层小怪 level=20 → 40 exp。
- 金币：`gold = 1 + floorIndex / 5`（整除）。  
  - 1–4 层→1，5–9 层→2，…，95–99 层→19。

**打败 BOSS**

- 经验：`exp = 2 * boss_level + (floorIndex + 1)`。  
  - 例：5 层 BOSS level=5 → 30 exp；20 层 BOSS level=20 → 120 exp。
- 金币：`gold = 5 +  (floorIndex + 1)`。  
  - 例：5 层→17，20 层→47。

**刷新石（5.3.1）**

- **获取**：仅击败特殊敌人 **Tin** 后固定获得 1 枚（见 4.4.2）。  
- **使用效果**：玩家当前楼层变为「当前十层段的起始层」。  
  - 若楼层为 0-based（floor_index 0–99）：`target_floor_index = floorIndex - (floorIndex % 10)`  
  - 即：0–9 层→0，10–19 层→10，…，90–99 层→90；等价 1-based 显示为回到第 1、11、21、…、91 层。  
- 使用后消耗 1 枚刷新石；不改变玩家血量、经验、装备等其它状态。

**打败敌人获得物品规则**

- 打败 BOSS：可获得所有稀有度的物品；S 仅 BOSS 在 69 层以上时有约 5% 概率掉落；每次击败 BOSS 掉落 **0-2 件** 物品（种类独立 roll）。
- 打败小怪：掉落 **0-2 件**；**不能** 掉落 S 稀有度；稀有度按权重随机。
- 物品种类权重（从高到低）：potion = 80%，book = 20%。
- 小怪稀有度：C≈60%，B≈20%，A≈20%；小怪不掉 S。
- **装备掉落**：战斗胜利有较小几率额外获得 **1 件装备**（随机类型：剑/甲/盾）；见 5.3.2。

**5.3.2 装备掉落（战斗胜利小概率）**

- 战斗胜利后，在常规物品掉落之外，**有概率额外掉落 1 件装备**（类型随机：剑 / 盔甲 / 盾）。
 - **小怪**：
  - 掉落装备的**基础概率恒定 5%**，然后**每 10 层增加 1%**。实现上仍用 [0, 256) 随机数：  
    - 令 `segment = floorIndex / 10`（整数除，0–9）；  
    - 令 `P_int = min(14, 5 + segment)`（单位为百分比，0–10 层=5%，11–20 层=6%，…，91–100 层=14%）；  
    - 计算 `drop_threshold = (P_int * 256) / 100`（下取整），若 `random < drop_threshold` 则掉装备。  
  - 装备**等级**随楼层升高而升高，**最高等级 20**（与现有装备等级上限一致）。
  - **不能掉落 S 稀有度**，仅 C/B/A；稀有度权重建议与小怪物品一致或略偏 B/A。
- **BOSS**：
  - 掉落装备的**基础概率恒定 25%**，然后**每 10 层增加 2%**。实现上同样用 [0, 256) 随机数：  
    - 令 `segment = floorIndex / 10`（整数除，0–9）；  
    - 令 `P_int = 25 + 2 * segment`（单位为百分比，0–10 层=25%，11–20 层=27%，…，91–100 层=43%）；  
    - 计算 `drop_threshold = (P_int * 256) / 100`（下取整），若 `random < drop_threshold` 则掉装备。  
  - 装备**等级**随楼层升高，**最高等级 20**。
  - **不能掉落 S 稀有度**，仅 C/B/A。
- 装备类型（剑/甲/盾）由独立随机决定（ `random % 3` 或按权重分配）；材料（铁/木/黑曜石等）可按稀有度或再 roll 一次。

**5.3.3 掉落物计算公式**

约定：**所有随机数取值范围均为 [0, 256)**（即 0～255，共 256 个数），由 `uint256(keccak256(seed)) % 256` 得到；每件掉落独立用不同 `seed`。

**步骤一：物品种类（type）**（仅针对消耗品，装备见 5.3.2）

- 权重：potion = 80%，book = 20%。
- **公式**：`r = random`（random ∈ [0, 256)）；若 `r < 204` 则 **potion**，否则 **book**（204 = 256×80/100 下取整）。

**步骤二：稀有度（rarity）——区分 BOSS 与 小怪**

- **BOSS 掉落**（C/B/A/S，S 仅在 69 层以上有约 5% 概率）  
  - 权重建议：S≈5%，A≈10%，B≈20%，C≈60%。  
  - **公式**：`r = random`（random ∈ [0, 256)）  
    - `r < 13` → **S**（13 = 256×5/100 下取整）  
    - `r < 26` → **A**（26 = 13 + 256×5/100 下取整）  
    - `r < 78` → **B**（78 = 26 + 256×20/100 下取整）  
    - 否则 → **C**  
  - 即：`rarityIndex = 0(C)/1(B)/2(A)/3(S)` 可由分段判断或查表得到。

- **小怪掉落**（仅 C/B/A，不掉 S）  
  - 权重建议：C≈60%，B≈20%，A≈20%。  
  - **公式**：`r = random`（random ∈ [0, 256)）  
    - `r < 154` → **C**（154 = 256×60/100）  
    - `r < 205` → **B**（205 = 154 + 256×20/100 下取整）  
    - 否则 → **A**  
  - 小怪永不掉落 S，无需 roll S 区间。

**步骤三：单件掉落流程小结**

- **小怪**：掉落 0–2 件消耗品；另按 5.3.2 判定是否额外掉 1 件装备。  
  1. 用 `seed_item` 得到 `random ∈ [0, 256)`；  
  2. 数量：`count = random % 3`（0/1/2 件）；若 count=0 则不掉落；  
  3. 种类：`random < 204` → potion，否则 book；  
  4. 稀有度：再用一次随机按小怪权重得 C/B/A；  
  5. 生成对应 (type, rarity) 物品加入背包。  
  6. 装备掉落：用独立 seed 判定是否掉装备；若掉，再 roll 类型（剑/甲/盾）、稀有度 C/B/A、等级（≤ min(20, 与楼层相关)）。

- **BOSS**：掉落 0–2 件消耗品，**每件独立 roll**；另按 5.3.2 判定是否额外掉 1 件装备。  
  1. 第 1 件：`seed_1 = keccak256(battleSeed, 0)` → 数量 + 种类 + BOSS 稀有度（含 S）；  
  2. 第 2 件：`seed_2 = keccak256(battleSeed, 1)` → 数量 + 种类 + BOSS 稀有度（含 S）；  
  3. 两件种类、稀有度均独立，可同 potion、同 rarity。  
  4. 装备掉落：用独立 seed 判定是否掉装备；若掉，再 roll 类型、稀有度 C/B/A、等级（≤ 20）。

---

## 六、商店与锻造房

### 6.1 楼层选项随机算法

**适用楼层**：非 BOSS 层（即 `(floorIndex + 1) % 5 != 0`）；BOSS 层只生成 BOSS，不参与本随机。

**目标**：每层生成 3–4 个选项，且「小怪」至少 1 个；商店、锻造房按楼层解锁并控制出现率。

**步骤一：本层是否出现商店、锻造房**

- 商店：仅当 `floorIndex >= 3` 时可能出现。**整数公式**：`f = min(128, 51 + (floorIndex * 256) / 200)`（约 20%～50%）；判定：`random ∈ [0, 256)` 且 `random < f` 则本层出现商店。
- 锻造房：仅当 `floorIndex >= 5` 时可能出现。**整数公式**：`f = min(115, 38 + (floorIndex * 256) / 250)`（约 15%～45%）；判定：`random ∈ [0, 256)` 且 `random < f` 则本层出现锻造房。


**步骤二：小怪槽位数量**

- 本层选项总数 `N = 3` 或 `4`（随机数 [0, 256)：`random < 128` 则 N=3，否则 N=4）。
- 小怪槽位数 = `N - (是否有商店 ? 1 : 0) - (是否有锻造房 ? 1 : 0)`，至少为 1。
- 即：若同时有商店+锻造房则 2 个小怪位；若只有其一则 2–3 个小怪位；若都没有则 3–4 个小怪位。

**步骤三：商店 / 锻造房内容**

- 商店：由 `floorIndex` 决定可售稀有度、装备等级与商品列表，见 **6.2 商店内容公式**。
- 锻造房：该层允许的**最高锻造稀有度**（仅可锻造 ≤ 该稀有度的装备）：
  - **整数公式**：`rarityIndex = floorIndex >= 90 ? 3 : min(2, floorIndex / 25)`（90 层及以上才可锻造 S）。
  - **映射**：`rarityIndex` 0→C，1→B，2→A，3→S。
  - **按楼层**：0–24 层→C，25–49 层→B，50–89 层→A，90–99 层→S。高层可锻造更高稀有度。

**步骤四：小怪槽位内容**

- 对每个小怪槽位：  
  1. 先以 **1/20** 概率判定是否为 **Tin**（见 4.4.2）；若命中则生成 Tin，不再走步骤 2。  
  2. 若未命中 Tin，则按 4.4.1 生成一只普通小怪。  
- 同一层多个槽位用不同 `slot_index` 保证不同 seed，Tin 与普通小怪互斥。

**随机源与可复现**：链上可用 `keccak256(floorIndex, slot_index, block.chainid, block.number)` 或带玩家/世界 seed 的哈希；同一层同一槽位在相同输入下应生成相同选项。

---

### 6.2 商店内容公式（根据 floorIndex）

**可售稀有度上限**

- 商店**最高只售 A 级**（不售 S）；A 仅 80 层及以上解锁。
- 0-19 层恒定 C
- Rarity 索引：C=0，B=1，A=2。  
  `maxRarityIndex = floorIndex >= 80 ? 2 : 1`（整数）。  
  - 20–79 层 C/B，80 层及以上可 C/B/A。

**可售装备等级上限（剑/盔甲/盾）**

- 商店装备**最高 20 级**，且 20 级仅 80 层及以上解锁。  
  `maxEquipLevel = floorIndex >= 80 ? min(20, 5 + floorIndex / 4) : min(19, 5 + floorIndex / 4)`。  
  - 0–79 层最高 19 级，80 层及以上最高 20 级；示例：0 层→5，40 层→15，79 层→19，80 层及以上→20。

**商品槽位数量**  
`shopSlotCount = 2 + (floorIndex % 3)`，即每层商店 2–4 个槽位。

**每个槽位生成什么**

- 用 `slot_seed = keccak256(floorIndex, slot_index, world_seed)` 决定类型与属性。  

- **类型（剑 / 盾 / 甲 / 书 / 血瓶）**：按权重随机，高层提高装备总权重，装备内部剑/盾/甲均分。  
  - **权重公式（全整数）**  
    - 装备总权重：`equipTotal = 40 + floorIndex / 5`（随楼层增加）。  
    - 剑 / 盾 / 甲：`swordWeight = shieldWeight = equipTotal / 3`，`armorWeight = equipTotal - 2 * (equipTotal / 3)`（余数归甲）。  
    - 书 / 血瓶（固定）：`bookWeight = 30`，`potionWeight = 50`。  
  - **总权重**：`totalWeight = equipTotal + bookWeight + potionWeight = 120 + floorIndex / 5`。  
  - **判定**：用 `slot_seed` 得到 `r = uint256(keccak256(slot_seed)) % totalWeight`，然后按区间选类型：  
    - `r < swordWeight` → 剑  
    - `r < swordWeight + shieldWeight` → 盾  
    - `r < swordWeight + shieldWeight + armorWeight` → 甲  
    - `r < swordWeight + shieldWeight + armorWeight + bookWeight` → 书  
    - 否则 → 血瓶  

- **若为装备（剑/盾/甲）**：rarity 在 [C, maxRarity] 内随机；level = floorIndex / 5 +1；material 在 Wooden / Iron / Obsidian 中随机一种。  
- **若为书或血瓶**：rarity 在 [C, maxRarity] 内随机，数值按 **4.3**（书 C/B/A 对应 10/20/40 经验，血瓶 50/100/200 血量；商店无 S 故无 80/1000）。  


**小结表**

| floorIndex | maxRarityIndex | 可售稀有度 | level |
|-------------|----------------|------------|---------------|
| 0-19        | 1              | C          |floorIndex / 5 +1|
| 20–39       | 1              | C, B       |floorIndex / 5 +1|
| 40–79       | 1              | C, B       |floorIndex / 5 +1|
| 80+         | 2              | C, B, A    |floorIndex / 5 +1|

---

### 6.3 商店购买消耗金币

购买时扣除并销毁，可选部分进入金币池（见 5.1）。

- **装备（剑/盔甲/盾）**  
  `cost_equip = 2 + 3 * level + 8 * rarityIndex`  
  - rarityIndex：C=0，B=1，A=2。  
  - 示例：1 级 C=5，10 级 B=35，20 级 A=78。

- **书**  
  `cost_book = 30 + 50 * rarityIndex`（C=30，B=80，A=130）。

- **血瓶**  
  `cost_potion = 20 + 40 * rarityIndex`（C=20，B=60，A=100）。


---

### 6.4 锻造房：升级与合成（与 4.6 一致）

**前提**

- 升级（Enhance）：单件装备从 level L 升到 L+1，Rarity 不变。
- 合成（Merge）：两件同类型、同材料、同 Rarity 的装备合成一件 Rarity+1 的新装备，新装备 level 取两者中较小值。

**金币消耗（操作时扣除，失败也扣；可选部分进入金币池，见 5.1）**

| 操作 | 公式 | 说明 |
|------|------|------|
| **升级**（单件 L→L+1） | `cost_upgrade = 3 + 2 * L` | L=1→5，L=10→23，L=20→43。 |
| **合成**（两件合为 Rarity+1） | `cost_merge = 10 + 3 * main_level + 5 * rarity_oldIndex` | rarity_oldIndex：C/B/A → 0/1/2（S 不再合成）。简化：C=50，B=100，A=150。 |

**升级（4.6.1）**

- 输入：一件装备，level = L。  
- 结果：若成功，level 变为 L+1；主属性按 4.2.1 重算；副属性不变。  
- 消耗金币：`cost_upgrade = 3 + 2 * L`（示例：L=1→5 金币，L=10→23 金币，L=20→43 金币）。  
- 成功概率：`P_upgrade = max(40%, 95% - 2% * L)`；L 低时接近 100%，随 L 上升逐渐下降，最低不低于 40%。失败只扣金币，装备不变。

**合成（4.6.2）**

- 输入：两件同类型、同材料、同 Rarity 的装备，level 分别为 L1、L2。  
- 结果（成功时）：`rarity_new = min(S, rarity_old + 1)`，`level_new = min(L1, L2)`；主属性与副属性按 4.2.3 计算，并 clamp 到 4.2.2 上限。  
- 消耗金币：`cost_merge = 10 + 3 * main_level + 5 * rarity_oldIndex`（rarity_oldIndex：C/B/A → 0/1/2）。  
  - 简化形式（按稀有度）：C=50，B=100，A=150（S 不再合成）。  
- 成功概率：固定与稀有度挂钩，与等级无关：C=60%，B=30%，A=5%，S 不再参与合成。失败时**随机销毁两件中的一件**（各 50%），另一件保留。

**锻造房限制（4.6.3）**

- 该层锻造房最大 Rarity 由 6.1 中 `Foundry.rarity` 决定；仅当装备当前 Rarity ≤ `Foundry.rarity` 时，才可在该层进行升级/合成。  
- 实现时随机数统一为 [0, 256)，概率判定为 `success = random < (P_int * 256 / 100)`（P_int 为 0～100 的整数百分比）；所有 cost 需在 uint32 范围内。

---
