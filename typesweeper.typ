#import "@preview/suiji:0.5.0": *

#let cell-size = 1cm
#let palette = (
  grass: rgb("#3ab46b"),
  grass-back: rgb("#65df96"),
  reveal: rgb("#ffe1b7"),
  mine: rgb("#551970"),
  flag: rgb("#ee3535"),
  flag-back: rgb("#ff8181"),
  win: rgb("#ffbd60"),
  lose: rgb("#c08dd8"),
)



#let init-state(seed, size) = {
  let rng = gen-rng-f(seed)
  let (rows, cols) = size
  let num-mines = int(rows * cols * 0.15)

  let mines = range(0, rows * cols - num-mines).map(_ => false) + range(num-mines).map(_ => true)
  (rng, mines) = shuffle-f(rng, mines)
  let marks = range(0, rows * cols).map(_ => "hidden") // "hidden" | "reveal" | "flag"
  (
    picker-pos: (0, 0),
    size: size,
    mines: mines,
    marks: marks,
    screen: "play", // "play" | "lose" | "win"
    seed: seed,
    first-reveal: false,
  )
}


#let surrounding-pos(x, y, size, wrap-around: false) = {
  let (rows, cols) = size
  let arr = {
    for dx in range(-1, 2) {
      for dy in range(-1, 2) {
        if dx == 0 and dy == 0 {
          continue
        }
        let (cx, cy) = (x + dx, y + dy)
        if wrap-around {
          (cx, cy) = (calc.rem(cx + cols, cols), calc.rem(cy + rows, rows))
        } else {
          if cx < 0 or cx >= cols {
            continue
          }
          if cy < 0 or cy >= rows {
            continue
          }
        }
        (cx, cy)
      }
    }
  }
  arr.chunks(2)
}

#let count-mines(x, y, state, include-self: false, wrap-around: false) = {
  let (rows, cols) = state.size
  let res = 0
  for (cx, cy) in surrounding-pos(x, y, state.size, wrap-around: wrap-around) {
    if state.mines.at(cy * cols + cx) {
      res += 1
    }
  }
  if include-self and state.mines.at(y * cols + x) {
    res += 1
  }
  res
}

#let get-num-remaining-flags(state) = {
  let num-mines = state.mines.filter(x => x).len()
  let num-placed-flags = state.marks.filter(x => x == "flag").len()
  num-mines - num-placed-flags
}



#let flood-reveal(x, y, state) = {
  let (rows, cols) = state.size
  let i = y * cols + x

  if state.marks.at(i) == "reveal" {
    return state
  }

  _ = state.marks.remove(i)
  state.marks.insert(i, "reveal")

  let count = count-mines(x, y, state)
  if count == 0 {
    for (cx, cy) in surrounding-pos(x, y, state.size) {
      state = flood-reveal(cx, cy, state)
    }
  }

  state
}

#let ensure-good-start(x, y, state) = {
  let (rows, cols) = state.size
  let current-index = y * cols + x
  let positions = range(0, rows).map(y => range(0, cols).map(x => (x, y))).flatten().chunks(2)
  // try to find positions naturally close to x, y
  positions = positions.sorted(key: ((px, py)) => calc.abs(px - x) + calc.abs(py - y))
  let good-position = positions.find(((x, y)) => count-mines(x, y, state, include-self: true, wrap-around: true) == 0)
  if good-position == none {
    let good-index = state.mines.enumerate().find((_, x) => not x).at(0)
    good-position = (calc.rem(good-index, cols), calc.div-euclid(good-index, cols))
  }
  let (gx, gy) = good-position
  let dx = x - gx
  let dy = y - gy

  // shift mines to align good-index to x, y
  let y-swap-start = (rows - calc.rem(dy + rows, rows)) * cols
  state.mines = state.mines.slice(y-swap-start) + state.mines.slice(0, y-swap-start)

  let x-swap-start = cols - calc.rem(dx + cols, cols)
  state.mines = state
    .mines
    .chunks(cols)
    .map(chunk => {
      chunk.slice(x-swap-start) + chunk.slice(0, x-swap-start)
    })
    .flatten()

  state
}

