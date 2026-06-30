# Sanctuary — dev harness.
# Override binaries if they aren't on PATH:
#   make smoke  GODOT=/path/to/Godot_v4.x
#   make assets BLENDER=/path/to/blender
GODOT ?= godot
BLENDER ?= blender
SRC := scripts tests

# Blender runs headless; --python-exit-code 1 makes a script exception fail the
# build, which is how the validator's `raise SystemExit(1)` reaches make.
BLENDER_RUN := $(BLENDER) --background --python-exit-code 1
ART_SRC := art_src/blender
MODELS := assets/models

.PHONY: help test smoke lint format run check assets validate-assets gen-examples

help:
	@echo "Game loop:"
	@echo "  make smoke           - boot core loop headless, assert, exit 0 on success"
	@echo "  make test            - run headless unit tests (exit 0 = pass)"
	@echo "  make lint / format   - gdlint / gdformat --check (needs gdtoolkit)"
	@echo "  make run             - launch the game (human only)"
	@echo "  make check           - lint + format + test + smoke (pre-commit gate)"
	@echo "Assets (Blender):"
	@echo "  make assets          - validate + export every .blend in art_src -> assets/models"
	@echo "  make validate-assets - validate every .blend without exporting"
	@echo "  make gen-examples    - regenerate the procedural crate + wall examples"

smoke:
	$(GODOT) --headless --path . res://tests/smoke/smoke.tscn

test:
	$(GODOT) --headless --path . res://tests/test_runner.tscn

lint:
	gdlint $(SRC)

format:
	gdformat --check --diff $(SRC)

run:
	$(GODOT) --path .

check: lint format test smoke
	@echo "All checks passed."

# --- Blender asset pipeline --------------------------------------------------

assets:
	$(BLENDER_RUN) --python tools/blender/batch_export.py -- --src $(ART_SRC) --out $(MODELS)

validate-assets:
	@for f in $$(find $(ART_SRC) -name '*.blend'); do \
		echo "validating $$f"; \
		$(BLENDER_RUN) "$$f" --python tools/blender/validate_asset.py -- || exit 1; \
	done

gen-examples:
	$(BLENDER_RUN) --python tools/blender/gen_props.py -- --kind crate --out $(MODELS)/crate.glb --save-blend
	$(BLENDER_RUN) --python tools/blender/gen_props.py -- --kind wall  --out $(MODELS)/wall.glb  --save-blend
