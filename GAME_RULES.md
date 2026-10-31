# Deckhand Digital - Core Game Rules (Implementation Spec)

This document rewrites the tabletop rules into implementation-ready terms.
Use this file as the primary rules reference for gameplay logic.
The printed French rulebook (`90x140-rules-fr.pdf`) is the source; section 19
lists the points the rulebook leaves open and how the digital version settles them.

## 1. Game Summary

- Players: 1 to 5
- Age target: 14+
- Typical duration: ~45 minutes
- Win condition: after 5 rounds, highest Victory Points (VP) wins

A game round has two stages:
1. Draft Phase
2. Build Phase Loop

## 2. Components

- 96 Supply cards (`deck/013..108`; 097..108 are second copies of earlier cards)
- 12 Infamy cards (`deck/001..012`)
- Card data: `data/cards.json`, generated from `cards.en.js` by `tools/build_cards.js`

### 2.1 Card Anatomy

Supply card:
1. Production (blue frame, top left): resources produced while in your Crew
2. Raised Banners (banners on a flagpole, next to production)
3. Effects / VP (top right)
4. Build cost (hanging price tag)

Infamy card:
- Effects / VP (top right)
- Banners required to claim it (bottom)

## 3. Core Concepts

- Hand: cards currently held by a player (face down to opponents)
- Crew: built cards in front of a player (face up)
- Windfall: each player's starting Infamy card. It stays in hand, cannot be
  built, and is only used as payment (worth 2 coins, see 10.2)
- Row: 5 Infamy slots, one per round, revealed left to right
- Supply deck: draw deck for Supply cards
- Infamy deck: remaining Infamy draw deck after setup
- Discard pile: shared discard for Supply cards
- Raised Banners: banners on a flagpole, used for claiming Infamy and some scoring

### 3.1 Resources (data tokens)

| Token | Resource    | Notes |
|-------|-------------|-------|
| `g`   | Gun         | |
| `p`   | Parrot      | |
| `r`   | Rum         | |
| `h`   | Helm        | |
| `s`   | Skull       | |
| `e`   | Emerald     | |
| `c`   | Gold coin   | only produced by discarding |
| `cs`  | Silver coin | by discarding, or from some Crew cards |

### 3.2 Banner types

