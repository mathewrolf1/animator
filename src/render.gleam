//// Convert each shape into a list of points called a RenderPath.

import gleam/float
import gleam/int
import gleam/list
import shape.{
  type Path, type Point, type Shape, Arc, Circle, Colored, Line, Point, Polygon,
}

/// One path as canvas.mjs setDrawing consumes it (field by field): the
/// polyline, stroke colour/width, and the start and end times (in tenths of a second)
/// between which the reveal runs — so the renderer's clock needs no shape
/// knowledge.
pub type RenderPath {
  RenderPath(
    points: List(Point),
    thickness: Float,
    color: String,
    start: Float,
    end: Float,
  )
}

// ── The canvas (canvas.mjs) ───────────────────────────────────────────────────

/// Replace the drawing being animated in the page's
/// `<canvas id="animation-canvas">` element. If that element doesn't appear within
/// about 10 seconds, this logs an error to the browser console. This keeps the
/// current time, so a drawing that replaces a finished one appears complete. To
/// animate it from the start, also call reset_clock.
@external(javascript, "./canvas.mjs", "setDrawing")
pub fn set_drawing(paths: List(RenderPath)) -> Nil

/// Set the animation's speed, as a multiple of its normal speed: 1.0 is normal and
/// is where it starts, 0.0 pauses, and a negative rate plays it backward.
/// Time stops at the start of the drawing and when its last path finishes, so
/// playing a finished drawing again takes a call to reset_clock.
@external(javascript, "./canvas.mjs", "setSpeed")
pub fn set_speed(rate: Float) -> Nil

/// Jump the animation back to its start, where the canvas is empty.
@external(javascript, "./canvas.mjs", "resetClock")
pub fn reset_clock() -> Nil

@external(javascript, "./render_ffi.mjs", "sin")
fn sin(radians: Float) -> Float

@external(javascript, "./render_ffi.mjs", "cos")
fn cos(radians: Float) -> Float

const pi = 3.141592653589793

/// The path's outline as a polyline, drawn in `color` unless a Colored shape
/// picks its own.
pub fn render_path(path: Path, color: String) -> RenderPath {
  let #(points, color) = outline(path.shape, color)
  RenderPath(points, path.thickness, color, path.start, path.end)
}

fn outline(shape: Shape, color: String) -> #(List(Point), String) {
  case shape {
    Line(a, b) -> #([a, b], color)
    Circle(c, r) -> #(arc_points(c, r, 0.0, 360.0), color)
    Arc(c, r, from, to) -> #(arc_points(c, r, from, to), color)
    Polygon(c, r, sides) -> {
      let n = int.max(sides, 3)
      #(
        list.map(ints(n), fn(k) {
          on_circle(c, r, -90.0 +. 360.0 *. int.to_float(k) /. int.to_float(n))
        }),
        color,
      )
    }
    Colored(inner, hue) ->
      outline(inner, "hsl(" <> int.to_string(hue % 360) <> ", 80%, 60%)")
  }
}

// Points every 5 degrees (at least 2) from one angle to another.
fn arc_points(c: Point, r: Float, from: Float, to: Float) -> List(Point) {
  let steps =
    int.max(
      2,
      float.ceiling(float.absolute_value(to -. from) /. 5.0) |> float.truncate,
    )
  list.map(ints(steps), fn(k) {
    on_circle(
      c,
      r,
      from +. { to -. from } *. int.to_float(k) /. int.to_float(steps),
    )
  })
}

fn on_circle(c: Point, r: Float, degrees: Float) -> Point {
  let radians = degrees *. pi /. 180.0
  Point(c.x +. r *. cos(radians), c.y +. r *. sin(radians))
}

// [0, 1, ..., n]
fn ints(n: Int) -> List(Int) {
  list.repeat(Nil, n + 1) |> list.index_map(fn(_, i) { i })
}
