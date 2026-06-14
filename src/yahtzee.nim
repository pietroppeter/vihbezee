import karax / [karax, karaxdsl, vdom, kdom, kajax]
import std / [strutils, sequtils, algorithm, random, strformat]

# ── Types ──────────────────────────────────────────────────────────────────────

type
  Category = enum
    Ones, Twos, Threes, Fours, Fives, Sixes,
    ThreeOfAKind, FourOfAKind, FullHouse,
    SmallStraight, LargeStraight, Yahtzee, Chance

  ScoreCard = array[Category, int]  # -1 = unused, >=0 = scored

  Player = object
    name: string
    scores: ScoreCard
    yahtzeeBonus: int   # extra +100 per bonus Yahtzee

  Phase = enum
    Setup, Playing, GameOver

  GameState = object
    phase: Phase
    numPlayers: int
    playerNames: array[4, string]
    players: seq[Player]
    currentPlayer: int
    round: int          # 1..13
    dice: array[5, int]
    held: array[5, bool]
    rollsLeft: int

# ── Constants ──────────────────────────────────────────────────────────────────

const
  CategoryNames: array[Category, string] = [
    "Ones", "Twos", "Threes", "Fours", "Fives", "Sixes",
    "3 of a Kind", "4 of a Kind", "Full House",
    "Sm. Straight", "Lg. Straight", "Yahtzee", "Chance"
  ]
  Upper = {Ones .. Sixes}
  UpperBonus = 35
  UpperBonusThreshold = 63
  YahtzeeScore = 50
  Unset = -1

# ── Global State ───────────────────────────────────────────────────────────────

var gs = GameState(
  phase: Setup,
  numPlayers: 2,
  playerNames: ["Player 1", "Player 2", "Player 3", "Player 4"],
  rollsLeft: 3,
  round: 1
)

# ── Score Calculation ───────────────────────────────────────────────────────────

proc counts(dice: array[5, int]): array[7, int] =
  for d in dice: result[d] += 1

proc scoreFor(cat: Category, dice: array[5, int]): int =
  let c = counts(dice)
  case cat
  of Ones:   result = c[1] * 1
  of Twos:   result = c[2] * 2
  of Threes: result = c[3] * 3
  of Fours:  result = c[4] * 4
  of Fives:  result = c[5] * 5
  of Sixes:  result = c[6] * 6
  of ThreeOfAKind:
    if c[1..6].anyIt(it >= 3): result = dice.foldl(a + b, 0)
  of FourOfAKind:
    if c[1..6].anyIt(it >= 4): result = dice.foldl(a + b, 0)
  of FullHouse:
    let has3 = c[1..6].anyIt(it == 3)
    let has2 = c[1..6].anyIt(it == 2)
    if has3 and has2: result = 25
  of SmallStraight:
    let s = sorted(deduplicate(dice.toSeq))
    var run = 1; var best = 1
    for i in 1 ..< s.len:
      if s[i] == s[i-1] + 1: inc run
      else: run = 1
      if run > best: best = run
    if best >= 4: result = 30
  of LargeStraight:
    let s = sorted(deduplicate(dice.toSeq))
    if s.len == 5 and s[4] - s[0] == 4: result = 40
  of Yahtzee:
    if c[1..6].anyIt(it == 5): result = YahtzeeScore
  of Chance:
    result = dice.foldl(a + b, 0)

proc jokerScore(cat: Category, dice: array[5, int]): int =
  # Joker rules: bonus Yahtzee, score in lower section if upper is filled
  case cat
  of FullHouse:    result = 25
  of SmallStraight: result = 30
  of LargeStraight: result = 40
  else: result = scoreFor(cat, dice)

proc upperTotal(p: Player): int =
  for cat in Ones .. Sixes:
    if p.scores[cat] != Unset: result += p.scores[cat]

proc upperBonus(p: Player): int =
  if upperTotal(p) >= UpperBonusThreshold: UpperBonus else: 0

proc lowerTotal(p: Player): int =
  for cat in ThreeOfAKind .. Chance:
    if p.scores[cat] != Unset: result += p.scores[cat]
  result += p.yahtzeeBonus

proc grandTotal(p: Player): int =
  upperTotal(p) + upperBonus(p) + lowerTotal(p)

proc isYahtzee(dice: array[5, int]): bool =
  scoreFor(Yahtzee, dice) == YahtzeeScore

