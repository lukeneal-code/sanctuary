"""Validate and export every .blend in a source directory to .glb.

One Blender process opens each file in turn, validates it, and (if clean)
exports it to the assets/models tree mirroring the source layout.

    blender --background --python tools/blender/batch_export.py \
        --python-exit-code 1 -- \
        --src art_src/blender --out assets/models

If ANY file fails validation, nothing for that file is exported and the whole
run exits non-zero after reporting every failure.
"""

import argparse
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_env as env  # noqa: E402

import bpy  # noqa: E402


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    extra = argv[argv.index("--") + 1:] if "--" in argv else []
    p = argparse.ArgumentParser(description="Batch export .blend -> .glb")
    p.add_argument("--src", default="art_src/blender")
    p.add_argument("--out", default="assets/models")
    return p.parse_args(extra)


def main() -> None:
    args = parse_args()
    blends = sorted(glob.glob(os.path.join(args.src, "**", "*.blend"), recursive=True))
    if not blends:
        print(f"No .blend files under {args.src} — nothing to do.")
        return

    failures: list[str] = []
    exported = 0

    for blend in blends:
        bpy.ops.wm.open_mainfile(filepath=blend)
        rel = os.path.relpath(blend, args.src)
        out = os.path.join(args.out, os.path.splitext(rel)[0] + ".glb")

        problems = env.validate_open_scene()
        if problems:
            for prob in problems:
                failures.append(f"{rel}: {prob}")
            print(f"SKIP {rel} (failed validation)")
            continue

        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        bpy.ops.export_scene.gltf(
            filepath=out,
            export_format="GLB",
            use_selection=False,
            export_apply=True,
            export_yup=True,
        )
        exported += 1
        print(f"OK   {rel} -> {out}")

    print(f"\nBatch done: {exported} exported, {len(failures)} failed.")
    if failures:
        print("Failures:")
        for f in failures:
            print("  - " + f)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