#let update-state(state, input) = {
  let (rows, cols) = state.size
  let (x, y) = state.picker-pos

  if state.screen != "play" {
    return state
  }

  if input == "w" {
    y -= 1
  } else if input == "s" {
    y += 1
  } else if input == "a" {
    x -= 1
  } else if input == "d" {
    x += 1
  }
  x = calc.clamp(x, 0, cols - 1)
  y = calc.clamp(y, 0, rows - 1)
  state.picker-pos = (x, y)


  let i = y * cols + x
  if input == "x" {
    if state.marks.at(i) == "hidden" {
      if not state.first-reveal {
        state = ensure-good-start(x, y, state)
        state.first-reveal = true
      }
      if state.mines.at(i) {
        state.screen = "lose"
      } else {
        state = flood-reveal(x, y, state)
      }
    }
  }

  if input == "f" {
    if state.marks.at(i) == "hidden" {
      if get-num-remaining-flags(state) > 0 {
        _ = state.marks.remove(i)
        state.marks.insert(i, "flag")
      }
    } else if state.marks.at(i) == "flag" {
      _ = state.marks.remove(i)
      state.marks.insert(i, "hidden")
    }
  }

  let num-reveal = state.marks.filter(x => x == "reveal").len()
  if num-reveal == rows * cols - state.mines.filter(x => x).len() {
    state.screen = "win"
  }

  state
}

#let render-cell(x, y, state) = {
  let (rows, cols) = state.size
  let i = y * cols + x

  let mark = state.marks.at(i)

  let color = if mark == "hidden" or mark == "flag" {
    palette.grass
  } else {
    palette.reveal
  }
  let txt = if mark == "reveal" {
    let count = count-mines(x, y, state)
    if count > 0 {
      [#count]
    } else {
      none
    }
  } else {
    none
  }

  let show-mine = if state.screen == "play" {
    false
  } else {
    state.mines.at(i)
  }

  if x == state.picker-pos.at(0) and y == state.picker-pos.at(1) {
    color = color.lighten(40%)
  }


  box(fill: color, width: cell-size, height: cell-size, stroke: 1pt)[
    #set align(center + horizon)
    #if show-mine {
      place(
        dx: cell-size * 0.25,
        dy: cell-size * 0.25,
        circle(radius: cell-size * 0.25, fill: palette.mine, stroke: 1pt),
      )
    }
    #if mark == "flag" {
      let a = cell-size * 0.5
      let h = calc.sqrt(3) / 2 * a
      place(
        dx: (cell-size - h) / 2 + h * 1 / 6,
        dy: (cell-size - a) / 2,
        polygon(
          fill: palette.flag,
          (0cm, 0cm),
          (0cm, a),
          (h, a / 2),
          stroke: 1pt,
        ),
      )
    }
    #txt

  ]
}

#let ui-element(fill, content) = box(height: cell-size, stroke: 1pt, inset: 0.2cm, fill: fill)[
  #set align(center + horizon)
  #content
]

#let key(fill, content) = box(stroke: 1pt, fill: fill, inset: (x: 0.2cm), outset: (y: 0.2cm))[#content]

#let render(state) = {
  let (rows, cols) = state.size
  let cells = range(0, rows).map(y => range(0, cols).map(x => render-cell(x, y, state))).flatten()


  let num-remaining-flags = get-num-remaining-flags(state)

  [
    #set text(size: 16pt)
    #set align(center)
    = typesweeper

    #box[
      #set align(left)
      1. open `play.typ` in a typst editor with live preview
      2. put your caret between the quotes in  ```typst #typesweeper("")```
    ]

    #key(palette.grass-back)[w] #key(palette.grass-back)[a] #key(palette.grass-back)[s] #key(palette.grass-back)[d] to move, #key(palette.reveal)[x] to reveal, #key(palette.flag-back)[f] to flag



    #let screen-element = if state.screen == "play" {
      ui-element(palette.reveal, [playing])
    } else if state.screen == "win" {
      ui-element(palette.win, [you win!])
    } else if state.screen == "lose" {
      ui-element(palette.lose, [you lose])
    }


    #box[
      #set align(left)
      #let topbar = stack(
        dir: ltr,
        ui-element(palette.flag-back, [#num-remaining-flags flags]),
        screen-element,
      )
      #stack(topbar, grid(rows: rows, columns: cols, ..cells))
    ]
  ]
}



/// Play a game of minesweeper in a live preview Typst editor
///
/// - seed (number): random seed to initialize the game state.
/// - size ((int, int)): size of grid in rows and columns.
/// - inputs (string): string of input characters.
/// ->
#let typesweeper(seed: 1, size: (10, 15), inputs) = {
  let state = init-state(seed, size)
  for i in range(0, inputs.len()) {
    let input = inputs.at(i)
    state = update-state(state, input)
  }
  render(state)
}


