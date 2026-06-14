import karax / [karax, karaxdsl, vdom, kdom]
import std / [json, options]

# ── Types ──────────────────────────────────────────────────────────────────────

type
  DiceMode = enum Virtual, Physical
  Phase    = enum Setup, Playing, GameOver

  # Minimal saved-state schema (v1). Extended in later components.
  SavedGame = object
    version:     int
    phase:       Phase
    round:       int
    diceMode:    DiceMode
    playerNames: seq[string]

  # Local UI state (not persisted)
  SetupForm = object
    numPlayers: int
    names:      array[4, string]
    diceMode:   DiceMode

var
  savedGame: Option[SavedGame]  # Some(g) if localStorage has a valid game
  form: SetupForm               # setup form state
  showConfirmNew: bool          # confirmation dialog before wiping in-progress game

# ── localStorage helpers ───────────────────────────────────────────────────────

const StorageKey = "yahtzee"

proc loadSaved(): Option[SavedGame] =
  let raw = window.localStorage.getItem(StorageKey)
  if raw.isNil or $raw == "": return none(SavedGame)
  try:
    let j = parseJson($raw)
    if j.kind != JObject: return none(SavedGame)
    var g: SavedGame
    g.version = j{"version"}.getInt(0)
    g.round   = j{"round"}.getInt(1)
    let phaseStr = j{"phase"}.getStr("Setup")
    g.phase = case phaseStr
      of "Playing":  Playing
      of "GameOver": GameOver
      else:          Setup
    let modeStr = j{"diceMode"}.getStr("Virtual")
    g.diceMode = if modeStr == "Physical": Physical else: Virtual
    if j{"playerNames"}.kind == JArray:
      for n in j["playerNames"]:
        g.playerNames.add(n.getStr(""))
    if g.playerNames.len < 2 or g.phase == Setup:
      return none(SavedGame)
    return some(g)
  except:
    return none(SavedGame)

proc clearSaved() =
  window.localStorage.removeItem(StorageKey)

proc savePlaceholder(f: SetupForm) =
  # Will be replaced with full state save in later components.
  # For now, write just enough to demonstrate resume detection.
  let j = %* {
    "version":     1,
    "phase":       "Playing",
    "round":       1,
    "diceMode":    (if f.diceMode == Physical: "Physical" else: "Virtual"),
    "playerNames": f.names[0 ..< f.numPlayers]
  }
  window.localStorage.setItem(StorageKey, cstring($j))

# ── Init ───────────────────────────────────────────────────────────────────────

proc initForm(d: DiceMode = Virtual; n: int = 2) =
  form = SetupForm(
    numPlayers: n,
    diceMode:   d,
    names:      ["Player 1", "Player 2", "Player 3", "Player 4"]
  )

proc init() =
  savedGame = loadSaved()
  if savedGame.isSome:
    let g = savedGame.get
    initForm(g.diceMode, g.playerNames.len)
    for i, name in g.playerNames:
      if i < 4: form.names[i] = name
  else:
    initForm()

init()

# ── Setup form ─────────────────────────────────────────────────────────────────

proc renderSetupForm(): VNode =
  buildHtml(tdiv(class = "screen setup-screen")):
    h1: text "Yahtzee"

    # Dice mode
    tdiv(class = "field-group"):
      p(class = "field-label"): text "Dice mode"
      tdiv(class = "mode-toggle"):
        button(
          class = (if form.diceMode == Virtual: "mode-btn active" else: "mode-btn"),
          onclick = proc(ev: Event, t: VNode) =
            form.diceMode = Virtual; redraw()):
          text "🎲 Virtual"
        button(
          class = (if form.diceMode == Physical: "mode-btn active" else: "mode-btn"),
          onclick = proc(ev: Event, t: VNode) =
            form.diceMode = Physical; redraw()):
          text "🎯 Physical"

    # Player count
    tdiv(class = "field-group"):
      p(class = "field-label"): text "Number of players"
      tdiv(class = "count-row"):
        for n in 2..4:
          let nn = n
          button(
            class = (if form.numPlayers == nn: "cnt-btn active" else: "cnt-btn"),
            onclick = proc(ev: Event, t: VNode) =
              form.numPlayers = nn; redraw()):
            text $n

    # Names
    tdiv(class = "field-group"):
      p(class = "field-label"): text "Player names"
      tdiv(class = "name-inputs"):
        for i in 0 ..< form.numPlayers:
          let idx = i
          tdiv(class = "name-row"):
            label: text $(i + 1) & ":"
            input(`type` = "text",
                  value = cstring(form.names[idx]),
                  placeholder = cstring("Player " & $(idx + 1)),
                  oninput = proc(ev: Event, t: VNode) =
                    form.names[idx] = $ev.target.InputElement.value
                    redraw())

    button(class = "btn-primary start-btn",
           onclick = proc(ev: Event, t: VNode) =
             savePlaceholder(form)
             savedGame = loadSaved()
             redraw()):
      text "Start Game"

# ── Game-in-progress card ──────────────────────────────────────────────────────

proc renderGameCard(g: SavedGame): VNode =
  let modeIcon = if g.diceMode == Physical: "🎯" else: "🎲"
  let modeLabel = if g.diceMode == Physical: "Physical dice" else: "Virtual dice"
  buildHtml(tdiv(class = "screen game-card-screen")):
    h1: text "Yahtzee"

    tdiv(class = "game-card"):
      p(class = "card-title"): text "Game in progress"
      p(class = "card-round"): text "Round " & $g.round & " / 13"
      p(class = "card-mode"): text modeIcon & "  " & modeLabel

      tdiv(class = "card-players"):
        for name in g.playerNames:
          tdiv(class = "card-player"): text name

      tdiv(class = "card-actions"):
        button(class = "btn-primary",
               onclick = proc(ev: Event, t: VNode) =
                 # Future: transition to Playing screen
                 redraw()):
          text "Continue"

        if showConfirmNew:
          tdiv(class = "confirm-box"):
            p: text "Start a new game? Current game will be lost."
            tdiv(class = "confirm-btns"):
              button(class = "btn-danger",
                     onclick = proc(ev: Event, t: VNode) =
                       clearSaved()
                       savedGame = none(SavedGame)
                       initForm()
                       showConfirmNew = false
                       redraw()):
                text "Yes, new game"
              button(class = "btn-secondary",
                     onclick = proc(ev: Event, t: VNode) =
                       showConfirmNew = false; redraw()):
                text "Cancel"
        else:
          button(class = "btn-secondary",
                 onclick = proc(ev: Event, t: VNode) =
                   showConfirmNew = true; redraw()):
            text "New Game"

# ── Root ───────────────────────────────────────────────────────────────────────

proc createDom(): VNode =
  buildHtml(tdiv):
    if savedGame.isSome:
      renderGameCard(savedGame.get)
    else:
      renderSetupForm()

setRenderer createDom
