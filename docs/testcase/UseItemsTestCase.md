# UseItems 测试用例

## 被测对象

- **合约**: GameLogic
- **函数**: `useItems(uint256[] calldata slots) external`
- **说明**: 使用背包中指定槽位的物品（当前仅支持 Book、Potion）；slots 须严格升序且不重复，长度 1～5。

## 前置与环境

- **Harness**: `GameV1UseItemsHarness`，暴露 `exposedAddItemToBag(uint256 itemId)` 用于向背包塞入书/药水。
- **setUp**: 部署 GameToken、GameAssets、GameV1UseItemsHarness 实现与 ERC1967Proxy，配置 token.setProxy / assets.setProxy，gameLogic 指向 proxy，harness 指向 proxy；固定 owner、user 地址。

## 测试用例列表

### 1. Happy path


| ID  | 函数名                                   | 场景简述          | 前置条件                        | 操作                                               | 预期结果                                   |
| --- | ------------------------------------- | ------------- | --------------------------- | ------------------------------------------------ | -------------------------------------- |
| H-1 | test_useItems_singlePotion_slot0      | 使用 slot 0 的药水 | user 已 born，slot 0 为药水      | useItems([0])                                    | bag[0]=0，health 按药水逻辑（满血则保持 healthMax） |
| H-2 | test_useItems_singleBook_levelUp      | 使用一本书升级       | user 已 born，slot 1 为 BOOK_C | 先 exposedAddItemToBag(BOOK_C_ID)，再 useItems([1]) | level=2，bag[1]=0                       |
| H-3 | test_useItems_twoSlots_ascendingOrder | 多槽位严格升序使用     | born + slot 1 书、slot 2 药水   | useItems([0,1,2])                                | 三个槽位均被消耗，level=2                       |
| H-4 | test_useItems_singleSlot_len1Allowed  | 仅传一个 slot     | user 已 born                 | useItems([0])                                    | 不 revert，slot 0 被消耗                    |


### 2. Reverts: length


| ID  | 函数名                                    | 场景简述     | 预期 revert                                |
| --- | -------------------------------------- | -------- | ---------------------------------------- |
| R-1 | test_useItems_revertWhenEmptySlots     | 空数组      | IGameLogic.LengthOutOfRange1To5.selector |
| R-2 | test_useItems_revertWhenMoreThan5Slots | 6 个 slot | IGameLogic.LengthOutOfRange1To5.selector |


### 3. Reverts: sequence


| ID  | 函数名                                    | 场景简述     | 预期 revert                         |
| --- | -------------------------------------- | -------- | --------------------------------- |
| R-3 | test_useItems_revertWhenWrongSequence  | 降序 [1,0] | IGameLogic.WrongSequence.selector |
| R-4 | test_useItems_revertWhenDuplicateSlots | 重复 [0,0] | IGameLogic.WrongSequence.selector |


### 4. Reverts: slot / item


| ID  | 函数名                                    | 场景简述             | 预期 revert                         |
| --- | -------------------------------------- | ---------------- | --------------------------------- |
| R-5 | test_useItems_revertWhenSlotOutOfRange | slot 越界（如 10）    | ItemNotFound(10)                  |
| R-6 | test_useItems_revertWhenSlotEmpty      | 使用已消耗的 slot      | ItemNotFound(0)                   |
| R-7 | test_useItems_revertWhenWrongItemType  | 使用不可用类型（如 Stone） | IGameLogic.WrongItemType.selector |


### 5. Reverts: access


| ID  | 函数名                                   | 场景简述       | 预期 revert            |
| --- | ------------------------------------- | ---------- | -------------------- |
| R-8 | test_useItems_revertWhenNotRegistered | 未 born 即调用 | PlayerNotFound(user) |


## 辅助方法


| 方法                | 用途                                |
| ----------------- | --------------------------------- |
| _slots(uint256 a) | 构造单元素 slots 数组                    |
| _slots(a, b)      | 构造两元素 slots 数组                    |
| _slots(a, b, c)   | 构造三元素 slots 数组                    |
| _slots(a..f)（6 参） | 构造六元素 slots 数组（用于 >5 的 revert 测试） |


---

