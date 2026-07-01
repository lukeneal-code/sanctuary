# Sanctuary — Development Harness & Production Guide

*A solo-developer, AI-assisted pipeline for a first-person dialogue / inventory / stealth puzzle game. Built with Claude Code + Godot 4.x + Blender. PSX low-poly, dark ambient, dieselpunk-adjacent.*

> **Read of your brief:** Your second and third stages were both labelled "Third stage," so this guide treats them as **Stage 1 – Ceremony**, **Stage 2 – Cracks**, **Stage 3 – Escape**. Character names below are suggestions you can ignore; the cult's inner circle going by numbers/titles is kept deliberately because it's creepy and free.

> **Build status (kept in sync with the repo).** Part A is no longer just a plan — the **Phase 0 harness** and the **Blender asset pipeline** are implemented, and the **Phase 1 greybox vertical slice** is essentially done (all ten systems present in crude form; see Part C). The **PSX surface-texture system** (`TextureCatalog` + `data/textures/textures.json`, with optional normal maps) also now exists. **Phase 2 (Stage 1 – Ceremony) is well underway:** room-to-room transitions (a *threshold* door reloads the one generic level host into the next room, selected by `GameState.current_room`), a day-cycle scaffold, the opening beat — wake in the booking cell, don the robe to leave, meet Brother Coll in the corridor — and now the full Ceremony beat are in: flag-gated + day-advancing doors, the Ceremony hall, the compliance ritual scripted as dialogue with illusory choices, the cast you meet along the way (Edrin, Vesna, Renn, Kassian), and the loop close — leave the hall and land in a day-two night cell with the day advanced. Still ahead: the inner circle as distinct characters and the fuller return-to-booking day loop (a cell that regenerates per day rather than the terminal night cell). This guide is the *spec*; the repo is the *implementation*; they're meant to agree. Repo entry points: `README.md` (quick-start), `CLAUDE.md` (the contract the agent reads — canonical when the two disagree), and `tools/blender/README.md` (the asset pipeline). Sections below flag what's built vs. still ahead.

---

## Part A — The Harness (the part that actually decides whether AI-assisted dev works)

The single biggest factor in whether Claude Code is useful on a game is **whether it can get a feedback signal without human eyes**. A coding agent thrives on a tight edit → run → read-result → fix loop. Most of this section exists to manufacture that loop for a game engine, which doesn't give you one by default.

### A1. The core principle: text over binary, data over scenes

Draw a hard line and write it into `CLAUDE.md`:

- **AI territory (text):** GDScript (`.gd`), text scenes (`.tscn`), text resources (`.tres`), dialogue/data files (`.dialogue`, `.json`, `.csv`), shaders (`.gdshader`), tooling scripts.
- **Human + Blender territory (binary):** `.blend`, exported `.glb`/`.gltf`, `.import` files, audio, baked lightmaps.

Then push as much of the game as possible into **data, not bespoke scenes**. A room, an NPC, an item, and a conversation should each be definable by a data file that a *generic* scene reads at runtime. Adding content then means writing data (which Claude does tirelessly and correctly) rather than performing surgery on `.tscn` node trees (which it does adequately but riskily). This one decision is simultaneously your biggest scope-saver and your biggest AI-leverage multiplier.

### A2. Repository structure *(as built)*

