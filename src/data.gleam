//// The library of saved drawings. A drawing is a name and the source of its draw
//// function.

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/result

// ── localStorage (data_ffi.mjs) ───────────────────────────────────────────────

/// The string stored in localStorage under key, or an Error if there isn't one.
@external(javascript, "./data_ffi.mjs", "storageGet")
pub fn storage_get(key: String) -> Result(String, Nil)

/// Store value in localStorage under key, replacing anything already there. If that
/// isn't possible, this logs the reason to the browser console.
@external(javascript, "./data_ffi.mjs", "storageSet")
pub fn storage_set(key: String, value: String) -> Nil

// ── The new-drawing prompt (data_ffi.mjs) ─────────────────────────────────────

/// Prompt the user to name a new drawing; "" (empty string) means they
/// cancelled or left it blank.
@external(javascript, "./data_ffi.mjs", "promptDrawingName")
pub fn prompt_drawing_name() -> String

// ── The library ───────────────────────────────────────────────────────────────

/// All saved drawings (name and source) and the name of the one that's open.
pub type Library {
  Library(current: String, drawings: List(#(String, String)))
}

const library_key = "animator-library"

fn library_decoder() -> decode.Decoder(Library) {
  use current <- decode.field("current", decode.string)
  use drawings <- decode.field(
    "drawings",
    decode.list({
      use name <- decode.field("name", decode.string)
      use source <- decode.field("source", decode.string)
      decode.success(#(name, source))
    }),
  )
  decode.success(Library(current, drawings))
}

/// The saved library, or one made of `examples` (opening the first) if there is
/// none, or it can't be read, or it has no drawings.
pub fn load(examples: List(#(String, String))) -> Library {
  let saved =
    storage_get(library_key)
    |> result.replace_error(Nil)
    |> result.try(fn(text) {
      json.parse(text, library_decoder()) |> result.replace_error(Nil)
    })
  case saved {
    Ok(Library(current, [first, ..] as drawings)) ->
      case list.key_find(drawings, current) {
        Ok(_) -> Library(current, drawings)
        Error(_) -> Library(first.0, drawings)
      }
    _ ->
      case examples {
        [first, ..] -> Library(first.0, examples)
        [] -> Library("", [])
      }
  }
}

/// Save the library to localStorage as JSON; each source is stored as typed.
pub fn save(library: Library) -> Nil {
  let drawings =
    json.array(library.drawings, fn(d) {
      json.object([#("name", json.string(d.0)), #("source", json.string(d.1))])
    })
  json.object([
    #("current", json.string(library.current)),
    #("drawings", drawings),
  ])
  |> json.to_string
  |> storage_set(library_key, _)
}
