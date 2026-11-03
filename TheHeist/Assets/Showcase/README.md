# Heist Animation Showcase

A small inspection scene that plays every retargeted Mixamo clip on the real Synty Heist characters. It has no gameplay.

## Open it

1. Open `TheHeist/project.godot` in **Godot 4.6** or newer. The first import takes a minute.
2. Press **Run** (F5). The showcase is the project's main scene: `res://Assets/Showcase/AnimationShowcase.tscn`.
   The original Synty demo is still available at `res://Assets/Synty/PolygonHeist/Scenes/Demo.tscn`.

## Controls

| Control | What it does |
|---|---|
| Character dropdown | Switches between the nine Synty Heist characters. The current clip carries on at the same point. |
| Clip buttons, grouped by category | Play that clip. Loops repeat; clips marked ¹ play once, then blend back to idle. Click again to restart. |
| Pause / Resume, Replay | Freeze or continue the clip; restart it from the beginning. |
| Speed slider | 0.1× to 2×. |
| Root motion switch | For clips that have a root-motion variant (walk, run, sneak, crouched walk), the character really travels and the camera follows. Off: the clip plays on the spot. Past 5 m from the centre the character is returned to the centre. **Re-centre** does that on demand. |
| Mouse drag (outside the panel) | Orbit the camera. Wheel or trackpad: zoom. |

Fire Rifle shows `SM_Wep_RifleSwat_01` between the hands, and Carry shows `SM_Prop_Box_01`. Neither clip contains a prop, so the showcase places them for inspection only.

## Files

| Path | Purpose |
|---|---|
| `AnimationShowcase.tscn` | The scene: lighting, a bank-vault stage built from Synty prefabs, the character spawn point and the camera rig. |
| `animation_showcase.gd` | Character switching, playback, root motion, props and the UI (built in code). |
| `orbit_camera.gd` | Third-person orbit camera that follows the character's hips. |
| `clip_catalog.gd` | Category, display name and loop flag for each clip id. Unknown clips go in "Other". |
| `Animations/heist_female_inplace.res` | Baked clips, in place. |
| `Animations/heist_female_rootmotion.res` | Baked clips with travel (and turn heading) on the Synty `Root` bone, for `AnimationMixer.root_motion_track`. |
| `Animations/bake_report.json` | What the last bake produced. |
| `tools/bake_animations.gd` | Re-bakes every FBX in `<repo>/Animations/Female`. |
| `tools/showcase_smoke_test.gd` | Automated check: plays every clip on every character and saves screenshots. |

## Adding or updating animations

Put the Mixamo FBX files ("without skin", any of the Female clips) in `<repo>/Animations/Female/`, then run this from the repository root:

```bash
godot --headless --path TheHeist -s res://Assets/Showcase/tools/bake_animations.gd
```

The bake does four things:
- It retargets every FBX in that folder onto the Synty skeleton. This is the baked method from `docs/asset-discovery/REPORT.md` section 9.
- It detects root motion, meaning horizontal hip travel over 0.25 m or a heading change over 30°.
- It skips a file whose clip duplicates one already baked.
- If a re-uploaded file under the same name differs from the previous bake, it keeps both versions, the new one as `<clip>_v2`.

Strafe, turn and hit-reaction clips already have categories in `clip_catalog.gd`, so they appear in the panel as soon as they are baked.