proc previewScore(cat: Category, dice: array[5, int], p: Player): int =
  # Bonus Yahtzee joker rules
  if isYahtzee(dice) and p.scores[Yahtzee] == YahtzeeScore:
    # Joker: must fill upper matching face first
    let face = dice[0]
    let matchCat = Category(face - 1)  # Ones=0, Twos=1 …
    if p.scores[matchCat] == Unset:
      if cat == matchCat: return scoreFor(cat, dice)
      else: return 0
    # Upper slot filled – free to use joker in any open lower slot
    if cat in Upper: return scoreFor(cat, dice)
    return jokerScore(cat, dice)
  scoreFor(cat, dice)

# ── Actions ────────────────────────────────────────────────────────────────────

proc rollDice() =
  for i in 0 ..< 5:
    if not gs.held[i]:
      gs.dice[i] = rand(1..6)
  dec gs.rollsLeft

proc resetTurn() =
  gs.held = [false, false, false, false, false]
  gs.rollsLeft = 3

proc scoreCategory(cat: Category) =
  let p = addr gs.players[gs.currentPlayer]
  if p.scores[cat] != Unset: return

  let isBonus = isYahtzee(gs.dice) and p.scores[Yahtzee] == YahtzeeScore
  if isBonus: p.yahtzeeBonus += 100

  p.scores[cat] = previewScore(cat, gs.dice, gs.players[gs.currentPlayer])

  # Advance turn
  gs.currentPlayer = (gs.currentPlayer + 1) mod gs.players.len
  if gs.currentPlayer == 0: inc gs.round
  if gs.round > 13:
    gs.phase = GameOver
  else:
    resetTurn()

proc startGame() =
  gs.players = @[]
  for i in 0 ..< gs.numPlayers:
    var p = Player(name: gs.playerNames[i])
    for cat in Category: p.scores[cat] = Unset
    gs.players.add(p)
  gs.currentPlayer = 0
  gs.round = 1
  gs.phase = Playing
  randomize()
  resetTurn()

proc restartGame() =
  gs = GameState(
    phase: Setup,
    numPlayers: 2,
    playerNames: gs.playerNames,
    rollsLeft: 3,
    round: 1
  )

# ── UI helpers ─────────────────────────────────────────────────────────────────

proc dieFace(n: int): string =
  case n
  of 1: "⚀"
  of 2: "⚁"
  of 3: "⚂"
  of 4: "⚃"
  of 5: "⚄"
  of 6: "⚅"
  else: "?"

# ── Setup Screen ───────────────────────────────────────────────────────────────

proc renderSetup(): VNode =
  buildHtml(tdiv(class = "screen setup-screen")):
    h1: text "Yahtzee"
    p(class = "subtitle"): text "Hotseat · 2–4 players"
    tdiv(class = "player-count"):
      text "Number of players: "
      for n in 2..4:
        let cn = if gs.numPlayers == n: "cnt-btn active" else: "cnt-btn"
        let nn = n
        button(class = cn, onclick = proc(ev: Event, t: VNode) =
          gs.numPlayers = nn; redraw()):
          text $n
    tdiv(class = "name-inputs"):
      for i in 0 ..< gs.numPlayers:
        let idx = i
        tdiv(class = "name-row"):
          label: text "Player " & $(i+1) & ":"
          input(`type` = "text",
                value = gs.playerNames[idx],
                placeholder = "Player " & $(idx+1),
                oninput = proc(ev: Event, t: VNode) =
                  gs.playerNames[idx] = $ev.target.InputElement.value
                  redraw())
    button(class = "btn-primary start-btn", onclick = proc(ev: Event, t: VNode) =
      startGame(); redraw()):
      text "Start Game"

# ── Scorecard ──────────────────────────────────────────────────────────────────

