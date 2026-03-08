# Tower Top - Frontend

Web frontend for the Tower Top GameFI DApp.

## Directory structure

- **assets/** – Static assets (images, sprites, audio)
  - **aoka/** – Enemy (Aoka) type icons, one per `AokaType` from contract
- **src/** – Frontend application code (React/Next.js, etc.)

## Game style (see docs/GAME_UI_STYLE.md)

- **Visual:** Cartoon style, similar to [EOS Knights](https://eosknights.io)
- **Battle layout:** Pokémon-style – enemy top-left facing player, player bottom-right from behind
- **Battle feedback:** Hit effects, character shake or flash (implementable with JS/CSS animation)
