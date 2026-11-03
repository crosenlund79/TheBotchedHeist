# Museum After Midnight

A lightweight **haunted-museum shooter** built from Synty assets in **Godot 4.6** (Forward+). Explore the museum after dark, shoot the Horror Mansion monsters roaming the galleries, clear the museum and survive the next, slightly harder round. The Heist experiment in `../TheHeist` is untouched.

## Run it

Open `MuseumAfterMidnight/project.godot` in Godot 4.6 or newer and press **Run** (F5). The first import takes about a minute. The main scene is `res://Scenes/Museum.tscn`.

## Controls

| Input | Action |
|---|---|
| W A S D | Move |
| Shift | Run |
| Mouse | Look and aim (crosshair at screen centre; click to recapture the mouse) |
| Left mouse button | Shoot (hold for automatic fire) |
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

## Haunted museum

- **The Crypt:** a new 20 × 10 m room behind the Samurai and Horror galleries, through doors marked "THE CRYPT".
  - Coffins under a flickering chandelier, a swaying skeleton in a cage, specimen jars, a bird cage and an exorcist cross.
  - Candle stands with flames, hanging chains, skulls, barrels and crates, and spider webs in the corners.
  - Built from Horror Mansion and Generic assets.
- **Atmosphere:**
  - flickering lamps, candles and the chandelier, with irregular dips and drop-outs;
  - cold green ambient light and denser fog (volumetric on High);
  - spider webs in the hall and the Horror gallery.

## Monsters and combat

- **Monsters:** Horror Mansion characters: Werewolf, Demon (with tail), Ghoul, Witch, Butcher, Yokai, Gimp and the Count.
  - Each has its own health, speed, damage and glowing eyes.
  - They animate with the baked Mixamo clips from the Heist pipeline: idle, walk/sneak to wander, run to chase, a lunging strike, and kneel-and-sink on death.
- **AI:**
  - idle and wander near their spawn point;
  - notice you by line of sight or when you fire nearby;
  - chase you through doorways along a navigation mesh baked at startup from the museum's collision;
  - attack in melee.
- **Gun:** the Heist pistol in the player's right hand.
  - Shots go through the crosshair; the arms raise into an aim pose (an upper-body overlay of the "Firing Rifle" clip) while firing.
  - Effects: muzzle flash and light, tracer, impact sparks, blood-red hits on monsters, a hit marker (red for headshots, which do double damage) and a procedural gunshot sound.
- **Health:** 100. Monster hits flash the screen red.
  - At zero: "YOU DIED", a kneeling death, then respawn at the entrance with full health and 2.5 s of invulnerability.
- **Rounds:**
  - the HUD shows the round and remaining monsters;
  - when all are dead, "MUSEUM CLEARED!" appears and the next round starts after 5 s;
  - each round adds one monster (6 → 10) and raises monster health and damage by 10 % and speed by 4 %, capped at round 6.

Sounds are synthesised in code (gunshot, hits, growls, deaths), because the Synty packs contain no audio.

## Security cameras

There are two ceiling cameras (Synty Heist CCTV prop with a blinking red light), in the **Wild West** and **Future City** galleries.
- While you are inside a camera's gallery, it records your position, facing and animation state 30 times a second.
- About a second after you leave, the view cuts to that camera's fixed viewpoint.
- It replays the last 3–5 seconds with a ghost copy of your character.
- The overlay shows a blinking `● REC`, a date and time stamp, the camera name and a playback countdown.
- Gameplay then resumes automatically. Monsters freeze and the combat HUD hides during a replay.

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

**Converted from `ModelProject/SyntyUnity.zip` (Unity packs):** 104 prefabs, 100 FBX files, 26 materials and 22 textures.

| Pack | Prefabs | Characters |
|---|---:|---:|
| Western | 14 | 2 |
| Samurai | 15 | 3 |
| Vikings | 13 | 2 |
| Horror Mansion | 35 | 8 |
| Sci-Fi City | 15 | 3 |
| Generic | 12 | 1 |

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
- This is a prototype: there are no audio files (sounds are procedural), and no collision on wall-hung pieces.
- Monsters use the female Mixamo clips; their attack is a sped-up section of "Button Pushing", since no attack or hit-reaction clips exist yet.
