# Museum After Midnight

A first visual and technical prototype: an explorable night-time museum built from Synty assets in **Godot 4.6** (Forward+). It has no enemies, objectives or progression. The Heist experiment in `../TheHeist` is untouched.

## Run it

Open `MuseumAfterMidnight/project.godot` in Godot 4.6 or newer and press **Run** (F5). The first import takes about a minute. The main scene is `res://Scenes/Museum.tscn`.

## Controls

| Input | Action |
|---|---|
| W A S D | Move |
| Shift | Run |
| Mouse | Look (third-person camera; click to recapture the mouse) |
| Esc | Menu: resume, graphics preset, quit |

## What's in it

- **Entrance hall (20 × 15 m, 6 m high):**
  - glass facade onto a night street, with a parked police car's lights flashing outside;
  - skylights with a moonbeam;
  - a Viking longship centrepiece behind rope barriers, Viking figures, rune stones, shields and classical statues.
- **Four galleries off the hall:**
  - **Samurai**: warrior, ninja and geisha figures; temple bell; guardian lions; weapons in glass cases; paper lanterns.
  - **House of Horrors**: the Count and the Witch, a coffin, an anatomy skeleton, portraits, a crystal ball and a grandfather clock.
  - **The Wild West**: stagecoach, sheriff and cowgirl, saloon piano, firearms in cases, saloon signs.
  - **Future City**: hover bike, cop, robot and hacker figures, drones, neon signs, a vending machine.
- **Every exhibit:**
  - a stone plinth with a brass edge, or a low dais;
  - a spotlight;
  - a placard naming the object and its Synty pack;
  - small objects sit in Synty glass display cases.
- **Animated figures:** all costumed figures play the idle clip from the Heist Mixamo pipeline. The Synty rig is shared across packs, so no new retargeting was needed.
- **Player:** a Synty Heist character (`SM_Chr_Female_Overall_01`) with the baked Mixamo idle, walk and run clips. Movement speed matches the clips' measured root speed, so the feet don't slide.

## Security cameras

There are two ceiling cameras (Synty Heist CCTV prop with a blinking red light), in the **Wild West** and **Future City** galleries.
- While you are inside a camera's gallery, it records your position, facing and animation state 30 times a second.
- About a second after you leave, the view cuts to that camera's fixed viewpoint.
- It replays the last 3–5 seconds with a ghost copy of your character.
- The overlay shows a blinking `● REC`, a date and time stamp, the camera name and a playback countdown.
- Gameplay then resumes automatically.

No video is encoded; the replay re-enacts the recorded transforms.

## Graphics presets

The preset applies immediately from the Esc menu, defaults to **Low**, and is saved in `user://settings.cfg`.

| | Low (laptop) | Medium | High |
|---|---|---|---|
| 3D resolution | 67 % (FSR 1) | 85 % (FSR 1) | 100 % |
| Anti-aliasing | FXAA | FXAA | MSAA 4× |
| Shadows | none | key lights (moon, centrepieces, street), 2048 atlas | all exhibit spotlights, 4096 atlas, soft high |
| Effects | fog only; decorative fill lights off | + SSAO, glow, fill lights | + SSAO high, SSIL, SSR, volumetric fog |

## Imported Synty assets

**Godot-native (copied from the Heist project):**
- POLYGON Heist: building kit (walls, floors, ceilings, skylights, pillars, glass facade, street), display cases, rope barriers, plants, CCTV prop, police car, and the player character.
- Particle FX: dust motes, sun beam, candle flame.
- The baked Mixamo animation library from `TheHeist/Assets/Showcase`.

**Converted from `ModelProject/SyntyUnity.zip` (Unity packs):** 78 prefabs, 79 FBX files, 25 materials and 21 textures (32 MB).

| Pack | Prefabs | Characters |
|---|---:|---:|
| Western | 14 | 2 |
| Samurai | 15 | 3 |
| Vikings | 13 | 2 |
| Horror Mansion | 15 | 2 |
| Sci-Fi City | 15 | 3 |
| Generic | 6 | 1 |

`Tools/convert_synty_unity.py` did the conversion; it runs outside Godot against the extracted zip:
- it parses each Unity prefab, including nested prefabs and inactive objects;
- it resolves meshes and materials through Unity GUIDs;
- it converts Synty's `Generic_Basic` and Standard materials to `StandardMaterial3D` (albedo, tint, alpha clip, multiplied emission, glass);
- it copies only the files needed;
- it writes `Assets/Imported/imported_manifest.json`.

`Scripts/exhibit_factory.gd` then builds each prefab in Godot:
- it shows only the meshes the prefab shows and applies its materials;
- it merges character attachments onto the body's skeleton, or onto the head bone for rigid ones;
- it adds the idle animation.

To change the selection, edit `SELECTION` in the converter and re-run it:

```bash
python3 Tools/convert_synty_unity.py <extracted SyntyUnity.zip>/Synty
```

## Known limitations

- The Unity FBX files reference Synty's local `.psd` texture paths, so the first import prints texture-not-found messages. They are harmless; the converted materials supply the textures.
- Figures from the five 49-bone Unity rigs animate with relaxed fingers: their finger bones have no `_L`/`_R` names, so those tracks are skipped.
- Synty's special shaders (Horror grunge, Sci-Fi triplanar) aren't recreated; the converted materials use the base palette textures.
- This is a prototype: there are no audio, interactions or collision on wall-hung pieces.
