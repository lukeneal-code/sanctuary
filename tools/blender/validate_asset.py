"""Validate the open .blend against the project's asset conventions.

Exits non-zero (via --python-exit-code) if anything fails, so `make` and
Claude Code get a clear signal without needing to see the model.

    blender --background art_src/blender/crate.blend \
        --python tools/blender/validate_asset.py --python-exit-code 1 -- 
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_env as env  # noqa: E402


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    extra = argv[argv.index("--") + 1:] if "--" in argv else []
    p = argparse.ArgumentParser(description="Validate open scene")
    p.add_argument("--visual-budget", type=int, default=env.VISUAL_TRI_BUDGET)
    p.add_argument("--proxy-budget", type=int, default=env.PROXY_TRI_BUDGET)
    return p.parse_args(extra)


def main() -> None:
    args = parse_args()
    problems = env.validate_open_scene(args.visual_budget, args.proxy_budget)

    n_objs = len(env.mesh_objects())
    if problems:
        print(f"VALIDATE FAIL ({n_objs} mesh objects):")
        for prob in problems:
            print("  - " + prob)
        raise SystemExit(1)
    print(f"VALIDATE OK — {n_objs} mesh objects pass conventions.")


if __name__ == "__main__":
    main()
