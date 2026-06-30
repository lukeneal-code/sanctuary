"""Export the currently open .blend scene to a Godot-ready .glb.

Typical use (the .blend is opened by Blender, this script exports it):

    blender --background art_src/blender/crate.blend \
        --python tools/blender/export_glb.py --python-exit-code 1 \
        -- --out assets/models/crate.glb

Conventions live in blender_env.py.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_env as env  # noqa: E402

import bpy  # noqa: E402


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    extra = argv[argv.index("--") + 1:] if "--" in argv else []
    p = argparse.ArgumentParser(description="Export open scene to .glb")
    p.add_argument("--out", required=True, help="output .glb path")
    p.add_argument("--skip-validate", action="store_true")
    return p.parse_args(extra)


def main() -> None:
    args = parse_args()

    if not args.skip_validate:
        problems = env.validate_open_scene()
        if problems:
            print("EXPORT BLOCKED — asset validation failed:")
            for prob in problems:
                print("  - " + prob)
            raise SystemExit(1)

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=args.out,
        export_format="GLB",
        use_selection=False,
        export_apply=True,  # apply modifiers
        export_yup=True,  # Godot expects +Y up
    )
    print(f"EXPORT OK -> {args.out}")


if __name__ == "__main__":
    main()