`basic` (Pearl), `gun`, `parrot`, `rum`, `helm`, `skull`, `crown`, `coin`
(the thief's hand). The Pearl banner is a banner type of its own: it is not a
wildcard and not a coin.

## 4. Setup

1. Shuffle all 12 Infamy cards.
2. Place 5 Infamy cards face down into a 5-slot Row (round slots 1..5).
3. Deal 1 random Infamy card to each player as their Windfall.
4. Place remaining Infamy cards face down as the Infamy deck.
5. Shuffle all 96 Supply cards and place as the Supply deck.
6. Determine seating order (clockwise table order).

## 5. Match Structure

The game runs exactly 5 rounds.
At the start of each round, reveal the leftmost unrevealed Infamy card(s) in the Row,
then check Infamy claims (section 11).
Revealed Infamy cards stay in the Row until claimed.

## 6. Draft Phase

### 6.1 Draft Hand Creation

1. Each player places their current hand face down (round 1: only the Windfall).
2. Each player draws 5 Supply cards into a Draft hand.
3. Round 1 only, one-time mulligan option per player:
   - discard entire Draft hand
   - draw 5 new Supply cards

### 6.2 Draft Picks and Passing

Repeat until all drafted cards are exhausted:
1. Each player selects 1 card from their Draft hand and adds it face down to their personal picked stack.
2. Pass remaining Draft hand by wind direction:
   - odd rounds (1, 3, 5): clockwise
   - even rounds (2, 4): counterclockwise

Players may look at their picked cards at any time.
After the draft completes, each player adds their picked cards to their hand
(the hand put aside in 6.1 step 1 is kept).

## 7. Build Phase Loop

The build loop repeats until all players have passed.
All reveal decisions are simultaneous.

### 7.1 Loop Step Order

1. Each active player chooses 1 Supply card from hand to build (face down selection).
2. Simultaneous reveal:
   - reveal chosen card, or
   - pass (if pass, player is out for the rest of the round)
3. Pay the revealed card's build cost.
4. Move the built card to Crew (face up).
5. Resolve the built card's instant effects.
6. Resolve Infamy claims from currently revealed Row cards.

## 8. End of Round

- Each player discards down to hand size 8 (the Windfall counts as a hand card).
- Start next round unless round 5 has ended.

## 9. End of Game

After round 5:
1. Sum VP from all cards in each player's Crew (including multipliers).
2. Highest total wins.
3. Tie-breaker: most Tentacles wins.
4. If still tied, tied players share victory.

### 9.1 Solo ranks

| Score | Rank |
|-------|------|
| 0-39  | Hull Scraper (Écailleur de coques) |
| 40-49 | Almost-Loyal Buccaneer (Flibustier quasi-loyal) |
| 50-64 | Feared and Respected (Craint et respecté) |
| 65-84 | Expert Navigator (Navigateur expert) |
| 85+   | Sovereign of the High Seas (Souverain des Hautes-Mers) |

## 10. Resource and Payment System

### 10.1 Production

- Built Crew cards produce resources shown in their blue production frame.
- Each produced resource can be used once per card being built.
- Split production (A | B) produces one of the listed resources, chosen at use.
- If production is insufficient, player must discard cards for extra resources.

### 10.2 Discard for Resources

A player may produce resources by discarding hand cards face down to the common discard pile:

| Discard | Produces |
|---------|----------|
| 1 card | 1 silver coin or 1 gold coin |
| Windfall | 2 silver coins, or 1 gold + 1 silver coin |
| 1 card, revealed | one resource that card produces (its production frame; a choice A \| B applies) |
| 2 cards | any 1 resource |

Infamy cards have no production, so a revealed Windfall produces nothing extra.

Windfall discard special rule:
- when Windfall is discarded, either
  - shuffle it into Infamy deck, or
  - stack it face down on top of an unrevealed Row slot
- stacked cards are revealed together at that slot's round start

The legacy `discard` field in `cards.en.js` is not part of the rules and is ignored.

### 10.3 Supply Depletion

- If Supply deck is empty for any reason, shuffle discard pile to form a new Supply deck.

### 10.4 Insufficient Cards to Draw

- If an effect requests multiple draws and not enough cards exist (even after reshuffle), draw as many as possible.
- During Draft Phase, all players must still receive equal card counts.

## 11. Infamy Claim Rules

Infamy claims are checked:
- when Row cards are revealed, and
- during Build Loop step 6

A player may claim a revealed Infamy card if their Raised Banners meet or exceed that card's requirement
(per banner type; banners are not spent).
When claimed:
1. Add Infamy card to Crew.
2. Resolve its instant effects.

If 2+ players qualify for the same Infamy card at the same moment:
- default: card is removed from game
- exception: the player with the most Tentacles claims it (section 13.6)

## 12. Symbol Rules

### 12.1 Base Symbols

- Raised Banners: used for Infamy claims and some scoring
- VP symbol (wax seal with a number): points scored at end of game
- Split production (A | B): choose one of the listed resources when producing; the choice also applies when discarding
- Coins:
  - gold coin can be produced only by discarding
  - any card can be discarded for a coin
  - silver coin may also come from specific Crew cards
- The diagram on the Supply card back suggests which resources to build first,
  usually marked by a Pearl banner on the front.

### 12.2 Multiplier Symbols

- `N x [banner]`: at end of game, score N VP per Raised Banner of that type in your Crew.
- The banner pictured in a multiplier has no flagpole and is not itself a Raised Banner.

## 13. Advanced Effect Rules

Instant effects trigger when the card is added to Crew.

### 13.1 Telescope

- Look at one face-down Infamy card in Row and top card of Infamy deck.
- You may swap them.
- In round 5, you may place top deck card face up in Row instead of swapping.
- Then shuffle Infamy deck.

### 13.2 Draw Effects

- Draw X cards means draw from Supply deck unless effect text overrides.
- "Draw 3, keep 1, discard 2" (stack of cards marked 1) means exactly that sequence.

### 13.3 Trigger-on-Symbol Effects

- `[symbol] -> [effect]`: each time you add that symbol to your Crew, trigger the effect.
  Example: draw 1 card each time you add a Crown Raised Banner.
- Only flagpole banners count as Raised Banners. Tentacles can also be the trigger symbol.

### 13.4 Compass Draft Effect

- During each Draft, each Compass in Crew may be used once:
  - draw 1 additional draft card
  - discard 1 draft card before passing
- Multiple Compasses can be used at different draft moments.

### 13.5 Battle Effect

- A Battle is announced now and resolved on that player's next build.
- On resolution, each participating player scores the card they just built, including multipliers and +1 per Battle symbol in Crew.
- Highest score draws 1 card per Battle trigger.
- If tied, no winner unless Tentacles rule breaks tie.
- Players who did not build in that reveal do not participate.

### 13.6 Tentacles Rule

Tentacles break ties for:
- Infamy claims
- Battles
- End-game scoring

Higher Tentacles count wins tied comparisons.

### 13.7 Hook Effect

- Steal 1 random Supply card from an opponent hand.
- If stealer has fewer than 3 Hooks in Crew, stealer must give 1 Supply card from hand back to that opponent.

## 14. Priority Resolution Rule

When multiple simultaneous claim/effect actions must be ordered:
1. Player with most Tentacles acts first.
2. If still tied, choose randomly among tied players.
3. Continue one action at a time in current wind direction order.

Priority can occur with Hook, Telescope-like swaps, and rare Infamy conflicts.

## 15. Beginner Variant

Suggested teaching variant:
- Resolve payment and effects one player at a time.
- Ignore advanced symbols initially.
- In round 1 draft, use 7 cards instead of 5 (can be kept for later games).

## 16. Solo Variant (1 Human + Virtual Opponent)

1. Set up normal game with one virtual opponent.
2. During each draft pick step, randomly select one card for the virtual opponent.
3. Each time human builds, virtual opponent builds one random Supply card from their hand (free).
4. Resolve virtual effects and Infamy claims normally.
5. Ignore Hook effects in solo mode.
6. Score normally at game end and compare against the ranks in 9.1.

## 17. Data Model (as implemented in `engine/`)

### 17.1 Global State (`DeckhandGame`)

- `round_index`: 1..5, `wind()`: +1 clockwise (odd rounds), -1 otherwise
- `supply`, `discard_pile`, `infamy_deck`, `removed`
- `row[5]`: `{cards: [ids], revealed: bool}` (stacked Windfalls append to `cards`)
- `pending`: player -> decision awaiting an answer (`submit(player, action)`)

### 17.2 Per-Player State

- `hand`, `crew`, `windfall`, `passed`
- `draft_hand`, `picks`, `compasses_used`, `pending_battles`
- derived: `tentacles()`, `raised_banners()`, `crew_production_slots()`, `score()`

### 17.3 Deterministic Resolution Order

For any simultaneous conflict:
- apply Priority Rule (section 14)
- the game RNG is seeded, so a seed plus the list of submitted actions replays a game

## 18. Rule Authority

If card text conflicts with general rules, card text takes priority unless explicitly blocked by a global rule in this document.

## 19. Digital Rulings

Points the rulebook leaves open, and how the engine resolves them:

- **Effects of several builders** in one reveal resolve player by player in
  priority order (all of one player's effects, then the next player's).
- **Triggers** (`X -> effect`) fire for symbols on the card being added, not for
  the trigger card's own symbols.
- **Claims** resolve one at a time in priority order, re-checking after each, so
  a Tentacle gained from one claim can break a tie on another card. A tie that
  Tentacles cannot break removes the card from the game.
- **Pending Battles** carry over to the player's next build, even into a later round.
- **Telescope on a stacked slot** looks at the top card of the stack.
- **Hook** targets are chosen by the hooking player; the stolen card is random.
- **Payment**: the player picks which cards to discard; the engine works out the
  best use of them (coin, revealed resource or pair) automatically.
