# Deckhand: Race for Infamy

A digital version of the Deckhand card game. Recruit a crew of rogues over five
rounds, raise your banners, claim Infamy, and score the most Victory Points.
You play against 1 to 4 bots, or a solo variant against a virtual opponent.

Built with [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/).

## Run the game

1. Install **Godot 4.3** (the standard build; .NET isn't needed).
2. Open Godot, click **Import**, and select this folder's `project.godot`.
3. Press **F5**, or the ▶ button at the top right.

Or from a terminal (macOS path shown; use your own Godot binary elsewhere):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

The first launch imports the assets, which can take a minute.

The game starts fullscreen. Press **Esc** for the menu.

## Controls

| Input | Action |
|---|---|
| Mouse | Hover a card to see its rules; click to play it |
| ← / → | Move between cards (the open choice, otherwise your hand) |
| Enter / Space | Play the focused card, or press the green button (Keep, Confirm) |
| Letter on a button | Press that button (e.g. **P** Pass, **B** Build, **A** Auto-pay, **C** Cancel) |
| H | Hide or show the current choice to look at the table |
| Tab | Move between buttons |
| Esc | Open or close the menu |

Every button shows its key in a small badge on its corner.

Volumes are set in the menu and saved between sessions.

## Online play

**Play online** in the menu creates a table (you get a 5-letter code to share)
or joins one. The host picks how many bots fill the empty seats, and starts.

The game runs in lockstep on every player's machine: the server is a small
relay in [server/](server/) (a Cloudflare Worker, one Durable Object per
table). It knows nothing of the rules. It picks the seed and passes every
move to every player in the same order. The host's machine plays the bots,
and any player who has been away for 15 seconds. A player who drops out
rejoins their seat automatically, and catches up from the moves so far.

### Run the relay locally

```sh
cd server
npm install
npm run dev            # relay on http://localhost:8787
npm test               # relay tests (with the dev relay running)
```

Point the game at it with `--relay`:

```sh
godot --path . -- --relay=http://localhost:8787
godot --headless --path . -s res://tests/test_online.gd -- --relay=http://localhost:8787
```

### Deploy

```sh
cd server
npx wrangler login     # once
npm run deploy
```

[server/wrangler.jsonc](server/wrangler.jsonc) serves it on `play.tidale.org`
(the tidale.org zone must be on the same Cloudflare account); the game connects
there by default (`NetClient.DEFAULT_URL`). On the free plan, idle tables cost
nothing; a table untouched for 7 days is deleted.

## Tests

Both run headless and play full games:

```sh
# Rules engine: card data, payments, 40 bot-only games.
godot --headless --path . -s res://tests/test_engine.gd

# Table UI: two complete games through the real game scene.
godot --headless --path . -s res://tests/test_ui.gd
```

## Build a release

In Godot: **Project → Export…**, then pick the **macOS** preset and export.
The first time, Godot asks you to download the export templates for 4.3.
The preset writes `deckhand.dmg` to `~/Downloads`.

## Project layout

| Path | What it holds |
|---|---|
| `engine/` | The rules: game state, payments, bots. No rendering. |
| `scenes/game/` | The table UI, card views and motion, sounds, shaders |
| `data/cards.json` | Card data, generated from `cards.en.js` |
| `deck/`, `backs/` | Card images |
| `assets/` | Art, icons, music and sound effects |
| `tests/` | Headless engine and UI tests |
| `tools/` | Generators for card data and sound effects |
| `GAME_RULES.md` | The rules as implemented |

## Regenerating data

```sh
node tools/build_cards.js   # cards.en.js -> data/cards.json
python3 tools/make_sfx.py   # synthesizes assets/sfx/*.wav
```

## Credits

- **Publisher:** [Tidale](https://tidale.org/deckhand-race-for-infamy/)
- **Game design:** Batiste Bieler
- **Illustrations:** Vitor Henrique, Ricardo Zopello, Batiste Bieler, Mauri, Toloma, Daniel Cunha, Marvin Blattert, Matias Gonzalez
- **Iconography:** Louise Fayt, Batiste Bieler
- **Playtesting:** Jessica Gibbons, Gaël Nardin, Jonathan Bieler, Eduard Schäli, Riccardo Zoppello, Lucas Clark, the Break My Game community, and many others
- **Music:** composed with Suno
- **Sound effects:** synthesised by `tools/make_sfx.py`
- **Typeface:** Signika by Anna Giedryś, under the SIL Open Font License (`scenes/shared/fonts/signika/OFL.txt`)
- **Engine:** [Godot Engine](https://godotengine.org)

## License

GPL-3.0, see [LICENSE](LICENSE).
