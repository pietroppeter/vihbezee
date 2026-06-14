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
DECISIONS.md      — architecture decision records (ADRs)
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

- Feature branches → PR → merge to `main` → GitHub Pages auto-deploys
- Pages must be enabled once: Settings → Pages → main / (root)
- All asset paths in `index.html` are relative (`./app.js`, `./style.css`) — required for the project-page URL `https://pietroppeter.github.io/vihbezee/` (see ADR-002)

## Architecture notes

- Everything lives in `src/yahtzee.nim` until it's genuinely unwieldy (see ADR-005)
- State is a single `GameState` object; functions mutate it then call `redraw()`
- localStorage key: `"yahtzee"`. Schema has a `version` field for safe future migrations (see ADR-006)
- Karax entry point: `setRenderer createDom` at the bottom of the file

## Known Nim/Karax gotcha — closure capture in loops (ADR-004)

**Do not** write inline closures over loop variables inside `buildHtml`. Use a proc factory instead:

```nim
# Wrong — all handlers share the last value of i after macro expansion
for i in 0..<n:
  button(onclick = proc(ev, t) = doSomething(i)): ...

# Correct — each call creates a fresh captured copy
proc makeHandler(i: int): proc(ev: Event, t: VNode) =
  result = proc(ev: Event, t: VNode) = doSomething(i)

for i in 0..<n:
  button(onclick = makeHandler(i)): ...
```

## Build plan

See `PLAN.md` for the full component breakdown and current status.
See `DECISIONS.md` for architecture decisions.
Current target: **Component 2 — Dice Rolling**.
