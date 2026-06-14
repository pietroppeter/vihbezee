# vihbezee — Build Plan

## Overview

Client-only Yahtzee SPA built with Nim + Karax, compiled to JavaScript, deployed to GitHub Pages.  
Hotseat play for 2–4 players on one device. Two dice modes: the app rolls for you (Virtual) or you bring your own dice (Physical) and tap in the results.  
Game state is persisted in localStorage so a game survives a page refresh.

**Live URL:** https://pietroppeter.github.io/vihbezee/  
**Branch:** `claude/yahtzee-nim-karax-ulxgir` → merged to `main` for Pages

---

## Component Breakdown

| # | Component | Status |
|---|-----------|--------|
| 1 | Setup / Home screen | 🔨 in progress |
| 2 | Dice rolling (Virtual + Physical input) | ⬜ todo |
| 3 | Scorecard display + live preview | ⬜ todo |
| 4 | Full turn loop (dice → score → next player) | ⬜ todo |
| 5 | Game Over screen (leaderboard + recap + Play Again) | ⬜ todo |

Cross-cutting concerns finished alongside each component:
- **localStorage** — introduced in C1, extended in C2–C4
- **Responsive / mobile-first CSS** — refined with each component

---

## Component 1 — Setup / Home Screen

**Goal:** on page load, show either a setup form or a "game in progress" summary.  
No rolling or scoring yet — just state detection and game initialisation.

### What it shows

**No saved game →** Setup form:
- Dice mode toggle: `Virtual 🎲` / `Physical 🎯`
- Player count selector: `2` `3` `4`
- Name text inputs (one per player, defaults to "Player N")
- `Start Game` button

**Saved game found →** Game-in-progress card:
- Player names listed
- Dice mode icon (🎲 or 🎯)
- Current round (e.g. "Round 3 / 13")
- `Continue` button
- `New Game` button (clears localStorage, returns to setup form)

### localStorage schema (v1 — minimal)

```json
{
  "version": 1,
  "diceMode": "Virtual",
  "phase": "Playing",
  "round": 3,
  "playerNames": ["Alice", "Bob"]
}
```

Full game state fields will be added in later components without breaking this schema.

---

## Component 2 — Dice Rolling

### Virtual mode
- `Roll Dice` / `Roll Again` button generates `rand(1..6)` for each non-held die
- Held state toggled by clicking a die face
- Rolls remaining counter (3 → 2 → 1 → 0)

### Physical mode
- `Enter Roll` button opens an input panel
- Each non-held die shows a row of 6 pip buttons ⚀–⚅; tap the face you rolled
- Held dice frozen at current value
- `Confirm Roll` activates once all non-held dice have a value; decrements rollsLeft
- Hold/unhold works identically between rolls

---

## Component 3 — Scorecard + Live Preview

- All 13 categories rendered in a table (one column per player)
- Active player's column highlighted
- **Open cells** show the preview score for the current dice (clickable to commit)
- **Filled cells** show the committed score (greyed, not clickable)
- Upper section subtotal + bonus tracker (e.g. "42 / 63")
- Yahtzee bonus row

---

## Component 4 — Full Turn Loop

Connects C2 and C3 into a full game turn:
1. At turn start: rollsLeft = 3, held = all false
2. Player rolls (or enters) dice up to 3 times with optional holds between
3. Player clicks a preview cell → score committed, advance to next player
4. After all 13 rounds → transition to Game Over phase
5. Full GameState saved to localStorage on every action

Yahtzee bonus and joker rules applied at score-commit time.

---

## Component 5 — Game Over

- Final leaderboard table: rank, upper total, +35 bonus, lower total, grand total
- Full scorecard recap for every player (all 13 category scores)
- `Play Again` — same players + dice mode, fresh scores, skip setup
- `New Game` — clear localStorage, back to setup form
- Winner highlighted

---

## Scoring Reference

| Category | Score |
|----------|-------|
| Ones–Sixes | sum of matching faces |
| Upper bonus | +35 when upper total ≥ 63 |
| Three of a Kind | sum of all dice (if ≥ 3 same) |
| Four of a Kind | sum of all dice (if ≥ 4 same) |
| Full House | 25 |
| Small Straight (4 seq.) | 30 |
| Large Straight (5 seq.) | 40 |
| Yahtzee | 50 |
| Yahtzee bonus | +100 per extra Yahtzee (joker rules apply) |
| Chance | sum of all dice |

---

## Build & Deploy

```bash
# Install Karax (first time)
nimble install karax

# Compile
nim js -d:release \
  --path:/root/.nimble/pkgs/karax-1.5.0 \
  -o:app.js src/yahtzee.nim

# Push compiled output
git add app.js && git commit -m "..." && git push
```

GitHub Pages: Settings → Pages → Deploy from branch → **main / (root)**  
`.nojekyll` file disables Jekyll so `app.js` is served as a plain file.
