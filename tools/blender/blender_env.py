"""Shared Blender (bpy) helpers for the Sanctuary asset pipeline.

Runs INSIDE Blender's Python (via `blender --background --python <script>`),
never as plain CPython. Holds the project's asset conventions in one place so
the export, validate, batch, and generator scripts all agree.

Conventions
-----------
- 1 Blender unit == 1 metre. Export with +Y up (Godot's convention).
- Object transforms are applied before export (scale == 1, rotation == 0).
- Visual meshes have at least one UV map.
- Collision / nav proxies are SEPARATE objects whose names end in a Godot
  import suffix; Godot turns them into the right body/shape on import.

Godot mesh-name suffixes we honour (Godot 4 glTF import):
    -col          keep mesh, add concave (trimesh) static collision
    -convcol      keep mesh, add convex static collision
    -colonly      replace mesh with concave static collision
    -convcolonly  replace mesh with convex static collision
    -rigid        rigid body
    -navmesh      navigation mesh
    -noimp        skip on import
"""

import math
import re

import bmesh
import bpy
from mathutils import Vector

# --- conventions -------------------------------------------------------------

UNIT_METRES = 1.0

# Per-object triangle budgets for the PSX low-poly look. Tune freely.
VISUAL_TRI_BUDGET = 3000
PROXY_TRI_BUDGET = 500

COLLISION_SUFFIXES = (
    "-col",
    "-convcol",
    "-colonly",
    "-convcolonly",
    "-rigid",
    "-navmesh",
)
RECOGNISED_SUFFIXES = COLLISION_SUFFIXES + ("-noimp",)

# Object names should be node-safe: letters, digits, underscores, plus an
# optional recognised suffix. No spaces (they survive into Godot node names).
_NAME_BODY = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")


# --- introspection -----------------------------------------------------------


def mesh_objects():
    return [o for o in bpy.data.objects if o.type == "MESH"]


def suffix_of(name: str):
    for suf in RECOGNISED_SUFFIXES:
        if name.endswith(suf):
            return suf
    return None


def is_proxy(name: str) -> bool:
    return suffix_of(name) in COLLISION_SUFFIXES


def tri_count(obj) -> int:
    """Triangle count of the mesh as it would export (ngons counted as fan)."""
    return sum(max(len(p.vertices) - 2, 0) for p in obj.data.polygons)


def has_uv(obj) -> bool:
    return len(obj.data.uv_layers) > 0


def transforms_applied(obj, tol: float = 1e-3) -> bool:
    s = obj.scale
    r = obj.rotation_euler
    scale_ok = all(abs(c - 1.0) < tol for c in s)
    rot_ok = all(abs(a) < tol for a in r)
    return scale_ok and rot_ok


def name_ok(name: str) -> bool:
    body = name
    suf = suffix_of(name)
    if suf:
        body = name[: -len(suf)]
    return bool(_NAME_BODY.match(body))


# --- the validator (the feedback signal Claude reads) ------------------------


def validate_open_scene(
    visual_budget: int = VISUAL_TRI_BUDGET,
    proxy_budget: int = PROXY_TRI_BUDGET,
) -> list[str]:
    """Return a list of human-readable problems. Empty list == pass."""
    problems: list[str] = []
    objs = mesh_objects()
    if not objs:
        problems.append("scene has no mesh objects to export")
        return problems

    for obj in objs:
        n = obj.name
        if not name_ok(n):
            problems.append(f"{n}: name not node-safe (no spaces; A-Z, 0-9, _)")
        if not transforms_applied(obj):
            problems.append(f"{n}: transforms not applied (scale {tuple(round(c, 3) for c in obj.scale)})")

        tris = tri_count(obj)
        if is_proxy(n):
            if tris > proxy_budget:
                problems.append(f"{n}: collision proxy is {tris} tris (budget {proxy_budget})")
        else:
            if tris > visual_budget:
                problems.append(f"{n}: {tris} tris over visual budget {visual_budget}")
            if not has_uv(obj):
                problems.append(f"{n}: visual mesh has no UV map")
    return problems


# --- geometry-as-code helpers (used by the generator) ------------------------


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def add_box(name: str, size: Vector, location: Vector = Vector((0, 0, 0))):
    """Create a unit cube, scale to `size` (metres), apply, return the object."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    apply_transforms(obj)
    return obj


def apply_transforms(obj) -> None:
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def add_basic_material(obj, name: str, rgb=(0.55, 0.5, 0.42)) -> None:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Roughness"].default_value = 0.9
    obj.data.materials.append(mat)


def add_box_collision(visual, suffix: str = "-colonly") -> object:
    """Add a box collision proxy sized to `visual`'s bounds, parented to it."""
    assert suffix in COLLISION_SUFFIXES, f"unknown collision suffix {suffix}"
    bb = [Vector(c) for c in visual.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    size = hi - lo
    centre = (hi + lo) * 0.5
    proxy = add_box(visual.name + suffix, size, visual.matrix_world @ centre)
    proxy.parent = visual
    proxy.matrix_parent_inverse = visual.matrix_world.inverted()
    return proxy