```
sanctuary/
├── CLAUDE.md                 # the contract: architecture, commands, conventions, boundaries
├── README.md                 # quick-start
├── project.godot             # autoloads + Compatibility renderer
├── .gitignore
├── Makefile                  # wraps repeated commands (game loop + asset pipeline)
├── addons/                   # third-party (Dialogue Manager, GUT) — added when needed
├── art_src/                  # SOURCE .blend files (git-tracked, human-owned)
│   ├── .gdignore             #   ↳ makes Godot skip this tree (we ship .glb, not .blend)
│   └── blender/
├── assets/                   # EXPORTED binaries Godot imports — never hand-edited
│   ├── models/               #   .glb produced by the Blender pipeline
│   └── textures/ audio/ materials/
├── scenes/
│   ├── core/                 #   main scene now; generic Room/NPC/Interactable in Phase 1
│   └── levels/ ui/
├── scripts/
│   ├── core/                 #   GameState, SaveSystem, SceneManager, AudioDirector (autoloads)
│   ├── inventory/            #   inventory autoload + JSON item catalog
│   └── player/ dialogue/ stealth/   # filled in Phase 1+
├── data/                     # THE CONTENT — AI authors freely here
│   ├── items/                #   items.json (catalog)
│   ├── textures/             #   textures.json (PSX surface catalog, by semantic id)
│   └── dialogue/ npcs/ rooms/ quests/
├── shaders/                  # psx_surface.gdshader, dither, fog (Phase 2)
├── tests/                    # dependency-free runner + smoke scene (GUT optional later)
│   ├── test_runner.gd / .tscn
│   └── smoke/ smoke.gd / .tscn
└── tools/
    └── blender/              # the asset pipeline — Claude-owned (see its README)
        ├── blender_env.py    #   conventions + helpers + the validator
        ├── export_glb.py  validate_asset.py  batch_export.py
        ├── gen_props.py      #   procedural geometry-as-code example
        └── README.md
```


### A3. `.gitignore` (Godot 4)

```
.godot/                  # Godot's import cache — regenerates
/build/  /export/
export_presets.cfg
__pycache__/  *.pyc       # the Blender tool scripts are Python
.DS_Store
# keep per-asset .import files committed — they're needed and avoid re-import churn.
```

Use Git seriously: a branch per vertical slice, a commit per working feature, meaningful messages. When Claude Code wanders off into the weeds (it will, occasionally), `git revert` is your undo button. Let Claude do its own commits — it writes good messages — but you review the diff.

### A4. `CLAUDE.md` skeleton

This file is the highest-leverage artifact in the whole project. Keep it current. A skeleton (the repo already contains a fuller, live version):

```markdown
# Sanctuary — Project Memory

## What this is
First-person dialogue/stealth/inventory puzzle game. Godot 4.x, GDScript.
Solo dev. Scope is deliberately small. Prefer the simplest thing that works.

## Commands (always run before claiming done)
- Lint:   `make lint`   (gdlint + gdformat --check)
- Test:   `make test`   (headless run of the dependency-free test runner; exit 0 = pass)
- Smoke:  `make smoke`   (boots the smoke-test scene headless, asserts core loop, exits)
- Run:    `make run`     (human-only; launches the game)

## Architecture
- Autoloads (singletons): GameState, Inventory, SaveSystem, SceneManager, AudioDirector, GlobalInput. (See CLAUDE.md for the canonical, current list.)
- Data-driven: rooms/npcs/items/dialogue are DATA in /data, read by generic scenes in /scenes/core.
- World state lives in GameState.flags (Dictionary). Never store progression on nodes.
- Dialogue (Phase 1): custom JSON walker (DialogueRunner) over /data/dialogue/<id>.json. Phase 2 swaps in the Dialogue Manager addon (.dialogue files). Either way, gate on GameState flags.

## Boundaries — DO NOT
- Do NOT edit anything in /assets (binary, human/Blender owned).
- Do NOT hand-edit .glb/.import.
- Do NOT put game progression state on individual nodes — use GameState.
- Do NOT add a new system without a test scene in /tests.

## How to add content
- New item: add an entry to /data/items/items.json; reference by string id.
- New conversation: add /data/dialogue/<id>.json (custom-runner schema) now; switches to .dialogue when the Dialogue Manager addon lands in Phase 2. Gate with GameState flags.
- New NPC: add /data/npcs/<name>.tres; the generic NPC scene consumes it.

## Style
GDScript, typed where practical. snake_case files. PascalCase classes/nodes.
Small functions. Comment the "why," not the "what."
```

### A5. The feedback loop — give the agent something to read

Three layers, cheapest first:

