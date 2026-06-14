# vihbezee

A vibe (mobile) coded Yahtzee client-only app (in Nim + Karax).

Live: https://pietroppeter.github.io/vihbezee/

## Stack

- **Nim** compiled to JavaScript via `nim js`
- **Karax** virtual-DOM SPA framework
- Fully client-side — no backend

## Rebuild

```bash
nimble install karax   # first time only
nim js -d:release --path:$HOME/.nimble/pkgs/karax-1.5.0 -o:app.js src/yahtzee.nim
```

Commit `app.js` and push to `main`.

## GitHub Pages

Settings → Pages → Deploy from branch → **main / (root)**

The `.nojekyll` file disables Jekyll so `app.js` is served correctly.

## Game

Hotseat, 2–4 players. Standard Yahtzee scoring with bonus, joker rules, and live score preview.
