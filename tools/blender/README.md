# Blender asset pipeline

This folder is the bridge between Blender and the Godot project. It exists to
fold the *automatable* parts of asset creation into the Claude Code loop while
leaving the artful modelling to you.

## The division of labour

- **You model.** Anything that needs eyes and taste — silhouettes, organic
  shapes, hero props, hand-tuned UVs — happens in Blender, by you.
- **Claude owns the code around the model.** Procedural geometry-as-code,
  batch export with conventions baked in, and validation. None of that needs to
  *see* anything, so the agent can do it reliably and you can review the diffs.

The thing that makes this work is the **validator**: it turns "is this asset
correct?" into a text pass/fail with an exit code, which is the same kind of
signal `make test` gives for code. Without it the agent would be flying blind.

**Textures live on the Godot side.** Environment surfaces are textured by the
PSX texture catalogue (`data/textures/textures.json` + `TextureCatalog`, see
`CLAUDE.md`), not baked into `.glb` here — Blender materials stay flat-colour
(`add_basic_material`) for now. Model-baked textures are a separate, later path.

## Layout

```
art_src/blender/      source .blend files (you edit these; git-tracked)
art_src/.gdignore     makes Godot skip the source tree (we ship .glb, not .blend)
assets/models/        exported .glb (Godot imports these)
tools/blender/
  blender_env.py      conventions + helpers + the validator (shared)
  export_glb.py       export the open .blend -> .glb
  validate_asset.py   validate the open .blend
  batch_export.py     validate + export every .blend in a folder
  gen_props.py        procedural generator example (crate + wall)
```

## Commands

All Blender invocations run headless. Override the binary with
`BLENDER=/path/to/blender` if it isn't on your PATH.

```
make assets           # validate + export every .blend in art_src -> assets/models
make validate-assets  # validate only, no export
make gen-examples     # regenerate the procedural crate + wall examples
```

Under the hood they call Blender like:

```
blender --background <file.blend> --python tools/blender/validate_asset.py \
    --python-exit-code 1 --
```

`--python-exit-code 1` is what lets the validator's `raise SystemExit(1)` fail
the build. Without it, Blender exits 0 even when a script raises.

## Conventions (enforced by the validator)

Edit budgets and rules in `blender_env.py`.

- **Scale:** 1 Blender unit = 1 metre.
- **Transforms applied:** object scale `(1,1,1)`, rotation `0` before export.
- **Orientation:** exported with +Y up (Godot's convention).
- **UVs:** every visual mesh has at least one UV map.
- **Tri budget:** visual meshes stay under `VISUAL_TRI_BUDGET` (default 3000);
  collision proxies under `PROXY_TRI_BUDGET` (default 500).
- **Names:** node-safe (`A-Z`, `0-9`, `_`, no spaces) — names become Godot node
  names.
- **Collision / nav are separate proxy objects** whose names end in a Godot
  import suffix, parented to the visual mesh:

  | suffix         | Godot result                                  |
  |----------------|-----------------------------------------------|
  | `-col`         | keep mesh, add concave (trimesh) collision     |
  | `-convcol`     | keep mesh, add convex collision                |
  | `-colonly`     | replace mesh with concave collision            |
  | `-convcolonly` | replace mesh with convex collision             |
  | `-rigid`       | rigid body                                     |
  | `-navmesh`     | navigation mesh                                |
  | `-noimp`       | skipped on import                              |

  Use convex (`-convcol*`) for boxy/convex props (cheaper); concave
  (`-col*`) for static level geometry that needs exact shape.

## Geometry-as-code (the high-leverage path)

For a modular, PSX-style cult building, a lot of geometry is parametric. Author
it as code in `gen_props.py`, re-run on tweaked parameters, and it always
validates and exports cleanly. The shipped examples:

```
make gen-examples
# -> assets/models/crate.glb  (0.8x0.8x1.0 m, convex collision proxy)
# -> assets/models/wall.glb   (4x3 m panel, trimesh collision proxy)
# and editable sources saved into art_src/blender/
```

Add a new piece by writing a `build_<kind>()` function using the `add_box`,
`add_basic_material`, and `add_box_collision` helpers, then registering it in
the `BUILDERS` dict. Ask Claude to do exactly that.

## Interactive option: the Blender MCP connector

Separate from this scripted backbone, you can connect a chat-side Claude to a
**live** Blender session over a socket (Model Context Protocol). It can read the
scene (objects, materials, modifier stacks), run Python in your session, and
iterate in natural language. The error-loops-back-to-Claude debugging is the
genuinely useful part.

- Prefer the **official Blender connector** built by the Blender developers and
  shipped with Claude for Creative Work (Blender 4.2+); there are also community
  servers (e.g. `ahujasid/blender-mcp`). Check each project's current setup docs
  rather than trusting a snapshot here — setup details move.
- Realistic expectations (community consensus): strong for hard-surface,
  architectural, rule-based work — which is most of this game — and weak for
  organic/character modelling and final production quality. It needs Blender
  open with the addon active, and it executes generated code in your session,
  so run it on a machine without sensitive data if that worries you.

Treat MCP as a cockpit for interactive blockouts and edits; keep `make assets`
as the deterministic, version-controlled source of truth for what ships.