1. **Static checks.** `gdtoolkit` gives you `gdlint` and `gdformat` (`pip install gdtoolkit`). Catches the easy stuff instantly.
2. **Unit tests.** *(built)* The repo ships a small **dependency-free runner** (`tests/test_runner.gd`): any `test_*` method is auto-discovered, singleton state resets between tests, and it quits with exit 0/1. It covers flag transitions, the change-signal, inventory add/remove/combine, and the save round-trip — pure logic you've deliberately kept out of the visual layer. It needs no addon, so the harness works the moment you clone. Upgrade path to **GUT** (Godot Unit Test) when you want fixtures and richer asserts — drop it in `addons/gut/`, move tests to `tests/unit/`, and point the `test` target at:
   ```
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
   ```
3. **A smoke-test scene.** *(built)* `tests/smoke/smoke.gd` boots the engine, verifies the six autoloads exist and interoperate (flag → inventory → save → reload), prints `PASS`/`FAIL`, and quits with the right exit code — the agent's "did I break the core loop" canary. In Phase 1 you extend it to spawn the real player, look at an interactable, trigger a pickup, and advance a dialogue node before asserting.

Wrap all three in a `Makefile` so the agent (and you) invoke them by name. Now Claude's loop is real: edit → `make test` → read output → fix.

### A6. The visual loop — the part only you can close

Claude can't see your game running. Two practical bridges:

- **Programmatic screenshots.** Bind a debug key, or add a headless screenshot pass, that calls `get_viewport().get_texture().get_image().save_png("user://shots/...")`. After a build, you grab the relevant shots and paste them back into the Claude Code session for visual feedback ("the fog is too dense," "the PSX jitter is too strong"). This is your manual-but-effective vision channel.
- **Editor verification.** For anything spatial — level layout, NPC patrol paths, lighting — *you* verify in the Godot editor. Don't ask the agent to "make the room feel oppressive" blind; ask it to expose the knobs (fog density, light energy, vertex-snap strength) as exported variables, then you tune them in-editor.

> **Interactive option (now real).** There is an **official Blender MCP connector** built by the Blender developers (shipped with Claude for Creative Work, Blender 4.2+), plus community servers, that let a chat-side Claude read and edit a *live* Blender session. It tightens the visual loop for hard-surface/architectural work — this game's sweet spot — but it needs Blender open and runs generated code in your session. Treat it as an interactive cockpit, not the backbone. Details and honest limits in A8.

### A7. Scene authoring strategy

Hand-editing complex `.tscn` files (by you or the agent) is where AI-assisted Godot work goes wrong. Mitigations, in order of preference:

1. **Data-driven scenes.** A `Room.tscn` that reads `data/rooms/booking.tres` and spawns interactables/NPCs from data. Most "new content" never touches a scene file.
2. **`@tool` / `EditorScript` scaffolding.** For repetitive node trees, have Claude write a script that *builds* the tree, run it once, save the result. Generated, then human-verified.
3. **Direct `.tscn` edits** only for small, surgical changes the agent can clearly reason about.

### A8. Blender → Godot pipeline *(built — see `tools/blender/README.md`)*

The boundary: **you model** (anything needing eyes and taste); **Claude owns the code around the model** — procedural geometry, batch export, and validation. None of that needs to *see* anything, so the agent does it reliably and you review the diffs. The piece that makes it work is the **validator as a feedback signal**: it turns "is this asset correct?" into a text pass/fail with an exit code, the same kind of signal `make test` gives for code. Without it the agent is flying blind on assets.

What's in the repo:

