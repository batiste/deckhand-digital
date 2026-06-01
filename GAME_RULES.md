# Deckhand Digital - Core Game Rules (Implementation Spec)

This document rewrites the tabletop rules into implementation-ready terms.
Use this file as the primary rules reference for gameplay logic.

## 1. Game Summary

- Players: 1 to 5
- Age target: 14+
- Typical duration: ~45 minutes
- Win condition: after 5 rounds, highest Victory Points (VP) wins

A game round has two stages:
1. Draft Phase
2. Build Phase Loop

## 2. Components

- 96 Supply cards
- 12 Infamy cards

## 3. Core Concepts

- Hand: cards currently held by a player (face down to opponents)
- Crew: built cards in front of a player (face up)
- Windfall: each player's starting Infamy card (special hand card)
- Row: 5 Infamy slots, one per round, revealed left to right
- Supply deck: draw deck for Supply cards
- Infamy deck: remaining Infamy draw deck after setup
- Discard pile: shared discard for Supply cards
- Raised Banners: banner values used for claiming Infamy and some scoring

## 4. Setup

1. Shuffle all 12 Infamy cards.
2. Place 5 Infamy cards face down into a 5-slot Row (round slots 1..5).
3. Deal 1 random Infamy card to each player as their Windfall.
4. Place remaining Infamy cards face down as the Infamy deck.
5. Shuffle all 96 Supply cards and place as the Supply deck.
6. Determine seating order (clockwise table order).

## 5. Match Structure

The game runs exactly 5 rounds.
At the start of each round, reveal the leftmost unrevealed Infamy card(s) in the Row.

## 6. Draft Phase

### 6.1 Draft Hand Creation

1. Each player places their current hand face down.
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

After the draft completes, each player collects their face-down picked cards into their new hand.

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

- Each player discards down to hand size 8.
- Start next round unless round 5 has ended.

## 9. End of Game

After round 5:
1. Sum VP from all cards in each player's Crew.
2. Highest total wins.
3. Tie-breaker: most Tentacles wins.
4. If still tied, tied players share victory.

## 10. Resource and Payment System

### 10.1 Production

- Built Crew cards produce resources shown in their blue production frame.
- Produced resources are available when paying build costs.
- If production is insufficient, player must discard cards for extra resources.

### 10.2 Discard for Resources

A player may produce resources by discarding to the common discard pile:

1. Discard 1 card from hand (or Windfall) -> produce one resource that discarded card can produce.
2. Discard 1 card and reveal it -> produce one resource that revealed card can produce.
3. Discard 2 cards -> produce any 1 resource.

Windfall discard special rule:
- when Windfall is discarded, either
  - shuffle it into Infamy deck, or
  - stack it face down on top of an unrevealed Row slot
- stacked cards are revealed together at that slot's round start

### 10.3 Supply Depletion

- If Supply deck is empty for any reason, shuffle discard pile to form a new Supply deck.

### 10.4 Insufficient Cards to Draw

- If an effect requests multiple draws and not enough cards exist (even after reshuffle), draw as many as possible.
- During Draft Phase, all players must still receive equal card counts.

## 11. Infamy Claim Rules

Infamy claims are checked:
- when Row cards are revealed, and
- during Build Loop step 6

A player may claim a revealed Infamy card if their Raised Banners meet or exceed that card's requirement.
When claimed:
1. Add Infamy card to Crew.
2. Resolve its instant effects.

If 2+ players qualify for the same Infamy card at the same moment:
- default: card is removed from game
- exception: Tentacles tie-break rules may override (see section 13)

## 12. Symbol Rules

### 12.1 Base Symbols

- Raised Banners: used for Infamy claims and some scoring
- VP symbol: points scored at end of game
- Split production (A | B): choose one of the listed resources when producing
- Coins:
  - gold coin can be produced only by discarding
  - silver coin may also come from specific Crew cards

### 12.2 Multiplier Symbols

- Multiplier effects score VP at end game based on matching banner counts.
- A symbol that references a banner type without a flagpole is not itself a Raised Banner.

## 13. Advanced Effect Rules

These effects trigger when the card is added to Crew.

### 13.1 Telescope-like Effect

- Look at one face-down Infamy card in Row and top card of Infamy deck.
- You may swap them.
- In round 5, you may place top deck card face up in Row instead of swapping.
- Then shuffle Infamy deck.

### 13.2 Draw Effects

- Draw X cards means draw from Supply deck unless effect text overrides.
- "Draw 3, keep 1, discard 2" means exactly that sequence.

### 13.3 Trigger-on-Banner Effects

- Effects with "each time you add symbol X" trigger whenever the required symbol is newly added to your Crew.
- Only flagpole banners count as Raised Banners.

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
- In round 1 draft, use 7 cards instead of 5.

## 16. Solo Variant (1 Human + Virtual Opponent)

1. Set up normal game with one virtual opponent.
2. During each draft pick step, randomly select one card for the virtual opponent.
3. Each time human builds, virtual opponent builds one random Supply card from their hand.
4. Resolve virtual effects and Infamy claims normally.
5. Ignore Hook effects in solo mode.
6. Score normally at game end.

## 17. Suggested Data Model (for implementation)

### 17.1 Global State

- round_index: 1..5
- wind_direction_for_round
- supply_deck, supply_discard
- infamy_deck
- row_slots[5] with reveal state and possibly stacked Infamy

### 17.2 Per-Player State

- hand
- crew
- windfall
- passed_this_round
- resources_cache (optional computed each build)
- tentacle_count, raised_banners_by_type, vp_total (derived)

### 17.3 Deterministic Resolution Order

For any simultaneous conflict:
- apply Priority Rule (section 14)
- record event log for replay/debugging

## 18. Rule Authority

If card text conflicts with general rules, card text takes priority unless explicitly blocked by a global rule in this document.
