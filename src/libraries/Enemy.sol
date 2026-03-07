// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FloorIndex} from "./FloorIndex.sol";

// enemy is called Aoka.
enum AokaType {
    Tin, // special Aoka
    Slime,
    Goblin,
    Golem,
    Bat,
    Giant,
    Hellhound,
    Yeti,
    Skeleton,
    Zombie,
    Vampire,
    Werewolf,
    Witch,
    Orc,
    Hornet,
    Lizardman,
    Imp,
    Spider,
    Wisp,
    Gremlin, // index 19
    SlimeKing, // BOSS
    DarkLord,
    FrostQueen,
    FireElemental,
    ThunderTitan,
    ShadowReaper,
    CrystalGuardian,
    IronColossus,
    Warlock,
    SerpentEmperor,
    PhantomKnight,
    BloodWraith,
    SpecterKing,
    BoneCrusher,
    MagmaBeast,
    StormBringer,
    MoonPriest,
    SunWarden,
    AbyssWatcher,
    TitanLord // index 39
}

enum AokaTrait {
    Electric,
    Earth,
    Fire
}

struct Aoka {
    AokaType typ;
    AokaTrait trait;
    uint8 level; // 1-100
    uint16 health;
    uint16 attack;
    uint16 defense;
    uint8 crit; // 0 - 5
    uint8 critChance; // 0-100
    uint8 blockChance; // 0-100
    uint8 stunChance; // 0-100
    bool isBoss;
}

