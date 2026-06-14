# Architecture Decision Records

Decisions made during the build of vihbezee, in the order they were made.

---

## ADR-001 — Nim + Karax as the stack

**Status:** accepted

**Context:** The goal was a client-only app with no backend, deployed to GitHub Pages, coded in Nim (the language was the point of the exercise).

**Decision:** Use Nim compiled to JavaScript (`nim js`) with Karax as the virtual-DOM SPA framework. Karax is the most established Nim frontend library and provides a React-like render loop without requiring any external build tooling.

**Consequences:**
- No npm, no bundler, no Node — just `nim js` producing a single `app.js`
- Karax is a small community project; documentation is sparse; read the source when stuck
- The compiled `app.js` is committed to the repo so GitHub Pages can serve it as a plain static file

---

## ADR-002 — All asset paths in index.html are relative

**Status:** accepted

**Context:** GitHub Pages hosts project pages (as opposed to user pages) under a subdirectory: `https://<user>.github.io/<repo>/`. Absolute paths like `/app.js` would resolve to the root of the domain, not the repo subdirectory, and return 404s.

**Decision:** Use `./app.js` and `./style.css` in `index.html`. Add a `.nojekyll` file at the repo root so GitHub Pages serves files as-is without Jekyll processing.

**Consequences:** Works correctly as a project page. Must remember this when adding any new static asset reference.

---

## ADR-003 — Physical dice is the default mode

**Status:** accepted

**Context:** The app supports two dice modes. The use-case that prompted the Physical mode was the primary intended use (playing with real dice, using the app only for scoring). Virtual mode is a bonus.

**Decision:** Physical dice is the first option in the toggle and the pre-selected default on a fresh setup.

**Consequences:** Users who want virtual dice must explicitly tap the toggle. Acceptable trade-off for the intended audience.

---

## ADR-004 — Proc factories for event handlers in Karax loops

**Status:** accepted

**Context:** Discovered during Component 1 testing. Multiple bugs (count buttons all behaving as the last button, all name inputs writing to the same slot) were traced to closure capture failure.

In Nim 1.6's JS backend, `let nn = n` inside a `for` loop is supposed to capture `n` by value per iteration. However, when the loop body is inside a Karax `buildHtml` macro block, macro expansion transforms the code in a way that breaks this capture — all closures end up sharing the same reference.

**Decision:** Never write inline closures over loop variables inside `buildHtml`. Instead, define a named proc outside the render function that takes the loop variable as a parameter and returns the handler:

```nim
proc onCountClick(n: int): proc(ev: Event, t: VNode) =
  result = proc(ev: Event, t: VNode) = form.numPlayers = n; redraw()
```

Pass the factory result at the call site: `onclick = onCountClick(n)`.

Each proc call creates a fresh stack frame, so `n` is always correctly isolated.

**Consequences:**
- Slightly more boilerplate (one factory proc per handler type)
- Completely reliable across Nim versions and macro contexts
- Apply this pattern universally for any handler generated inside a loop

---

## ADR-005 — Single source file until genuinely unwieldy

**Status:** accepted

**Context:** Karax SPA logic can be split across multiple `.nim` files and imported. At the current scale (~200 lines for C1) there is no benefit to splitting.

**Decision:** Keep everything in `src/yahtzee.nim`. Revisit if the file exceeds ~600 lines or distinct concerns (game logic vs UI vs persistence) become hard to navigate independently.

**Consequences:** Simple build command, easy to read top-to-bottom. No import graph to maintain.

---

## ADR-006 — localStorage schema versioned from day one

**Status:** accepted

**Context:** The app persists game state in `localStorage["yahtzee"]`. As components are added the schema will grow. We need a safe migration path so a user's persisted game from an older version doesn't crash a newer one.

**Decision:** Include a `"version": 1` field in every saved JSON blob. The `loadSaved()` function already uses defensive parsing with per-field defaults; when a breaking change is needed, increment the version and add a migration branch.

**Consequences:** Future-proofs persistence at minimal cost. Current schema is minimal (v1); full state added in C4.
