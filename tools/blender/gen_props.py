"""Procedural low-poly prop generator — the 'geometry as code' pattern.

For a PSX-style, modular cult building, a lot of geometry is parametric: crates,
wall panels, doorframes, pallets, ducting. Claude can author these as code,
re-run on tweaked parameters, and they always validate and export cleanly.

This file ships two examples (a crate and a wall panel) to demonstrate the
pattern, including auto-generated collision proxies with the right Godot
suffixes. Add your own kinds the same way.

    blender --background --python tools/blender/gen_props.py \
        --python-exit-code 1 -- --kind crate --out assets/models/crate.glb

Pass --save-blend to also write the editable source into art_src/blender.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_env as env  # noqa: E402

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402


def build_crate() -> None:
    """A 0.8 x 0.8 x 1.0 m crate. Convex, so a convex collision proxy fits."""
    crate = env.add_box("Crate", Vector((0.8, 0.8, 1.0)), Vector((0, 0, 0.5)))
    env.add_basic_material(crate, "CrateWood", rgb=(0.45, 0.32, 0.18))
    env.add_box_collision(crate, "-convcolonly")


def build_wall() -> None:
    """A 4 x 3 m wall panel, 0.2 m thick. Static level geometry -> trimesh."""
    wall = env.add_box("Wall", Vector((4.0, 0.2, 3.0)), Vector((0, 0, 1.5)))
    env.add_basic_material(wall, "WallConcrete", rgb=(0.5, 0.49, 0.47))
    env.add_box_collision(wall, "-colonly")


BUILDERS = {
    "crate": build_crate,
    "wall": build_wall,
}


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    extra = argv[argv.index("--") + 1:] if "--" in argv else []
    p = argparse.ArgumentParser(description="Generate a low-poly prop")
    p.add_argument("--kind", required=True, choices=sorted(BUILDERS.keys()))
    p.add_argument("--out", required=True, help="output .glb path")
    p.add_argument("--save-blend", action="store_true", help="also save .blend source")
    return p.parse_args(extra)


def main() -> None:
    args = parse_args()
    env.reset_scene()
    BUILDERS[args.kind]()

    problems = env.validate_open_scene()
    if problems:
        print("GENERATED ASSET FAILED VALIDATION:")
        for prob in problems:
            print("  - " + prob)
        raise SystemExit(1)

    if args.save_blend:
        blend_path = os.path.join("art_src", "blender", args.kind + ".blend")
        os.makedirs(os.path.dirname(blend_path), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(blend_path))
        print(f"SAVED  {blend_path}")

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=args.out,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_yup=True,
    )
    print(f"GEN OK -> {args.out}")


if __name__ == "__main__":
    main()
