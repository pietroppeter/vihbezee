# CLAUDE.md — vihbezee

## What this is

Client-only Yahtzee SPA. Nim source compiled to JavaScript with Karax (vdom framework), served as static files on GitHub Pages. No backend, no build server.

## Stack

- **Language:** Nim 1.6+ (compiled with `nim js`)
- **UI framework:** Karax (virtual DOM, SPA)
- **Persistence:** browser `localStorage` (JSON)
- **Hosting:** GitHub Pages (static, root of `main` branch)

## Key files

```
src/yahtzee.nim   — all game logic + Karax UI (single source file)
index.html        — mounts Karax app at <div id="ROOT">
style.css         — styling
app.js            — compiled JS bundle (committed, don't hand-edit)
yahtzee.nimble    — declares karax dependency + build task
PLAN.md           — component-by-component build plan (keep updated)
.nojekyll         — tells GitHub Pages to skip Jekyll
```

## Build

```bash
nim js -d:release \
  --path:/root/.nimble/pkgs/karax-1.5.0 \
  -o:app.js src/yahtzee.nim
```

Always compile before committing. Commit `app.js` as part of every meaningful change.

## Branch & deploy

- Development branch: `claude/yahtzee-nim-karax-ulxgir`
- Merges to `main` → triggers GitHub Pages (must be enabled once: Settings → Pages → main / root)
- All asset paths in `index.html` are relative (`./app.js`, `./style.css`) — required for the project-page URL `https://pietroppeter.github.io/vihbezee/`

## Architecture notes

- Everything lives in `src/yahtzee.nim`. Keep it that way until it gets genuinely unwieldy.
- State is a single `GameState` object; functions mutate it then call `redraw()`.
- localStorage key: `"yahtzee"`. Schema versioned with a `version` field so future migrations are possible.
- Karax entry point: `setRenderer createDom` at the bottom of the file.

## Build plan

See `PLAN.md` for the full component breakdown and current status.
Current target: **Component 1 — Setup / Home Screen**.