- **Layout & isolation.** Source `.blend` files live in `art_src/blender/` (git-tracked). An `art_src/.gdignore` makes Godot skip that tree, so the engine imports your exported `.glb` from `assets/models/`, never your working files.
- **`make assets`** runs Blender headless (`batch_export.py`): for each `.blend` it validates against the conventions, then exports a `.glb`. A failed asset fails the build with a readable reason. `make validate-assets` checks without exporting. (Blender's `--python-exit-code 1` is what lets the validator's `raise SystemExit(1)` reach `make`.)
- **Conventions, enforced** (`blender_env.py`, tweak budgets there): 1 unit = 1 m; transforms applied (scale 1, rotation 0); +Y up on export; visual meshes carry a UV map and stay under the tri budget; node-safe names (no spaces); collision/nav are **separate proxy objects** named with a Godot import suffix:

  | suffix | Godot result |
  |---|---|
  | `-col` / `-colonly` | concave (trimesh) collision, with / without the visible mesh |
  | `-convcol` / `-convcolonly` | convex collision, with / without the mesh |
  | `-rigid` | rigid body |
  | `-navmesh` | navigation mesh |
  | `-noimp` | skipped on import |

  Convex for boxy props (cheaper); concave for exact static geometry.
- **Geometry-as-code** (`gen_props.py`) is the high-leverage path for a *modular* PSX building. Crates, wall panels, doorframes, ducting are parametric — author them as code, re-run on tweaked numbers, always exports clean with auto-generated collision proxies. Two examples ship (crate, wall); adding a kind is a `build_<kind>()` function plus a dict entry — a one-line ask to the agent. `make gen-examples` regenerates them.

**Interactive option (the cockpit).** The official **Blender MCP connector** (Blender devs; Claude for Creative Work; Blender 4.2+) and community servers connect a chat-side Claude to a *live* Blender session over a socket — good for blockouts, scene introspection, and batch edits, with errors looping straight back to Claude. Honest limits (community consensus): strong on hard-surface/architectural geometry, weak on organic/character and final-quality output; needs Blender open with the addon active; executes generated code in your session (run it without sensitive data around if that worries you). Use it for interactive work; keep `make assets` as the deterministic, version-controlled source of truth for what ships. Setup details move, so follow each project's current docs rather than a snapshot.

- **PSX look** is achieved in *Godot*, not Blender — see A9.

### A9. The PSX look — two approaches, one decision still open

There are two ways to get the PSX look, and the project currently sits between them. **Decide which you commit to before Phase 2 art lands** — they're not mutually exclusive, but the shader is real work and the texture path may already be "enough."

**What's built today (the texture-catalog path).** The realized look comes entirely from *materials and lighting*, no shader: `TextureCatalog` (`scripts/levels/texture_catalog.gd`) builds a `StandardMaterial3D` per surface with **nearest-neighbour filtering** (the no-bilinear crunch), optional **normal maps** for tactile relief on the flat CSG, low-res PNG source art, and deliberately **dark, low-energy lighting** (`room_builder` reads ambient/sun/bg from room JSON). Textures are referenced by semantic id from a room's `surfaces` block. This is cheap, data-driven, and already gives a credible institutional-PSX feel.

**What's planned but not built (the full shader).** A handful of well-understood, scriptable tricks that go further:

- **Vertex snapping/jitter:** quantize vertex positions in clip space in the vertex shader (the signature wobble).
- **Affine texture mapping:** disable perspective-correct interpolation so textures swim on near surfaces.
- **Low internal resolution:** render the 3D world into a `SubViewport` at a low res, then upscale with nearest-neighbour to a full-screen rect. This single move does most of the heavy lifting.
- **Limited colour depth + ordered dithering**, and **distance fog** doubling as your draw-distance cutoff (which also lets you keep scenes small — a scope win disguised as an aesthetic).

No `.gdshader`, `SubViewport`, or dither exists yet. Expose strength/snap/fog as exported uniforms *if* you build it, so you tune by eye in-editor and via screenshots.

> **Open decision:** ship the full SubViewport/vertex-snap/dither shader, or treat the texture-catalog + lighting path as the final look (and maybe add only distance fog)? The vertex wobble and low-res upscale are the parts the texture path can't replicate. Resolve this when you push real hero assets in Phase 2.

### A10. Scope guardrails (re-read these monthly)

The two systems that will try to eat your timeline are **emergent stealth AI** and **branching narrative**. Pre-decide:

