# Tower Top - Frontend

Web frontend for the Tower Top GameFI DApp.

## Running locally (required)

The app uses ES modules (`import`). **Do not open `index.html` directly** (file://) or the browser will block loading scripts (CORS). Use a local HTTP server:

```bash
cd frontend
npm start
```

Then open **http://localhost:3000** in your browser.

Without npm: `cd frontend && npx serve . -p 3000`, or `python3 -m http.server 3000` (then open http://localhost:8000).

## Directory structure

- **assets/** – Static assets (images, sprites, audio)
  - **aoka/** – Enemy (Aoka) type icons, one per `AokaType` from contract
- **src/** – Frontend application code (React/Next.js, etc.)

## Game style (see docs/GAME_UI_STYLE.md)

- **Visual:** Cartoon style, similar to [EOS Knights](https://eosknights.io)
- **Battle layout:** Pokémon-style – enemy top-left facing player, player bottom-right from behind
- **Battle feedback:** Hit effects, character shake or flash (implementable with JS/CSS animation)
