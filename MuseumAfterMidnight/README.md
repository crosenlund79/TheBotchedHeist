# Museum After Midnight: The Museum Awakens

A third-person supernatural action game built in **Godot 4.6** from the Synty POLYGON packs:
Heist, Generic, Horror Mansion, Vikings, Samurai, Western, Sci-Fi City and Particle FX. You play
the night guard, locked in after closing, while the exhibits wake up. The `../TheHeist` project
and the animation showcase are untouched.

## Run it

Open `MuseumAfterMidnight/project.godot` in Godot 4.6 and press **Run** (F5). The first import
takes about a minute. The main scene is `res://Scenes/Museum.tscn`.

From a terminal:

```bash
godot --path MuseumAfterMidnight
```

A Web export preset (Compatibility renderer, single-threaded) is included:

```bash
godot --headless --path MuseumAfterMidnight --export-release "Web" build/index.html
```

## Controls

You can remap these under **Settings → Controls**.

| Input | Action |
|---|---|
| W A S D | Move (strafe / walk backward while aiming) |
| Shift | Sprint |
| C / Ctrl | Crouch (toggle) |
| Mouse | Look |
| Right mouse | Aim (over-the-shoulder) |
| Left mouse | Fire (rifle: automatic; handgun: semi-automatic) |
| R | Reload |
| 1 / 2 | Rifle / handgun |
| E | Interact (plaques, pickups, terminal, alarm, relics) |
| F | Weapon flashlight |
| V | Swap shoulder |
| Esc | Pause menu |
| F1 | Developer overlay |

## Zones

| Zone | Purpose |
|---|---|
| Main Hall · Viking Wing | Longship (walk all the way round), Stone Totem, Rune Stone, sacrificial altar, spear and shield, classical statues, reception desk, museum directory |
| Samurai Gallery | Figures, temple bell (ring it to lure monsters), weapons in cases |
| Occult Exhibition | Count and Witch, crystal ball (seance encounter), paintings that change, rocking chair, ritual candle circle, mirror |
| The Crypt | Coffins, caged skeleton, chandeliers, chains; the most dangerous zone |
| Wild West / Future City | The original galleries |
| Ancient Civilizations Wing | Sarcophagus of the Nameless King (cursed), tomb guardian, ceremonial masks, coin hoard, temple gold, burial jars, torches |
| Storage & Maintenance | Shelving and crate aisles, hiding nook, red emergency lighting, ammo and first aid |
| Security Office | CCTV terminal, live monitor wall, alarm button, status board, supplies; enemies never spawn here |

## Enemies

- **Possessed Exhibit:** a figure or classical statue that stands dormant until it wakes (you get close, you shoot it, a haunting event or a relic). Figures walk slowly and hit hard. Stone statues move only while you are not looking at them.
- **Haunted Staff:** night staff in Heist outfits. They patrol, investigate noise, alert, chase, attack, stagger when shot, lose sight of you, search and return to their route.
- **Supernatural Entity:** a translucent ghost. It hovers, phases (short teleport) and telegraphs its lunge with a rising glow and a shriek. It is briefly untouchable while phasing.
- **Nightmare Beast:** a fast, tough Horror Mansion monster that appears in later rounds.

Each round has a finite roster. Some enemies start the round, others arrive during it, and
relics can add a capped number of extra enemies. When every one is destroyed, a summary appears
and the next round starts on a countdown.

## CCTV

There are six cameras: four record (blinking red light) and two are live-only (green light).
Every 0.1 s the game snapshots the player, enemies and camera-only phantoms into one 90-second
buffer, along with timestamped events.

- **Replay:** a short picture-in-picture replay plays after you leave a recording camera's area.
- **Terminal:** the Security Office terminal plays back any camera with play/pause, ±5 s, rewind, speed and a scrub timeline. It also shows clip markers, museum status, alarm controls and an event log.
- **How playback works:** playback rebuilds puppets on their own render layer and never touches gameplay.
- **Ghost reveals:** phantoms from the "ghost silhouette" event are invisible to the player but appear on the recordings.

## Graphics presets

Low (the default) is laptop-friendly. Medium adds shadows, SSAO, glow and live office monitors.
High adds MSAA, SSIL, SSR and volumetric fog. Change it under Settings → Graphics or from the
pause menu.

## Tools

- `Tools/convert_synty_unity.py`: converts the selected Unity prefabs into `Assets/Imported/` and updates the manifest.
- `Assets/Generated/template_*.png`: generated effect sprites (muzzle flash, sparks, bullet hole, dust, wisp, static). Replace any of them with art of the same name to override it.