library Enemy {
    function fillAokas(Aoka[] storage aokas, bytes32 random, uint256 floorIndex, uint256 count) internal {
        unchecked {
            bool isBoss = FloorIndex.isBossFloor(floorIndex);

            // about 5% probability
            bool tinAppear = uint8(random[0]) < 13;

            // count is at most 4
            for (uint256 i = 0; i < count; i++) {
                // casting to 'uint8' is safe because i <= 3
                // forge-lint: disable-next-line(unsafe-typecast)
                uint8 offset = uint8(i * 5);
                bool tinRound = false;

                AokaType typ = _aoKaType(isBoss, floorIndex, uint8(random[offset + 1]));
                uint16 health = _health(isBoss, floorIndex);
                uint16 attack = _attack(isBoss, floorIndex);
                uint16 defense = _defense(isBoss, floorIndex);

                if (tinAppear && i == 0 && !isBoss) {
                    typ = AokaType.Tin;
                    tinRound = true;
                }
                aokas.push(
                    Aoka({
                        typ: typ,
                        trait: _aokaTrait(uint8(random[offset + 2])),
                        // casting to 'uint8' is safe because  floorIndex <=99
                        // forge-lint: disable-next-line(unsafe-typecast)
                        level: uint8(floorIndex + 1),
                        crit: _crit(isBoss, floorIndex),
                        critChance: _critChance(isBoss, floorIndex),
                        blockChance: _blockChance(isBoss, floorIndex),
                        stunChance: _stunChance(isBoss, floorIndex),
                        isBoss: isBoss,
                        attack: isBoss
                            ? attack
                            : _floatedAttack(attack, floorIndex, uint8(random[offset + 3]), tinRound),
                        defense: isBoss
                            ? defense
                            : _floatedDefense(defense, floorIndex, uint8(random[offset + 4]), tinRound),
                        health: isBoss
                            ? health
                            : _floatedHealth(health, floorIndex, uint8(random[offset + 5]), tinRound)
                    })
                );
            }
        }
    }

    function _attack(bool isBoss, uint256 floorIndex) private pure returns (uint16) {
        unchecked {
            if (isBoss) {
                // forge-lint: disable-next-line(unsafe-typecast)
                return floorIndex < 20 ? uint16(7 + floorIndex) : uint16(30 + (floorIndex * 3));
            } else {
                // forge-lint: disable-next-line(unsafe-typecast)
                return floorIndex < 20 ? uint16(3 + floorIndex) : uint16(floorIndex * 2);
            }
        }
    }

    /// @notice calculate enemy floated attack, exclude boss
    /// @dev randomly adds some defense fluctuation to prevent all enemies
    ///      on the same floor from having identical attack.
    function _floatedAttack(uint16 attack, uint256 floorIndex, uint8 random, bool tin) private pure returns (uint16) {
        unchecked {
            uint256 range = floorIndex / 4;

            // range is at most 19
            uint256 attackFinal = uint256(attack) + (uint256(random) % (2 * range + 1)) - range;

            if (tin) {
                attackFinal += attackFinal / 4;
            }

            // casting to 'uint16' is safe because attak <=173, floorIndex <= 99
            // forge-lint: disable-next-line(unsafe-typecast)
            return uint16(attackFinal);
        }
    }

    function _defense(bool isBoss, uint256 floorIndex) private pure returns (uint16) {
        unchecked {
            // forge-lint: disable-next-line(unsafe-typecast)
            return isBoss ? uint16(4 + floorIndex) : uint16(2 + floorIndex);
        }
    }

    /// @notice calculate enemy floated defense, exclude boss
    /// @dev randomly adds some defense fluctuation to prevent all enemies
    ///      on the same floor from having identical defense.
    function _floatedDefense(uint16 defense, uint256 floorIndex, uint8 random, bool tin) private pure returns (uint16) {
        unchecked {
            uint256 range = floorIndex / 5;

            // range is at most 19
            uint256 defenseFinal = uint256(defense) + (uint256(random) % (2 * range + 1)) - range;

            if (tin) {
                defenseFinal += defenseFinal / 4;
            }

            // casting to 'uint16' is safe because defense <=32, floorIndex <= 99
            // forge-lint: disable-next-line(unsafe-typecast)
            return uint16(defenseFinal);
        }
    }

    function _health(bool isBoss, uint256 floorIndex) private pure returns (uint16) {
        unchecked {
            // forge-lint: disable-next-line(unsafe-typecast)
            return isBoss ? uint16(40 + floorIndex * 20) : uint16(12 + (floorIndex * 8));
        }
    }

    /// @notice calculate enemy floated health, exclude boss
    /// @dev randomly adds some health fluctuation to prevent all enemies
    ///      on the same floor from having identical health.
    function _floatedHealth(uint16 health, uint256 floorIndex, uint8 random, bool tin) private pure returns (uint16) {
        unchecked {
            uint256 range = floorIndex / 5;
            if (range == 0) range = 1;

            // range is at most 19
            uint256 healthFinal = uint256(health) + (uint256(random) % (2 * range + 1)) - range;

            if (tin) {
                healthFinal += healthFinal / 4;
            }

            // casting to 'uint16' is safe because health <=319, floorIndex <= 99
            // forge-lint: disable-next-line(unsafe-typecast)
            return uint16(healthFinal);
        }
    }

    function _crit(bool isBoss, uint256 floorIndex) private pure returns (uint8) {
        unchecked {
            return
            // casting to 'uint8' is safe because the result is at most 3
            // forge-lint: disable-next-line(unsafe-typecast)
            isBoss
                ? uint8(floorIndex < 25 ? 1 : (floorIndex < 60 ? 2 : 3))
                : uint8(floorIndex < 30 ? 0 : (floorIndex < 60 ? 1 : 2));
        }
    }

    function _critChance(bool isBoss, uint256 floorIndex) private pure returns (uint8) {
        unchecked {
            if (isBoss) {
                uint256 cc = 5 + floorIndex / 5;
                if (cc > 20) return 20;
                // casting to 'uint8' is safe because cc <= 20
                // forge-lint: disable-next-line(unsafe-typecast)
                return uint8(cc);
            } else {
                uint256 cc = floorIndex < 15 ? 0 : (floorIndex - 15) / 2;
                if (cc > 15) return 15;
                // casting to 'uint8' is safe because cc <= 15
                // forge-lint: disable-next-line(unsafe-typecast)
                return uint8(cc);
            }
        }
    }

    function _blockChance(bool isBoss, uint256 floorIndex) private pure returns (uint8) {
        unchecked {
            if (isBoss) {
                uint256 bc = 5 + floorIndex / 6;
                if (bc > 15) return 15;
                // casting to 'uint8' is safe because cc <= 15
                // forge-lint: disable-next-line(unsafe-typecast)
                return uint8(bc);
            } else {
                uint256 bc = floorIndex < 20 ? 0 : (floorIndex - 20) / 3;
                if (bc > 12) return 12;
                // casting to 'uint8' is safe because cc <= 12
                // forge-lint: disable-next-line(unsafe-typecast)
                return uint8(bc);
            }
        }
    }

    function _stunChance(bool isBoss, uint256 floorIndex) private pure returns (uint8) {
        unchecked {
            if (isBoss) {
                uint256 sc = floorIndex < 20 ? 0 : (floorIndex - 20) / 5;
                if (sc > 10) return 10;
                // casting to 'uint8' is safe because cc <= 10
                // forge-lint: disable-next-line(unsafe-typecast)
                return uint8(sc);
            } else {
                uint256 sc = floorIndex < 40 ? 0 : (floorIndex - 40) / 5;
                if (sc > 8) return 8;
                // casting to 'uint8' is safe because cc <= 8
                // forge-lint: disable-next-line(unsafe-typecast)
                return uint8(sc);
            }
        }
    }

    function _aoKaType(bool isBoss, uint256 floorIndex, uint8 random) private pure returns (AokaType) {
        if (isBoss) {
            // here floorIndex start with 4
            return AokaType((floorIndex + 1) / 5 + 19);
        } else {
            uint256 s = 19;
            if (floorIndex < 10) {
                s = 4;
            }
            // random type index: 1-19 or 1-4
            return AokaType((uint256(random) % s) + 1);
        }
    }

    function _aokaTrait(uint8 random) private pure returns (AokaTrait) {
        return AokaTrait(random % 3);
    }
}