- **Soft stealth, not simulation.** NPCs get a 3-state machine (Patrol → Suspicious → Alert), a vision cone, a fixed patrol path (`NavigationAgent`), and a detection meter. Getting caught is a *soft fail* (raise a suspicion flag / reset to a checkpoint), not a fail-state with complex pursuit AI. Keep ≤3 active NPCs per stealth space.
- **Flag-gated variation, not divergent content.** Your "few different approaches" should mostly be the *same* spaces and assets recombined by flags, plus a handful of bespoke moments — not three separately-authored escape levels.
- **One location, reused.** The compound is your entire world. Day/cycle structure and progressively unlocked areas let you reuse every asset across all three stages. This is the most important scope decision in the project.

---

## Part B — Core systems & the vertical-slice philosophy

Minimum systems for this genre:

1. First-person controller (walk, look, crouch, sprint).
2. Interaction (look-at raycast + "press E," contextual prompts).
3. Dialogue (branching, condition/flag-gated, runs mutations on the world).
4. Inventory (hold, examine, combine, use-on-target).
5. Stealth (vision cones, NPC state machine, suspicion meter, hiding spots).
6. World state (`GameState.flags`) + objectives.
7. Save/load (serialise flags + inventory + player transform).
8. UI (HUD prompt, dialogue box, inventory screen, pause/menu).
9. Audio director (ambient music layers, footsteps, tension stingers).
10. Scene management & transitions.

**A vertical slice is a thin cut through *all* of these at once**, playable end to end, even if ugly. You do not build inventory fully, then dialogue fully, then stealth fully — you build a crude version of each that *connects*, prove the loop, then thicken. The first slice's job is to surface integration problems while they're cheap.

---

## Part C — Phased roadmap (~4–6 months part-time; timeboxes are rough)

**Phase 0 — Harness ✓ *(done)*.** Delivered: repo + `.gitignore`, `CLAUDE.md`, `README.md`, `project.godot` with six autoloads (`GameState`, `Inventory`, `SaveSystem`, `SceneManager`, `AudioDirector`, `GlobalInput` — the last added during Phase 1 for Esc-to-quit / the future pause menu), JSON save/load, a dependency-free unit-test runner, a smoke scene, the `Makefile`, and the full Blender asset pipeline (`tools/blender/`, `make assets`). gdtoolkit-verified. **First thing to do on your machine:** run `make smoke` and `make test` against your Godot, and `make gen-examples` against your Blender, to confirm the harness is green end-to-end.

**Phase 1 — Greybox vertical slice (~2–3 weeks).** One grey-box room. Walk in, look at a door (locked), find a key item, read one branching conversation with one NPC, sneak past one patrolling guard with a vision cone, use the key, transition to a second grey room. All ten systems present in crude form. **This is the most important phase** — it de-risks the entire project. No final art. No story polish.

**Phase 2 — Stage 1: Ceremony (~3–4 weeks).** Build the intro for real, with assets and the PSX shader dialled in. Booking cell → walk-and-talk with the Overseer → the Ceremony itself. The Blender pipeline already exists; this is where you first push real hero assets through it and lock your tone.

**Phase 3 — Stage 2: Cracks (~4–6 weeks).** Your biggest content phase: free-roam of the compound, information gathering, the trust mini-arc, crafting, riddle puzzles, the suspicion system under real pressure. Most of your dialogue volume lives here.

**Phase 4 — Stage 3: Escape + endings (~3–4 weeks).** The payoff and the branching approaches. Reuses Stage 2 spaces under new flags (curfew layout, patrols, locked routes). Keep to 2–4 endings.

**Phase 5 — Polish (~2–4 weeks).** Audio passes, save/load hardening, menus, settings, bug-fix, performance, the final PSX tuning. Always longer than you think; budget for it.

---

## Part D — Characters, beats & mechanics

Suggested names (optional). The inner circle keep their numbers/titles on purpose.

