//// The drawings that a browser with no saved library starts with: each one's
//// name and source.

pub const all = [
  #(
    "fan",
    "fn draw(shape_slider: Int) -> List(Path) {
  fan(30, Point(-200, -200))
}

fn fan(n: Int, start: Point) -> List(Path) {
  case n > 0 {
    True -> [Path(Line(start, Point(n * 10, 200)), 0, 30, 3), ..fan(n - 1, start)]
    False -> []
  }
}
",
  ),
  #(
    "square_spiral",
    "fn draw(shape_slider: Int) -> List(Path) {
  let turns = 20 + shape_slider / 4
  spiral(Point(0, 0), Point(1, 0), 0, turns)
}

fn spiral(p: Point, d: Point, i: Int, n: Int) -> List(Path) {
  case i == n {
    True -> []
    False -> {
      let len = { i / 2 + 1 } * 24
      let q = Point(p.x + d.x * len, p.y + d.y * len)
      [
        Path(Line(p, q), i * 3, i * 3 + 3, 3),
        ..spiral(q, Point(0 - d.y, d.x), i + 1, n)
      ]
    }
  }
}
",
  ),
  #(
    "string_art",
    "fn draw(shape_slider: Int) -> List(Path) {
  let n = 8 + shape_slider / 10
  list.flatten([
    quadrant(1, 1, n, 0),
    quadrant(-1, 1, n, n + 1),
    quadrant(-1, -1, n, { n + 1 } * 2),
    quadrant(1, -1, n, { n + 1 } * 3),
  ])
}

fn quadrant(sx: Int, sy: Int, n: Int, base: Int) -> List(Path) {
  strings(0, sx, sy, n, base)
}

fn strings(i: Int, sx: Int, sy: Int, n: Int, base: Int) -> List(Path) {
  case i > n {
    True -> []
    False -> {
      let a = Point(sx * 420 * i / n, 0)
      let b = Point(0, sy * 420 * { n - i } / n)
      let t = { base + i } * 2
      [Path(Line(a, b), t, t + 8, 2), ..strings(i + 1, sx, sy, n, base)]
    }
  }
}
",
  ),
  #(
    "tree",
    "fn draw(shape_slider: Int) -> List(Path) {
  let depth = 4 + shape_slider / 20
  branch(Point(0, 420), Point(0, -220), 0, depth)
}

fn branch(p: Point, d: Point, level: Int, depth: Int) -> List(Path) {
  case level == depth {
    True -> []
    False -> {
      let q = Point(p.x + d.x, p.y + d.y)
      let left = Point({ d.x - d.y } / 2, { d.y + d.x } / 2)
      let right = Point({ d.x + d.y } / 2, { d.y - d.x } / 2)
      [
        Path(Line(p, q), level * 4, level * 4 + 4, depth - level),
        ..list.append(
          branch(q, left, level + 1, depth),
          branch(q, right, level + 1, depth),
        )
      ]
    }
  }
}
",
  ),
  #(
    "spirograph",
    "fn draw(shape_slider: Int) -> List(Path) {
  rings(3 + shape_slider / 10, 0, shape_slider * 3)
}

fn rings(n: Int, i: Int, hue: Int) -> List(Path) {
  case i == n {
    True -> []
    False -> {
      let angle = i * 360 / n
      let center = Point(150 * cos_like(angle), 150 * sin_like(angle))
      [
        Path(Colored(Circle(center, 120), hue + i * 25), i * 3, i * 3 + 20, 3),
        ..rings(n, i + 1, hue)
      ]
    }
  }
}

fn cos_like(angle: Int) -> Int {
  // A triangle wave from 1 to -1 and back, close enough to cosine for a drawing.
  case angle < 180 {
    True -> 1 - angle / 90
    False -> angle / 90 - 3
  }
}

fn sin_like(angle: Int) -> Int {
  cos_like({ angle + 270 } % 360)
}
",
  ),
  #(
    "colour_wheel",
    "fn draw(shape_slider: Int) -> List(Path) {
  wheel(0, 12, 3 + shape_slider / 12)
}

fn wheel(i: Int, n: Int, sides: Int) -> List(Path) {
  case i == n {
    True -> []
    False -> [
      Path(
        Colored(Polygon(Point(0, 0), 60 + i * 30, sides), i * 360 / n),
        i * 4,
        i * 4 + 20,
        3,
      ),
      ..wheel(i + 1, n, sides)
    ]
  }
}
",
  ),
]
