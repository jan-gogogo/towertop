# Buy 测试用例

## 被测对象

- **合约**: GameLogic
- **函数**: `buy(uint256 typeIndex, uint256 index) external`
- **说明**: 在当层商店购买指定类型、指定槽位的商品。typeIndex：0=消耗品（书/血瓶），1=剑，2=盾，3=盔甲。index 为对应数组下标。购买时扣减并销毁 Coin，向玩家 mint 对应 asset。

## 前置与环境

- **setUp**: 部署 GameToken、GameAssets、GameV1 实现与 ERC1967Proxy，配置 token.setProxy / assets.setProxy，gameLogic / gameToken / gameAssets 指向对应地址；固定 owner、user 地址。
- **商店出现**: 通过 `_advanceToFloorWithShop()` 将 user 推进到带商店的楼层（floor index 3，seed 使 shopCountNextFloor 命中），并清空当层敌人以便 nextFloor。

## 测试用例列表

### 1. Happy path

| ID  | 函数名                   | 场景简述         | 前置条件                         | 操作              | 预期结果                                           |
| --- | ------------------------- | ---------------- | -------------------------------- | ----------------- | -------------------------------------------------- |
| H-1 | test_buy_item_success     | 购买消耗品成功     | 当层商店有 items 槽，user 有足够 Coin | buy(0, 0)         | Coin 扣减 itemCost，对应 itemId mint +1，shop.items[0]=0 |
| H-2 | test_buy_sword_success    | 购买剑成功        | 当层商店有 swords 槽，user 有足够 Coin | buy(1, 0)         | Coin 扣减 equipmentCost，剑槽清空（level=0）         |


### 2. Reverts: onlyRegistered

| ID  | 函数名                            | 场景简述     | 预期 revert            |
| --- | --------------------------------- | ------------ | ---------------------- |
| R-1 | test_buy_revertWhenNotRegistered  | 未 born 即购买 | PlayerNotFound(user)   |


### 3. Reverts: typeIndex

| ID  | 函数名                                 | 场景简述        | 预期 revert                    |
| --- | -------------------------------------- | --------------- | ------------------------------ |
| R-2 | test_buy_revertWhenInvalidTypeIndex    | typeIndex = 4   | InvalidTypeIndex(4)            |


### 4. Reverts: index / 已售

| ID  | 函数名                                 | 场景简述           | 预期 revert                |
| --- | -------------------------------------- | ------------------ | -------------------------- |
| R-3 | test_buy_revertWhenIndexOutOfRange     | index 越界（如 1000） | InvalidIndex(1000)         |
| R-4 | test_buy_revertWhenItemAlreadySold     | 同一槽位购买两次     | 第二次 InvalidIndex(0)     |


### 5. Reverts: insufficient Coin

| ID  | 函数名                                 | 场景简述                     | 预期 revert                |
| --- | -------------------------------------- | ---------------------------- | -------------------------- |
| R-5 | test_buy_revertWhenInsufficientCoin    | 先买一件耗尽余额，再买第二件且余额不足 | InsufficientCoin.selector  |


## 辅助方法

| 方法                         | 用途                                               |
| ---------------------------- | -------------------------------------------------- |
| _clearCurrentFloor(seed)     | 清空当层所有敌人（按 seed 依次 battle）               |
| _advanceToFloor(idx, seedBase) | 推进到目标楼层（循环清层 + nextFloor）                |
| _advanceToFloorWithShop()    | 推进到带商店的楼层（到 2 层后清层，再 nextFloor 到 3 层） |
| _itemCost(itemId)            | 与 Property.itemCost 一致的消耗品价格（书/血瓶，1e18 单位） |
| _equipmentCost(level, rarity)| 与 Property.equipmentCost 一致的装备价格（1e18 单位）   |
| _giveUserCoin(coinAmount)   | 给 user 至少 1 ether token 并 deposit，得到 Coin   |


---
