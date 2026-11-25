//// Animator -- an application for program-generated drawings.

import builtins
import data.{type Library, Library}
import drawing
import editor
import errors
import examples
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import parser
import render
import shape.{type Path}

/// Your app's public address, once you've deployed it in Problem 13, such as
/// "https://your-username.github.io/animator/".
pub const public_url = "https://mathewrolf1.github.io/animator/"

/// Set to True if you would like your app's URL included in the course gallery.
pub const include_app_in_gallery = False

/// A link to your video from Problem 14, which anyone with the link can watch.
pub const video_url = "https://drive.google.com/file/d/1g0PpR_q48WnUa1TGOm2LieeooXclg1RT/view?usp=drive_link"

/// Set to True if you would like your video included in the course gallery.
pub const include_video_in_gallery = False

const default_code =
  "fn draw(shape_slider: Int) -> List(Path) {\n  [Path(Line(Point(0, 0), Point(100, 100)), 0, 10, 2)]\n}\n"

// ── Model ──────────────────────────────────────────────────────────────────────

pub type Model {
  Model(
    // The saved drawings and the name of the open one.
    library: Library,
    // The code in the editor.
    source: String,
    shape_slider: Int,
    speed: Float,
    paused: Bool,
    // The parse or evaluation error for the current code, or "" if it ran.
    error: String,
    // Whether the code editor is shown.
    code_open: Bool,
  )
}

pub type Msg {
  SetCode(String)
  SetShape(String)
  SetSpeed(String)
  ResetClock
  TogglePause
  SelectDrawing(String)

  // Layout controls
  ToggleCode
}

/// The value of the select's "new drawing" option; no drawing name can clash
/// with it since it is not one a student can type without a prompt.
const new_option = "\u{0}new"

const colors = ["#ff6b6b", "#ffd93d", "#6bcB77", "#4d96ff", "#c77dff", "#ff9f45"]

// ── Init ───────────────────────────────────────────────────────────────────────

pub fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  let library = data.load(examples.all)
  let source = current_source(library)
  let model =
    Model(
      library:,
      source:,
      shape_slider: 10,
      speed: 1.0,
      paused: False,
      error: "",
      code_open: True,
    )
  let #(model, draw_effect) = redraw(model)
  #(model, effect.batch([editor.mount(source, SetCode), draw_effect]))
}

fn current_source(library: Library) -> String {
  list.key_find(library.drawings, library.current) |> result.unwrap("")
}

// Parse and evaluate a draw function at the given shape-slider value, returning
// the rendered paths on success, or a human-readable message on failure.
fn run_source(shape_slider: Int, source: String) -> Result(List(Path), String) {
  case parser.parse_program(source, builtins.global_frame()) {
    Error(msg) -> Error(msg)
    Ok(program) ->
      drawing.try_draw(shape_slider, program)
      // Convert Error(EvalError) to Error(String) with a useful error message.
      |> result.map_error(errors.error_message)
  }
}

// Run the model's code and animate the result; on an error draw nothing and
// record the message.
fn redraw(model: Model) -> #(Model, Effect(Msg)) {
  let #(error, render_paths) = case
    run_source(model.shape_slider, model.source)
  {
    Ok(paths) -> #(
      "",
      list.index_map(paths, fn(path, i) {
        let color = list.drop(colors, i % list.length(colors))
        render.render_path(path, result.unwrap(list.first(color), "white"))
      }),
    )
    Error(msg) -> #(msg, [])
  }
  #(
    Model(..model, error:),
    effect.from(fn(_) { render.set_drawing(render_paths) }),
  )
}

// ── Update ─────────────────────────────────────────────────────────────────────

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ToggleCode -> #(Model(..model, code_open: !model.code_open), effect.none())

    // After each keystroke in the editor, save the code and redraw.
    SetCode(text) -> {
      let library = set_current_source(model.library, text)
      data.save(library)
      redraw(Model(..model, library:, source: text))
    }

    SetShape(value) ->
      redraw(Model(..model, shape_slider: result.unwrap(int.parse(value), 0)))

    SetSpeed(value) -> {
      let speed = result.unwrap(float.parse(value), 1.0)
      #(
        Model(..model, speed:, paused: False),
        effect.from(fn(_) { render.set_speed(speed) }),
      )
    }

    ResetClock -> #(model, effect.from(fn(_) { render.reset_clock() }))

    TogglePause -> {
      let paused = !model.paused
      let rate = case paused {
        True -> 0.0
        False -> model.speed
      }
      #(Model(..model, paused:), effect.from(fn(_) { render.set_speed(rate) }))
    }

    SelectDrawing(name) -> {
      let chosen = case name == new_option {
        True -> data.prompt_drawing_name()
        False -> name
      }
      case chosen {
        // Cancelled: keep the open drawing.
        "" -> #(model, effect.none())
        _ -> open_drawing(model, chosen)
      }
    }
  }
}

