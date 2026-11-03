# Discovery tooling

Scripts used to produce the catalogue. Run them against an extracted copy of the archives, never the originals.

- `audit.gd`: loads and instantiates every `.tscn` and dumps meshes, materials, skeletons, animations, particles and dependencies as JSON (`AUDIT_OUT=out.json godot --headless --path <project> -s audit.gd -- res://Assets`).
- `render.gd`: renders a preview PNG per scene (`model` / `fx` / `scene` modes).
- `tests.gd`, `states.gd`: functional checks (skinning, mask bone attachment, animation playback, FX in the Demo lobby, hinged sub-parts).
- `fxanim.gd`: frame sequences for the animated FX previews.
- `meta.py`: visual identification of each model, written from the renders.
- `build_data.py` + `assemble.py` + `template.html` + `report.md`: build `catalogue.html`, `REPORT.md` and `inventory.csv`.

Environment used: Godot 4.6-stable (Linux), with Forward+ on Mesa lavapipe (Vulkan) and Compatibility on llvmpipe (OpenGL), under Xvfb.
