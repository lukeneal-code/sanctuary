# Sanctuary — Project Memory (read this first)

First-person dialogue / stealth / inventory puzzle game. Godot 4.x, GDScript,
Compatibility renderer. PSX low-poly look, dark ambient audio, dieselpunk-light.
**Solo dev. Scope is deliberately small. Prefer the simplest thing that works.**

## Keeping these docs in sync

**This file is canonical** — it's the contract every session reads, so it must
never lie. When you change something structural (a convention, a command, the
autoload list, an asset rule, the folder layout), update the affected docs *in
the same change*, not "later":

- **`CLAUDE.md` (here)** — always, first.
- **`README.md`** — if prerequisites, commands, or first-run steps changed.
- **`tools/blender/README.md`** — if asset conventions, name suffixes, tri
  budgets, or the pipeline changed.
- **The design guide** (`sanctuary-dev-guide.md`, kept alongside the repo) — if
  architecture, the systems list, or the roadmap changed. That doc is the *why*;
  this file is the *rules*.

Rule of thumb: if a future session would act wrongly because a doc was stale,
that stale doc was the bug. After a structural change, say which docs you touched.

## Commands — run before claiming a task is done

- `make smoke` — boots the core loop headless, asserts, exits 0 on success.
- `make test` — headless unit tests; exit code 0 = pass.
- `make lint` / `make format` — gdlint / gdformat --check (needs `pip install gdtoolkit`).
- `make check` — lint + format + test + smoke. The pre-commit gate.
- `make run` — launches the game (human only; you can't see it).
- `make assets` — validate + export every `.blend` in `art_src/` to `assets/models/` (needs Blender).
- `make validate-assets` — validate `.blend` files against conventions without exporting.

**Fresh checkout / new `class_name`:** `.godot/` is gitignored, so on a clean
checkout the global class cache is absent and `class_name` scripts won't resolve
— autoloads fail to load and `make test`/`make smoke` report `0 passed`. Run one
import pass first: `godot --headless --path . --editor --quit`. Re-run it after
adding a new `class_name` script. (Local Godot here is the mono app build, not on
PATH; pass `GODOT=/Applications/Godot_mono.app/Contents/MacOS/Godot`.)

You cannot see the running game. For anything visual or spatial, expose tunable
values as `@export` vars and ask the human to verify in-editor or send a
screenshot. Do not guess at look/feel blind.

## Architecture

- **Autoloads (singletons), in load order:** `GameState`, `Inventory`,
  `SaveSystem`, `SceneManager`, `AudioDirector`, `GlobalInput`. Access by global
  name (e.g. `GameState.set_flag(...)`) or path `/root/GameState`. `GlobalInput`
  is the app-level input singleton (Esc-to-quit; seat for the Phase 5 pause menu).
- **World state lives in `GameState.flags` (Dictionary).** Never store
  progression on individual nodes. This is what makes saves and tests work.
- **Data-driven.** Items, dialogue, NPCs, rooms, textures are DATA under `data/`,
  consumed by generic scenes. Adding content = adding data, not editing scene trees.
- **PSX surface textures.** `TextureCatalog` (`scripts/levels/texture_catalog.gd`)
  loads `data/textures/textures.json` — a flat catalog keyed by semantic id,
  parallel to `ItemCatalog` — and `make_material()` builds a `StandardMaterial3D`
  with nearest-neighbour filtering. That factory is the one place the PSX
  no-bilinear look is enforced. `room_builder` applies textures to the CSG shell
  by id via an optional `surfaces` block in room JSON.
- **Save format** is JSON in `user://saves/slot_N.json` (state + inventory +
  player transform). Keep it readable.
- **Phase 1 systems split brain/body.** Each system has a pure, headless-testable
  core and a thin scene/UI body: `DialogueRunner` (JSON walker) vs `dialogue_ui`;
  `GuardVision.in_view_cone` (pure cone) vs `guard` (patrol + LOS raycast); `Door`
  gate `can_open()` vs its visuals. Put logic in the core so a unit test or the
  smoke drive can exercise it without a window.
- **Interaction.** Interactables join the `interactable` group and expose
  `interact(player)` (+ optional `get_prompt() -> String`); the player's camera
  `Interactor` raycast focuses whatever is under the crosshair and dispatches to
  it. Door, pickup, and NPC all follow this.
- **Input & physics layers.** Actions: `move_forward/back/left/right`, `interact`
  (E — also advances dialogue), `crouch` (Ctrl), `quit` (Esc — quits the game,
  handled globally by `GlobalInput`). Layers: 1 = world, 2 =
  interactable, 3 = player, 4 = guard (LOS rays mask world only, so they ignore
  the player and guard).

## Boundaries — DO NOT

- Do NOT edit exported binaries under `assets/` (`.glb`, textures, audio). Do
  not hand-edit `.glb` or `.import`. Regenerate `.glb` via the Blender tools.
- Do NOT do artful/organic modelling — that is the human's job in Blender. You
  own the `tools/blender/` scripts: procedural geometry, batch export, validation.
- Do NOT put game progression state on nodes — use `GameState`.
- Do NOT add a new system without a test in `tests/` (unit) and, if it touches
  the core loop, an assertion in the smoke test.
- Do NOT hand-author `.tres` resources with fabricated UIDs. Prefer JSON data
  loaded at runtime (like `data/items/items.json`), or scaffold via an editor
  script and let Godot assign UIDs.

## How to add content

- **New item:** add an entry to `data/items/items.json`. Reference it by its
  string id everywhere. Combinations are symmetric: set `combines_with` +
  `combines_into` on either side.
- **New conversation (Phase 1 — temporary runner):** add a JSON graph at
  `data/dialogue/<id>.json` and reference its id from an NPC (`dialogue` field).
  Schema: top-level `{id, start, nodes}`; each node `{speaker, text, set_flags?,
  choices[]}`; each choice `{text, goto, set_flags?, require_flags?}`. `goto:""`
  ends; `require_flags` (all must match) gates a choice; `set_flags` apply on node
  entry / choice pick; everything reads & writes `GameState`. `DialogueRunner`
  (`scripts/dialogue/dialogue_runner.gd`) is the pure, headless-tested walker; the
  UI is a thin layer over it. **This runner is a stopgap** — Phase 2 replaces it
  with the Dialogue Manager addon (install into `addons/`, `.dialogue` files in
  `data/dialogue/`, gate on flags). Until that addon is in, do not invent its files.
- **New texture (PSX surfaces):** drop a low-res PNG in
  `assets/textures/<category>/` (e.g. `surfaces/`) — that file is a binary, so it
  falls under the "do not edit binaries under `assets/`" boundary. Add an entry to
  `data/textures/textures.json` keyed by a semantic id: `{path, category, tags[],
  description, tiling?:[u,v], roughness?}`. Reference it by **id**, never by path —
  from a room's `surfaces` block or any `TextureCatalog.make_material(id, catalog)`
  call. `tags` + `description` exist so a session can pick the right texture
  *without seeing it*; write them for that reader. After adding a PNG, run the
  import pass (`godot --headless --path . --editor --quit`) so Godot imports it;
  `test_texture_catalog_paths_exist` fails `make test` on any dangling `path`.
- **New room (Phase 1):** add `data/rooms/<id>.json` and load it with a
  `room_builder` Node3D (see `scenes/levels/greybox.tscn`). Schema: `{id, ambient,
  size:[x,y,z], surfaces?:{floor, ceiling, walls}, spawns:{name:{pos,yaw}},
  entities:[...]}`. `surfaces` maps a role to a texture id (see *New texture*); an
  absent role leaves that surface untextured (the grey greybox default). Entity
  types: `pickup{item}`, `door{requires_item, opened_flag}`, `npc{name, dialogue}`,
  `guard{patrol:[[x,y,z]...], fov, range, speed}`, each with `pos`/`yaw`. The
  builder makes the CSG shell and instances entity scenes — new rooms are new
  JSON, not new scene trees. (NPCs are inline in the room JSON for now; promote to
  `data/npcs/` if they grow shared data.) Add a test for any new logic.

## Scene authoring

Editing `.tscn` by hand is error-prone. In order of preference: (1) data-driven
generic scenes; (2) scaffold node trees with an `@tool`/EditorScript run once;
(3) small surgical `.tscn` edits only when the change is obvious.

The Phase 1 entity/UI/level scenes were generated by approach (2):
`tools/godot/scaffold_phase1.gd` builds each node tree in code, packs it, and
saves a `.tscn` so Godot assigns UIDs. It is re-runnable and overwrites its
outputs — `godot --headless --path . --script res://tools/godot/scaffold_phase1.gd`.
After generating, tune the scenes' `@export` values in-editor.

**UI scale.** The game uses 2D content scaling
(`display/window/stretch/mode="canvas_items"`) against a 1280×720 reference
resolution, so all UI laid out at that base scales uniformly with the window
(3D/PSX render is unaffected). Design UI at 1280×720 and let the stretch handle
sizing — don't hardcode per-`Label` font sizes (they'd also be lost on a scaffold
re-run). To make all UI globally bigger or smaller, set
`display/window/stretch/scale`.