proc renderScorecard(): VNode =
  let cp = gs.currentPlayer
  let canScore = gs.rollsLeft < 3  # at least one roll done
  buildHtml(tdiv(class = "scorecard-area")):
    tdiv(class = "scorecard-wrap"):
      table(class = "scorecard"):
        thead:
          tr:
            th: text "Category"
            for i, p in gs.players:
              let cls = if i == cp: "th-active" else: ""
              th(class = cls): text p.name
        tbody:
          # Upper section
          tr(class = "section-header"):
            td(colspan = $(gs.players.len + 1)): text "Upper Section"
          for cat in Ones .. Sixes:
            tr:
              td: text CategoryNames[cat]
              for i, p in gs.players:
                let score = p.scores[cat]
                if score != Unset:
                  td(class = "scored"): text $score
                elif i == cp and canScore:
                  let preview = previewScore(cat, gs.dice, p)
                  let c = cat
                  td(class = "preview",
                     onclick = proc(ev: Event, t: VNode) =
                       scoreCategory(c); redraw()):
                    text $preview
                else:
                  td: text "–"
          # Upper bonus row
          tr(class = "bonus-row"):
            td: text "Bonus (≥63 → +35)"
            for p in gs.players:
              let u = upperTotal(p)
              let bonus = upperBonus(p)
              if bonus > 0:
                td(class = "scored"): text "+35"
              else:
                td: text $u & "/63"
          # Lower section
          tr(class = "section-header"):
            td(colspan = $(gs.players.len + 1)): text "Lower Section"
          for cat in ThreeOfAKind .. Chance:
            tr:
              td: text CategoryNames[cat]
              for i, p in gs.players:
                let score = p.scores[cat]
                if score != Unset:
                  td(class = "scored"): text $score
                elif i == cp and canScore:
                  let preview = previewScore(cat, gs.dice, p)
                  let c = cat
                  td(class = "preview",
                     onclick = proc(ev: Event, t: VNode) =
                       scoreCategory(c); redraw()):
                    text $preview
                else:
                  td: text "–"
          # Yahtzee bonus row
          tr(class = "bonus-row"):
            td: text "Yahtzee Bonus"
            for p in gs.players:
              td: text if p.yahtzeeBonus > 0: "+" & $p.yahtzeeBonus else: "–"
          # Totals
          tr(class = "total-row"):
            td: text "Grand Total"
            for p in gs.players:
              td(class = "total"): text $grandTotal(p)

# ── Dice Area ──────────────────────────────────────────────────────────────────

proc renderDice(): VNode =
  buildHtml(tdiv(class = "dice-area")):
    tdiv(class = "dice-row"):
      for i in 0 ..< 5:
        let idx = i
        let cls = if gs.held[idx]: "die held" else: "die"
        tdiv(class = cls,
             onclick = proc(ev: Event, t: VNode) =
               if gs.rollsLeft < 3:
                 gs.held[idx] = not gs.held[idx]; redraw()):
          text dieFace(gs.dice[idx])
          if gs.held[idx]:
            span(class = "held-tag"): text "HELD"

# ── Playing Screen ─────────────────────────────────────────────────────────────

proc renderPlaying(): VNode =
  let cp = gs.currentPlayer
  let p = gs.players[cp]
  buildHtml(tdiv(class = "screen play-screen")):
    tdiv(class = "play-header"):
      span(class = "turn-info"):
        text fmt"Round {gs.round}/13 — {p.name}'s turn"
      span(class = "rolls-left"):
        text fmt"Rolls left: {gs.rollsLeft}"
    renderDice()
    tdiv(class = "roll-area"):
      if gs.rollsLeft > 0:
        button(class = "btn-primary roll-btn",
               onclick = proc(ev: Event, t: VNode) =
                 rollDice(); redraw()):
          text if gs.rollsLeft == 3: "Roll Dice" else: "Roll Again"
      else:
        p(class = "no-rolls"): text "No rolls left – pick a category"
      if gs.rollsLeft < 3:
        p(class = "hint"): text "Click a highlighted cell to score"
    renderScorecard()

# ── Game Over Screen ───────────────────────────────────────────────────────────

proc renderGameOver(): VNode =
  var ranked = gs.players
  ranked.sort(proc(a, b: Player): int = cmp(grandTotal(b), grandTotal(a)))
  buildHtml(tdiv(class = "screen gameover-screen")):
    h1: text "Game Over!"
    h2(class = "winner"): text ranked[0].name & " wins!"
    table(class = "final-table"):
      thead:
        tr:
          th: text "Rank"
          th: text "Player"
          th: text "Upper"
          th: text "Bonus"
          th: text "Lower"
          th: text "Total"
      tbody:
        for i, p in ranked:
          tr:
            td: text $(i+1)
            td: text p.name
            td: text $upperTotal(p)
            td: text $upperBonus(p)
            td: text $lowerTotal(p)
            td(class = "total"): text $grandTotal(p)
    button(class = "btn-primary",
           onclick = proc(ev: Event, t: VNode) =
             restartGame(); redraw()):
      text "Play Again"

# ── Root ───────────────────────────────────────────────────────────────────────

proc createDom(): VNode =
  buildHtml(tdiv):
    case gs.phase
    of Setup:    renderSetup()
    of Playing:  renderPlaying()
    of GameOver: renderGameOver()

setRenderer createDom