fn set_current_source(library: Library, text: String) -> Library {
  Library(
    ..library,
    drawings: list.map(library.drawings, fn(d) {
      case d.0 == library.current {
        True -> #(d.0, text)
        False -> d
      }
    }),
  )
}

// Open the named drawing, creating it (with the default code) if it is new.
fn open_drawing(model: Model, name: String) -> #(Model, Effect(Msg)) {
  let drawings = case list.key_find(model.library.drawings, name) {
    Ok(_) -> model.library.drawings
    Error(_) -> list.append(model.library.drawings, [#(name, default_code)])
  }
  let library = Library(current: name, drawings:)
  data.save(library)
  let source = current_source(library)
  let #(model, draw_effect) = redraw(Model(..model, library:, source:))
  #(
    model,
    effect.batch([
      editor.mount(source, SetCode),
      effect.from(fn(_) { render.reset_clock() }),
      draw_effect,
    ]),
  )
}

// ── View ──────────────────────────────────────────────────────────────────
//
// Two side-by-side panes: the code editor on the left and its rendered output on
// the right. The code column can be hidden to expand the right pane.

pub fn view(model: Model) -> Element(Msg) {
  let app_class = case model.code_open {
    True -> "app"
    False -> "app code-hidden"
  }
  // The code column still exists even when hidden (CSS collapses it) so the
  // mounted CodeMirror editor keeps its state across show/hide.
  html.div([attr.class(app_class)], [
    html.div([attr.class("code-col")], [
      view_controls(model),
      editor.view_panel(ToggleCode),
    ]),
    view_anim(model),
  ])
}

fn view_controls(model: Model) -> Element(Msg) {
  html.div([attr.class("controls")], [
    html.select(
      [
        attr.attribute("data-test-id", "drawing-select"),
        event.on_change(SelectDrawing),
      ],
      list.append(
        list.map(model.library.drawings, fn(d) {
          html.option(
            [attr.value(d.0), attr.selected(d.0 == model.library.current)],
            d.0,
          )
        }),
        [html.option([attr.value(new_option)], "+ New drawing…")],
      ),
    ),
    view_slider(
      "shape",
      "shape-slider",
      "0",
      "100",
      "1",
      int.to_string(model.shape_slider),
      SetShape,
    ),
    view_slider(
      "speed",
      "speed-slider",
      "-3",
      "3",
      "0.25",
      float.to_string(model.speed),
      SetSpeed,
    ),
    html.button([attr.class("icon-btn"), event.on_click(TogglePause)], [
      html.text(case model.paused {
        True -> "▶ play"
        False -> "⏸ pause"
      }),
    ]),
    html.button([attr.class("icon-btn"), event.on_click(ResetClock)], [
      html.text("↺ restart"),
    ]),
  ])
}

fn view_slider(
  label: String,
  test_id: String,
  min: String,
  max: String,
  step: String,
  value: String,
  on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.label([], [
    html.text(label <> " "),
    html.input([
      attr.type_("range"),
      attr.attribute("data-test-id", test_id),
      attr.min(min),
      attr.max(max),
      attr.step(step),
      attr.value(value),
      event.on_input(on_input),
    ]),
    html.text(" " <> value),
  ])
}

fn view_anim(model: Model) -> Element(Msg) {
  html.div([attr.class("canvas-area")], [
    view_reveal_code(model),
    html.canvas([attr.id("animation-canvas"), attr.class("canvas")]),
    case model.error {
      "" -> element.none()
      msg -> html.pre([attr.class("output error")], [html.text(msg)])
    },
  ])
}

// The button that brings the code column back, overlaid on the top-left of the
// right pane. Nothing is rendered while the column is already showing (its own
// header holds the button that hides it).
fn view_reveal_code(model: Model) -> Element(Msg) {
  case model.code_open {
    True -> element.none()
    False ->
      html.button(
        [
          attr.class("icon-btn reveal-code"),
          attr.attribute("title", "Show code"),
          event.on_click(ToggleCode),
        ],
        [html.text("⟩")],
      )
  }
}

// ── Main ───────────────────────────────────────────────────────────────────────

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