## Blender / asset pipeline

The division of labour: **the human models** (artful, organic, judgement-heavy
work). **Claude owns the code around the model** — procedural geometry-as-code,
batch export, and validation. See `tools/blender/README.md` for details.

Layout and flow:

- Source `.blend` files live in `art_src/blender/` (git-tracked, but Godot skips
  the folder via `art_src/.gdignore`). Exported `.glb` files land in
  `assets/models/` and are what Godot imports.
- `make assets` runs Blender headless: for each `.blend` it validates against the
  conventions, then exports a `.glb`. A failed validation fails the build — that
  is the signal you read instead of seeing the model.
- `tools/blender/gen_props.py` is the geometry-as-code example (a crate + a wall
  panel, parametric, with auto collision proxies). For modular PSX environment
  pieces this is the high-leverage path: author them as code, re-run on tweaked
  params, always exports clean. Add new `--kind`s the same way.

Asset conventions (enforced by `tools/blender/blender_env.py`, edit budgets
there): 1 Blender unit = 1 m; transforms applied (scale 1, rotation 0); +Y up on
export; visual meshes have a UV map and stay under the tri budget; collision and
nav are SEPARATE proxy objects whose names end in a Godot import suffix
(`-col`, `-convcol`, `-colonly`, `-convcolonly`, `-rigid`, `-navmesh`, `-noimp`).