| Role | Suggested name | Function in the game |
|---|---|---|
| Player | *(unnamed / chosen)* | early-30s, ex-Luvaro, dawning dread |
| Sector Overseer ("Uncle") | **Brother Coll** | recruiter, fake warmth, hollowed-out; your tutorial guide and your leash |
| The Second (2IC) | **Edrin** | groomed since youth, miserable, complies; the trapped near-ally |
| Cautious newcomer | **Renn** | your age/gender, different race; the trust-arc ally |
| Larger-than-life newcomer | **Vesna** | 20s, openly defiant, charismatic; the catalyst |
| Inner Circle #1 | **The First** | distant, paranoid figurehead; the final threshold |
| Inner Circle #2 | **The Steward** | passive-aggressive, flamboyant gatekeeper of an area |
| Inner Circle #3 | **The Elder** | white beard, knows it's insane, wants a quiet life; ambiguous |
| Inner Circle #4 | **The Archivist** | riddle-keeper; literal puzzle gate |
| Inner Circle #5 | **Kassian** | golden boy, cruel, irredeemable; the active hunter |
| The genius | **Halloran** | feigns madness, secretly kind; your means of escape |

### Design move: every character carries a mechanic

The cleanest way to keep a character-driven game from sprawling is to make each major character the *vehicle* for a specific system. Then writing them and building the game are the same task.

