# Equip / Unequip 测试用例

## 被测对象

- **合约**: GameLogic
- **函数**: `equip(uint256 equipmentId) external`、`unequip(uint256 equipmentId) external`
- **说明**: equip 从仓库取出装备并装备到对应槽位（Sword/Armor/Shield/Puppet）；equipmentId 须在 [1e9, 5e9) 且存在于仓库。unequip 将已装备的装备卸下并放回仓库。

## 前置与环境

- **Harness**: `GameV1EquipHarness`，暴露 `exposedGetEquipped(address addr)` 用于读取当前装备（Sword / Armor / Shield / Puppet）。
- **setUp**: 部署 GameToken、GameAssets、GameV1EquipHarness 实现与 ERC1967Proxy，配置 token.setProxy / assets.setProxy，gameLogic 指向 proxy，harness 指向 proxy；固定 owner、user 地址。
- **born() 后仓库**: 剑 id=1e9、木偶 id=4e9 在仓库中；装备槽位 0=Sword、1=Armor、2=Shield、3=Puppet。

## 测试用例列表

### 1. equip — Happy path

| ID  | 函数名                        | 场景简述           | 前置条件           | 操作              | 预期结果                                           |
| --- | ----------------------------- | ------------------ | ------------------ | ----------------- | -------------------------------------------------- |
| H-1 | test_equip_sword_success      | 装备剑成功           | user 已 born       | equip(1e9)        | 仓库不再含 1e9；exposedGetEquipped 中 sword.attack=8 |
| H-2 | test_equip_puppet_success     | 装备木偶成功          | user 已 born       | equip(4e9)        | 仓库不再含 4e9；exposedGetEquipped 中 puppet.rarity=C |
| H-3 | test_equip_then_unequip_roundtrip | 装备后卸下往返        | user 已 born       | equip(1e9) 再 unequip(1e9) | 装备槽清空，仓库再次包含 1e9                          |

### 2. equip — Reverts

| ID  | 函数名                                          | 场景简述           | 前置条件 / 操作                         | 预期 revert                    |
| --- | ----------------------------------------------- | ------------------ | --------------------------------------- | ------------------------------ |
| R-1 | test_equip_revertWhenNotInWarehouse             | 装备不在仓库（如重复装备） | born，equip(1e9) 后再 equip(1e9)        | EquipmentNotFound(1e9)        |
| R-2 | test_equip_revertWhenInvalidEquipmentId_zero    | equipmentId=0      | born，equip(0)                          | InvalidEquipmentId(0)         |
| R-3 | test_equip_revertWhenInvalidEquipmentId_tooHigh | equipmentId=5e9    | born，equip(5e9)                        | InvalidEquipmentId(5e9)       |
| R-4 | test_equip_revertWhenNotRegistered              | 未注册即装备         | 未 born，equip(1e9)                      | PlayerNotFound(user)          |

### 3. unequip — Happy path

| ID  | 函数名                          | 场景简述     | 前置条件              | 操作                    | 预期结果                     |
| --- | ------------------------------- | ------------ | --------------------- | ----------------------- | ---------------------------- |
| H-4 | test_unequip_afterEquip_success | 装备后卸下成功 | user 已 born，equip(1e9) | unequip(1e9)             | 仓库含 1e9，装备槽 sword 为空 |

### 4. unequip — Reverts

| ID  | 函数名                                       | 场景简述         | 前置条件 / 操作              | 预期 revert                    |
| --- | -------------------------------------------- | ---------------- | ---------------------------- | ------------------------------ |
| R-5 | test_unequip_revertWhenNotEquipped           | 未装备即卸下       | born，直接 unequip(1e9)      | GameStorage.NotEquippedId(1e9) |
| R-6 | test_unequip_revertWhenInvalidEquipmentId_zero | equipmentId=0    | born，unequip(0)             | InvalidEquipmentId(0)         |
| R-7 | test_unequip_revertWhenNotRegistered         | 未注册即卸下       | 未 born，unequip(1e9)        | PlayerNotFound(user)         |

## 辅助方法

| 方法                              | 用途                     |
| --------------------------------- | ------------------------ |
| _arrayContains(uint256[] arr, uint256 value) | 判断数组是否包含某 id（校验仓库/装备状态） |

---