Interactive option (human-driven, not required): the **Blender MCP connector**
lets a chat-side Claude read and edit a *live* Blender session over a socket —
good for blockouts, scene introspection, and batch edits on hard-surface /
architectural geometry (this game's sweet spot). It needs Blender open with the
addon running and executes generated Python in your session, so treat it as a
cockpit for interactive work, while `make assets` stays the deterministic,
version-controlled backbone. Prefer the official connector (built by the Blender
devs, Blender 4.2+) over community servers. Do not assume it is set up.

## Testing

The current runner is a small, dependency-free script (`tests/test_runner.gd`):
any `test_*` method is auto-discovered; singleton state resets before each test.
This keeps the harness working without external addons. To upgrade to **GUT**
later: drop it in `addons/gut/`, move tests to `tests/unit/`, and change the
`test` target to:
`$(GODOT) --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`.

## Style

GDScript, typed where practical. `snake_case` files and functions, `PascalCase`
classes and node names. Small functions. Comment the *why*, not the *what*.
Run `gdformat scripts tests` to normalise indentation to tabs.

## Roadmap (where we are)

- **Phase 0 (done):** harness — autoloads, save/load, tests, smoke.
- **Phase 1 (done):** greybox vertical slice — one room, all systems crude:
  first-person controller + camera interaction ray, look-to-interact, item
  pickup, item-gated locked door, a custom JSON dialogue runner + UI, and a
  patrolling guard with cone + line-of-sight detection. `make smoke` drives the
  whole loop headless. Look/feel still needs in-editor tuning (`make run`).
- **Phase 2 (next):** Stage 1 "Ceremony" content. Opens with the PSX texture
  catalogue (`data/textures/textures.json` + `TextureCatalog`, see *New texture*)
  so Ceremony rooms can be textured by id; the catalogue ships empty and fills as
  real PNGs land.
- **Phase 3:** Stage 2 "Cracks" (biggest content phase).
- **Phase 4:** Stage 3 "Escape" + endings.
- **Phase 5:** audio, save/load hardening, menus, polish.