- **Coll (Overseer)** → teaches/embodies **compliance**. Walk-and-talk tutorials; later, his presence is a soft barrier.
- **Edrin (Second)** → the **trust/manipulation branch**; an access route if reached.
- **Renn (newcomer)** → the **ally trust meter**; unlocks a co-op-flavoured escape path.
- **Vesna** → the **catalyst / consequence demonstrator**; source of contraband + the event that makes escape urgent.
- **The Archivist (#4)** → **riddle puzzles** that gate information/access.
- **The Elder (#3)** → an optional **stealth bypass** (he looks away if you read him right).
- **The Steward (#2)** → an **area gatekeeper** to avoid or trick.
- **Kassian (#5)** → the **hunter/threat** in stealth setpieces and the dread engine.
- **The First (#1)** → the **final gate** at the threshold.
- **Halloran (genius)** → the **crafting/tool** system and the literal escape plan.

### Stage 1 — Ceremony  *(intro; teaches the verbs)*

- **Wake in the Booking.** Tutorial: move, look, interact. Find your assigned robe/token → inventory tutorial. The cell is small and over-warm; tone is "comfort that's slightly wrong."
- **Coll collects you.** Walk-and-talk to the Ceremony. *Mechanic: dialogue with choices that don't change anything yet* — the illusion of choice, which is thematically perfect for a cult and a free way to teach the dialogue UI. He's all kind-uncle warmth with the lights off behind his eyes; he mumbles a half-line of doctrine and doesn't notice he did.
- **Pass Edrin.** One flat, exhausted line. Plants the first seed: someone here is not okay.
- **The Ceremony.** Meet **Vesna** (loud, magnetic, *almost* mocking the ritual) and **Renn** (quiet, watchful — exchanges one loaded glance with you). The inner circle preside. *Mechanic: the compliance ritual* — a Simon-says/match-the-room beat where you copy the congregation's gestures/responses on cue. Cheap to build, deeply unsettling, and it teaches "obedience is the verb here." **Kassian (#5)** does something casually cruel during it that everyone treats as normal.
- **Return to the Booking.** First explicit unease. Establish the day/cycle loop you'll reuse forever.

*Systems proven this stage: movement, interaction, inventory basics, dialogue UI, the compliance mechanic, world flags, day-cycle scaffolding.*

### Stage 2 — Cracks  *(planning; choices start to matter)*

- **The compound opens up.** *Mechanic: exploration + information gathering.* Overheard conversations, documents, contraband — each sets a flag and feeds the objective tracker.
- **Vesna pushes, and survives it.** You watch her openly question the cult and *get away with it* (charisma as armour), which both emboldens you and frightens you — why is she allowed? She becomes your contraband/info source. *Mechanic: she gives you an item or a lead that opens a route.*
- **Renn — the trust mini-arc.** A series of careful exchanges where you can signal dissent or stay safe. *Mechanic: a hidden trust meter advanced by dialogue choices that now genuinely set flags.* Reach a threshold and Renn becomes an ally with their own access/skill — and unlocks an escape variant.
- **Edrin's backstory.** You learn he was groomed since childhood and is coddled/manipulated by Coll in real time. *Mechanic: a moral-grey branch* — you can mirror Coll's manipulation to use Edrin (effective, ugly), or genuinely reach him (harder, gentler). Either seeds a different Stage-3 option.
- **Halloran reveals himself.** *Mechanic: a perception puzzle* — across several scenes you notice his "madness" is inconsistent (a lucid aside, a hidden note, a dropped mask when no one's near). Once you see it, he becomes your engineer: he hands you a plan and a **crafting/gather objective** (collect components → he builds the tool/route). He's the kindest person here and the only one with a clear head.
- **The inner circle tighten:**
  - **The Archivist (#4)** gates a crucial fact behind **riddles** — solve them to unlock a route or a code.
  - **The Elder (#3)** — optional: read him correctly and he becomes a one-time **stealth bypass**; he won't *help*, but he'll fail to see you.
  - **The Steward (#2)** controls access to a key area; **avoid or trick** him (an item, a forged token, a timed distraction).
  - **Kassian (#5)** escalates the dread — you witness the wilder "activities" he drives for his own amusement, and he begins to *notice you*. *Mechanic: suspicion meter under real pressure* — curfews, restricted zones, patrols. Getting caught raises suspicion (soft fail), it doesn't end the run.
- **The crack becomes a fracture.** A trigger event makes escape urgent — e.g. Vesna abruptly "ascends"/vanishes, or you're scheduled for a deeper ritual. Halloran gives you the window. *End state: you have a plan, components, 0–2 allies, and a route.*

*Systems proven this stage: trust/flags, crafting, riddle + component puzzles, full stealth + suspicion, branching seeds.*

### Stage 3 — The Escape  *(payoff; the branches converge into a setpiece)*

Reuse Stage 2's spaces under a **curfew layout** (new patrols, locked routes, dark). Your "few approaches" are flag-driven recombinations, not separate levels:

- **Route A — Stealth (always available).** Halloran's timing-and-route plan. Pure stealth puzzle through the dark compound; the baseline path.
- **Route B — Ally-assisted.** If Renn's trust or Edrin's arc resolved well, an ally creates a diversion / opens a path — a different patrol pattern and a social beat. Bringing someone with you changes the ending.
- **Route C — Leverage.** Using the Archivist's riddle-knowledge or your manipulation of Edrin, you talk/trick your way through a gate that's otherwise a wall — tenser, riskier, fewer retries.
- **Kassian (#5) hunts.** He's the active threat — the climactic stealth setpiece is built around avoiding *him* specifically.
- **The First (#1).** The final threshold: a confrontation or a last test of nerve where the paranoid figurehead almost catches you out.

**Endings (keep to 2–4):** clean solo escape; escape with an ally (and the question of whether they make it); a pyrrhic version (you get out but leave someone behind — Edrin, Renn, Vesna); and a caught/bad ending. Decide which Stage-2 flags select which ending and *write that table down* before you build the finale, or this is where branching scope explodes.

---

## Part E — What to cut if you fall behind

In rough priority of "cut this first":

1. Route C (leverage) — fold into Route A/B.
2. The Elder's optional bypass.
3. Crafting depth — collapse "gather components" into "find one item."
4. Endings — ship two, not four.
5. Vesna's contraband sub-loop — keep her as catalyst/atmosphere only.

The irreducible core that still makes the game: the compliance ritual (Stage 1), the suspicion-pressured compound (Stage 2), Halloran's plan, Kassian as the hunter, and one clean escape with one meaningful ally choice. If you build *only* that, you have a finished game. Everything else is enrichment.

---

*Build the harness, prove the greybox slice, then let the characters pull the content into being one data file at a time.*
