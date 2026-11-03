# The Heist: 3D Asset Discovery Report

Inspection only: no game code was written and the archives were not modified. Browse the visual catalogue in `catalogue.html` (self-contained; open it in a browser).

## Summary

Both archives are **native Godot 4 projects**, not raw source art. `TheHeist.zip` is Synty's *POLYGON Heist* pack converted to Godot (project label `4.6`, Forward+, Jolt Physics). `ParticleFX.zip` is Synty's *Particle FX* sample pack (project label `4.5`, Forward+). Both were imported with the official **Godot 4.6-stable** Linux build.

All 264 model prefabs, both demo scenes and all 13 particle prefabs import, instantiate and render with **zero errors**. The two packs also work together in one project. The biggest gaps:

- **No animation.** The 9 characters are properly rigged and skinned (50-bone humanoid skeleton) but come with no usable clips.
- **No audio, no custom shaders, no scripts** in either archive.
- **One FX prefab needs a fix.** `FX_Smoke_01` disappears in Forward+ because of a bad turbulence setting.

## 1. Totals

| Asset type | Count | Notes |
|---|---:|---|
| Model prefabs (`.tscn`) | **264** | 9 characters + 255 static props and kit pieces |
| Distinct mesh resources | 353 | 343 `.res` static meshes + 10 skinned `.mesh` (9 outfits + duffel-bag strap) |
| Sub-part meshes inside prefabs | 87 | Lids, doors, wheels, rotors, glass, gun mags/slides, broken-glass variants |
| Unused meshes | 1 | `Item_Swat_Glass.res` (SWAT goggle lens), not referenced by any prefab |
| Collision shapes | 6 shared + per-prefab | Convex/box/concave/sphere on every static prefab; capsule on characters |
| Particle effects | **13** prefabs, 18 emitters | All `GPUParticles3D` + `ParticleProcessMaterial` |
| Demo / overview scenes | 3 | Heist `Demo.tscn` (dressed bank lobby), Heist `Overview.tscn`, FX `Overview.tscn` |
| Animation clips | **0 usable** | One imported clip `Take 001` (8.3 s, 150 tracks): every track has 1 key, so it is a static pose |
| Skeletons | 1 rig type | 50 bones (Synty humanoid naming: `Hips`, `Spine_01..03`, `Shoulder_L`, `Elbow_L`, `Hand_L`, fingers, `Jaw`, `Eyes`…) |
| Materials | 24 Heist + 11 FX | All `StandardMaterial3D`. Heist uses 11 of its 24; the rest are colour-swap variants |
| Textures | 21 Heist + 6 FX | 1024² palette atlases (4 sets × A/B/C variants), 512² mask skins, 2560² 10×10 fire flipbook |
| Shaders | 0 | No `.gdshader` / `.shader` files |
| Audio | 0 | No audio files of any kind |
| Scripts | 0 | No `.gd`, C# or plugins; no addons required |
| Source art | 1 FBX | Only `Characters.fbx` (1.5 MB). The 256 static FBX sources are absent; only `.unwrap_cache` stubs and the extracted `.res` meshes remain |

**Formats and versions:** Godot text scenes `format=3` (`unique_id` node attributes, a 4.6 feature), binary `ArrayMesh` `.res`/`.mesh`, `.tres` materials, PNG/TGA/SVG textures with `.import` sidecars (VRAM-compressed). Use **Godot 4.6 or newer**. The Heist scenes use 4.6-only syntax, so older 4.x editors will at best drop data. The FX pack targets 4.5 and loads cleanly in 4.6.

## 2. Categorised model inventory

The full per-model table (filename, what it is, heist use, textures and materials, skeleton/animation, completeness, confidence, status, triangle count, sub-parts) is in the **Models** tab and in `inventory.csv`. Summary:

| Category | Count | Models |
|---|---:|---|
| Building Kit / Doors & Vault | 4 | `Env_Door_01`, `Env_Door_02`, `Env_Door_03`, `Env_VaultDoor_Frame_01` |
| Building Kit / Floors, Ceilings & Roof | 19 | `Env_Ceiling_01`, `Env_Ceiling_02`, `Env_Ceiling_03`, `Env_Ceiling_04`, `Env_Ceiling_05`, `Env_Ceiling_06`, `Env_Ceiling_07`, `Env_Ceiling_08`*, `Env_Ceiling_Light_01`*, `Env_Ceiling_Light_02`, `Env_Ceiling_Light_03`, `Env_Floor_01`, `Env_Floor_02`, `Env_Roof_01`, `Env_Roof_02`, `Env_Roof_03`, `Env_Roof_04`, `Env_Roof_05`, `Env_Skylight_01` |
| Building Kit / Stairs & Railings | 7 | `Env_Railing_01`, `Env_Stairway_01`, `Env_Steps_01`, `Env_Steps_02`, `Env_Steps_03`, `Env_Steps_04`, `Env_Steps_Edge_01`* |
| Building Kit / Street | 3 | `Env_Road_01`, `Env_Sidewalk_01`, `Env_Sidewalk_Straight_01` |
| Building Kit / Walls & Pillars | 43 | `Env_Pillar_01`, `Env_Pillar_02`, `Env_Pillar_Exterior_01`, `Env_Pillar_Exterior_02`, `Env_Pillar_Exterior_03`, `Env_Pillar_Exterior_04`, `Env_Pillar_Exterior_Floor_01`, `Env_Pillar_Exterior_Floor_02`, `Env_Pillar_Exterior_Floor_03`, `Env_Pillar_Exterior_Floor_04`, `Env_Pillar_Interior_01`, `Env_Pillar_Interior_02`, `Env_Pillar_Interior_03`, `Env_Pillar_Interior_04`, `Env_VaultGate_Door_01`, `Env_VaultGate_Frame_01`, `Env_VaultGate_Wall_01`, `Env_Wall_Exterior_01`, `Env_Wall_Exterior_Door_01`, `Env_Wall_Exterior_DoubleDoor_01`, `Env_Wall_Exterior_Ground_01`, `Env_Wall_Exterior_Window_01`, `Env_Wall_Exterior_Window_02`, `Env_Wall_Exterior_Window_Ground_01`, `Env_Wall_Exterior_Window_Ground_02`, `Env_Wall_Glass_01`, `Env_Wall_Glass_DoorFrame_01`, `Env_Wall_Glass_Ground_01`, `Env_Wall_Interior_01`, `Env_Wall_Interior_Door_01`, `Env_Wall_Interior_Door_01_Alt_01`, `Env_Wall_Interior_Door_01_Alt_02`, `Env_Wall_Interior_Door_01_Alt_03`, `Env_Wall_Interior_Door_01_Alt_04`, `Env_Wall_Interior_DoubleDoor_01`, `Env_Wall_Interior_DoubleDoor_Alt_01`, `Env_Wall_Interior_Ground_01`, `Env_Wall_Interior_Window_01`, `Env_Wall_Interior_Window_02`, `Env_Wall_Interior_Window_Ground_01`, `Env_Wall_Interior_Window_Ground_02`, `Env_Wall_Window_Blinds_01`, `Env_Wall_Window_Panels_01` |
| Characters | 9 | `Chr_Female_FBI_01`, `Chr_Female_Overall_01`, `Chr_Female_Shirt_01`, `Chr_Female_SuitVest_01`, `Chr_Male_FBI_01`, `Chr_Male_Overall_01`, `Chr_Male_SWAT_01`, `Chr_Male_Shirt_01`, `Chr_Male_SuitVest_01` |
| Decor & Signage | 16 | `Prop_Flag_Pole_01`, `Prop_Flag_Straight_01`, `Prop_Flag_Wall_01`, `Prop_Flag_Wall_02`, `Prop_Pillar_01`, `Prop_Pillar_02`, `Prop_Plant_01`, `Prop_Plant_02`, `Prop_Plant_03`, `Prop_Rug_01`, `Prop_Rug_02`, `Prop_Sign_Bank_01`, `Prop_Sign_Base_01`*, `Prop_Sign_Jewellery_01`, `Prop_Sign_Money_Bank_01`, `Prop_Statue_01` |
| Furniture & Office | 28 | `Prop_AirVent_01`, `Prop_Aircon_01`, `Prop_Bin_01`, `Prop_Box_01`, `Prop_CoffeTable_01`, `Prop_CoffeeTable_02`, `Prop_Computer_01`, `Prop_Computer_Keyboard_01`, `Prop_Computer_Mouse_01`*, `Prop_Computer_Screen_01`, `Prop_Couch_01`, `Prop_Couch_02`, `Prop_DeskLight_01`, `Prop_Desk_01`, `Prop_Desk_02`, `Prop_Desk_03`, `Prop_Drawers_01`, `Prop_Folder_01`, `Prop_Folder_02`, `Prop_Folder_03`, `Prop_Folder_04`*, `Prop_Folder_05`, `Prop_Seat_01`, `Prop_Seat_02`, `Prop_Shelf_01`, `Prop_Table_01`, `Prop_Table_02`*, `Prop_WaterCooler_01` |
| HUD Crosshairs | 6 | `Wep_Crosshair_01`, `Wep_Crosshair_02`, `Wep_Crosshair_03`, `Wep_Crosshair_04`, `Wep_Crosshair_05`, `Wep_Crosshair_Sniper_01` |
| Items & Tools | 25 | `Item_AmmoPack_01`, `Item_AmmoPack_02`, `Item_Bomb_01`, `Item_Briefcase_01`, `Item_Briefcase_02`, `Item_Crowbar_01`, `Item_DuffleBag_01`, `Item_DuffleBag_Empty_01`, `Item_DuffleBag_Full_01`, `Item_DuffleBag_Open_Empty_01`, `Item_DuffleBag_Open_Full_01`, `Item_Hacksaw_01`, `Item_Hammer_01`, `Item_Handcuffs_01`, `Item_HealthKit_01`, `Item_HealthKit_02`, `Item_Mallet_01`, `Item_Pouch_01`*, `Item_Rope_01`, `Item_ScrewDriver_01`, `Item_WalkieTalkie_01`, `Item_Wirecutter_01`, `Item_Wrench_01`, `Item_ZipTies_01`, `Prop_Drill_01` |
| Loot & Valuables | 25 | `Prop_GoldBar_01`, `Prop_GoldBar_02`, `Prop_Jewellery_01`, `Prop_Jewellery_02`, `Prop_Jewellery_03`, `Prop_Jewellery_04`*, `Prop_Jewellery_Necklace_01`, `Prop_Jewellery_Necklace_02`, `Prop_Jewellery_Necklace_03`, `Prop_Jewellery_Necklace_04`, `Prop_Jewellery_Ring_01`, `Prop_Jewellery_Rings_01`, `Prop_Money_Note_01`, `Prop_Money_Note_02`, `Prop_Money_Note_03`, `Prop_Money_Note_04`, `Prop_Money_Note_05`, `Prop_Money_Note_06`, `Prop_Money_Note_07`, `Prop_Money_Roll_01`, `Prop_Money_Roll_02`, `Prop_Money_Stack_01`, `Prop_Money_Stack_02`, `Prop_Money_Stack_03`, `Prop_VaultTrolley_01` |
| Masks & Hair | 25 | `Item_Hair_Eyebrow_Man_01`, `Item_Hair_Eyebrow_Woman_01`, `Item_Hair_Man_01`, `Item_Hair_Woman_01`, `Item_Mask_Alien_01`, `Item_Mask_Balaclava_01`, `Item_Mask_Beanie_01`, `Item_Mask_Chicken_01`, `Item_Mask_Clown_01`, `Item_Mask_Construction_01`, `Item_Mask_Fox_01`, `Item_Mask_Gas_01`, `Item_Mask_Glasses_01`, `Item_Mask_Hat_01`, `Item_Mask_Hockey_01`, `Item_Mask_Horse_01`, `Item_Mask_Luchador_01`, `Item_Mask_Panda_01`, `Item_Mask_PaperBag_01`, `Item_Mask_Simple_Man_01`, `Item_Mask_Simple_Robber_01`, `Item_Mask_Simple_Woman_01`, `Item_Mask_Tiger_01`, `Item_Mask_Trump_01`, `Item_Mask_WeldersMask_01` |
| Security & Bank | 30 | `Prop_ATM_01`, `Prop_AlarmButton_01`, `Prop_Camera_01`, `Prop_DisplayCase_01`, `Prop_DisplayCase_02`, `Prop_Fire_Detector_01`*, `Prop_Glass_Shard_01`, `Prop_Glass_Shard_02`, `Prop_MetalDetector_01`, `Prop_MetalDetector_Baggage_01`, `Prop_RopeBarrier_01`, `Prop_RopeBarrier_02`, `Prop_RopeBarrier_03`*, `Prop_RopeBarrier_Pole_01`, `Prop_RopeBarrier_Pole_02`, `Prop_SafeDepositBox_Container_01`, `Prop_SafeDepositBox_Container_02`, `Prop_SafeDepositBox_Cover_01`, `Prop_SafeDepositBox_Cover_02`, `Prop_SafeDepositBox_Cover_03`, `Prop_SafeDepositBoxes_01`, `Prop_SafeDepositBoxes_Empty_01`, `Prop_SafeDepositBoxes_Half_01`, `Prop_SafeDepositBoxes_Looted_01`, `Prop_Sprinkler_01`*, `Prop_TellerDesk_01`, `Prop_TellerDesk_02`, `Prop_TellerDesk_03`, `Prop_TellerDesk_Barrier_01`, `Prop_TellerDesk_Barrier_02` |
| Vehicles | 3 | `Veh_Car_Police_Heist_01`, `Veh_Helicopter_01`, `Veh_SwatVan_01` |
| Weapons | 21 | `Wep_Ammo_BulletLarge_01`*, `Wep_Ammo_BulletLarge_02`, `Wep_Ammo_BulletSmall_01`*, `Wep_Ammo_BulletSmall_02`, `Wep_Ammo_Shotgun_01`, `Wep_Attachment_Grip_01`, `Wep_Attachment_M4Rail_01`*, `Wep_Attachment_Redot_01`, `Wep_Attachment_Silencer_01`, `Wep_Attachment_SniperScope_01`, `Wep_Attachment_Torch_01`, `Wep_Flashbang_Base_01`, `Wep_Grenade_Base_01`, `Wep_Holster_01`, `Wep_PistolBandit_01`, `Wep_PistolSwat_01`, `Wep_RifleBandit_01`, `Wep_RifleSwat_01`, `Wep_SMG_01`, `Wep_Shotgun_01`, `Wep_SniperSwat_01` |

`*` = Probable identification. Every model is **READY** (imported and rendered in Godot 4.6). Completeness: 152 complete objects, 71 modular kit pieces, 41 components (attachments, ammo, reticles, hair, deposit-box covers, rope segments).

## 3. Identification

Every model was identified by **looking at its Godot render**, not its filename (see the Models tab and the contact sheets).

- **Confirmed (249).** The render shows unambiguously what it is: all characters, masks, weapons, vehicles, loot, tools and almost the whole building kit.
- **Probable (15).** Small or abstract shapes whose purpose depends on context:
  - `Prop_Fire_Detector_01` and `Prop_Sprinkler_01`: ceiling discs.
  - `Prop_Computer_Mouse_01`: a blob at prefab scale.
  - `Item_Pouch_01`: utility pouch.
  - `Prop_Jewellery_04`: chain tray.
  - `Prop_Folder_04`: a printed sheet.
  - `Prop_Table_02`: vault/counting table.
  - `Prop_Sign_Base_01`: blank backing plate for letter signs.
  - `Prop_RopeBarrier_03`: straight barrier strap.
  - `Wep_Ammo_BulletLarge_01` / `BulletSmall_01`: very low-detail lying rounds.
  - `Wep_Attachment_M4Rail_01`: carry-handle rail.
  - `Env_Ceiling_Light_01`: flat panel light.
  - `Env_Ceiling_08`: recessed bay.
  - `Env_Steps_Edge_01`: kerb piece.
- **Unknown (0).**
- **Real-person likeness:** `SM_Item_Mask_Trump_01` is a recognisable caricature of Donald Trump. Flag it for legal/brand review before shipping. The flags are US flags.

## 4. What can actually be used in Godot

| Status | Models | FX | Evidence |
|---|---:|---:|---|
| **READY** | **264 / 264** | **12 / 13** | Imported, instantiated, and rendered in Forward+ (Vulkan) and Compatibility (OpenGL); load audit reported 0 errors and 0 missing dependencies |
| CONVERSION NEEDED | 0 models, but see animation below | 1 (`FX_Smoke_01`) | One-line fix, verified |
| DEPENDENCY MISSING | 0 | 0 | No plugins, shaders or external files needed |
| UNUSABLE | 0 | 0 | |
| UNVERIFIED | 0 | 0 | Every prefab was loaded and rendered |

**Verified functionally, beyond "it renders":**

- **Skinning works.** Rotating shoulder, head and knee bones from script deforms all outfits correctly.
- **Bone attachments work.** Masks parented to the existing `Head_Bone_Attachments` node follow the head. The hidden skinned duffel-bag strap can be switched on.
- **Interactive sub-parts have correct pivots.** The vault door swings on its hinge. The SWAT van's rear doors open. The briefcase lid opens to show the cash insert. The display-case broken-glass variants toggle. Car/van wheels and helicopter rotors are separate nodes.
- **Collision works.** Every static prefab has a `StaticBody3D` collider. Characters are `CharacterBody3D` with a capsule.
- **Scale is real-world metres.** Characters are about 1.76–1.84 m tall.
- **Cross-pack integration works.** The FX folder was copied into the Heist project *under a different path* and placed in the Demo lobby. References resolved through UIDs with no errors.

**Animation verdict.** The characters are **CONVERSION NEEDED for animation**: they are usable as posed or static models today, but no animation clips exist. To animate them, source humanoid clips (Synty's animation packs, which use this exact bone naming, or Mixamo or similar). Then either retarget them in Godot's import dialog with a `BoneMap` to `SkeletonProfileHumanoid`, or use clips authored for the Synty rig directly. This is identifiable, standard work, but it is not available in these archives.

**Limitations of this check (stated plainly):**

- Rendering ran on Mesa **software** drivers (lavapipe Vulkan, llvmpipe OpenGL) under Xvfb, not a real GPU. Output matched across both renderers except the smoke issue. Performance was not measured.
- The `Demo.tscn` environment enables SSIL, which only exists in Forward+. Compatibility logs a warning and skips it.

## 5. Particle effects

| Effect | Look | Heist use | Status |
|---|---|---|---|
| `FX_Fire_Small/Medium/Large_01` | Stylised flipbook flames (2560² 10×10 sheet), embers, spreading licks | Thermite or explosion aftermath, burning car, diversion fire, the "botched" chaos state | READY |
| `FX_Candle_Flame_01` | Small flickering flame | Candles, lantern | READY |
| `FX_Smoke_01` | Rising column of soft low-poly grey puffs | Breach smoke, smoke-grenade base (raise particle count), chimneys | **CONVERSION NEEDED** |
| `FX_Fog_01` | Low ground fog (soft billboards, proximity fade) | Tear gas / smoke-grenade cover, night mood | READY |
| `FX_Dust_01`, `FX_Dust_Soft_01` | Floating dust motes (very subtle) | Vault and basement air | READY |
| `FX_Sun_Beam_01` | Fake volumetric light shaft | Skylight beams into the lobby | READY |
| `FX_Rain_01`, `FX_Snow_01`, `FX_Leaves_01` | Weather in a small disc; scale it or attach it to the camera to cover an area | Exterior and getaway mood | READY |
| `FX_Flies_01` | Fly swarm | Bins, alleys | READY |

**Smoke fix:** in `FX_Smoke_01.tscn`'s `ParticleProcessMaterial`, set `turbulence_enabled = false` (or set `turbulence_initial_displacement_min/max` to 0). It currently has `turbulence_noise_scale = 0` and an initial displacement of 28–55 m. Compatibility shows the smoke; Forward+ moves every particle out of view. I tested the fixed variant and it renders correctly in Forward+. The archive itself was not modified.

**Missing from the FX library for a heist game:** muzzle flash, bullet impacts and sparks, explosion burst, glass shatter, sparks for drilling or cutting, smoke-grenade burst, alarm or strobe light, money and paper burst, blood. None of these exist and they would need to be built. Godot's built-in particle system makes that straightforward, and the existing circle, soft-circle and fire textures can be reused.

## 6. Missing dependencies and conversions

1. **Animations: missing.** No locomotion, aiming, interaction or hostage clips. The single imported clip is a static pose. This is the main blocker for characters.
2. **Audio: missing entirely.** No SFX (alarms, drills, gunfire, glass, doors) or music.
3. **`FX_Smoke_01` turbulence fix** (one property).
4. **Emission maps are disabled.** The main material `PolygonHeist_01_A_mat` references `Emissive_01.png` but `emission_enabled` is off. Screens, ATM displays and light fixtures therefore do not glow. Enable emission on that material, or a duplicate of it, if glowing screens or lights are wanted. `Emissive_02/03/05.png` and `PolygonHeist_01_Metallic.tga` are unused. `Emissive_04.png` is missing, but nothing references it.
5. **Lowercase paths.** 248 Heist prefabs reference meshes as `res://assets/...` while the folder is `Assets/`. This works because Godot resolves the UIDs first (verified on case-sensitive Linux). If UID caches are ever lost, these paths break. Recommendation: open the project once in the editor and re-save, or batch-fix `assets/` to `Assets/` when integrating.
6. **Unity leftovers:** `New Flare.flare.failed_import` (a Unity YAML file) and `.bak` scene backups. Harmless; drop them when integrating.
7. **Source FBX files absent** for all static models. The meshes are fine in Godot, but they cannot be re-exported or edited in Blender without extracting them from `.res` first (possible via Godot's GLTF export).
8. **Masks on characters.** The prefabs attach hair and eyebrows to the head bone. When a mask is worn, hide the hair (verified in testing). The masks fit the head bone without offsets.
9. **Colour variants.** The B/C texture and material variants (alternate palettes) are not used by any prefab. They are available for recolours at no cost.

## 7. Suitability for a 3D heist game

**High for environments, props, loot and visual identity. Low-to-medium for characters and gameplay feel until animation and audio are sourced.**

POLYGON Heist covers nearly everything a bank or jewellery-store heist level needs:

- A modular building kit: interior and exterior walls, glass walls, doors, pillars, floors, ceilings, roof, stairs, street.
- A round vault door with hinged lid and barred vault gates.
- Teller counters, deposit-box walls in four loot states (full, half, empty, ransacked).
- Smash-able display cases with broken variants, CCTV with a pannable head, alarm button, metal detectors.
- Plenty of loot: cash in many forms, gold, jewellery, open/full duffel bags.
- Heist tools: drill, bomb, crowbar, wire cutters, hacksaw, zip ties.
- 21 masks, 7 weapons with separate moving parts, and 3 vehicles with separate wheels and doors.

The style is consistent low-poly with flat palettes, so it stays cheap to render, and it ships with collision. The FX pack adds fire, fog and smoke in a matching style.

The main gaps are **animation**, **audio** and **combat/impact FX**. A top-down or isometric game, or a stealth/puzzle game with limited character motion, can lean on these assets much sooner than a third-person shooter.

## 8. Shortlist and the gameplay it enables

| Assets | Gameplay it enables |
|---|---|
| `Env_VaultDoor_Frame_01` (hinged lid and handles), `Env_VaultGate_*`, `Prop_Drill_01`, `Item_Bomb_01` | The core objective: drill or blow the vault, timed-drill defence, gate lock-picking |
| `Prop_SafeDepositBoxes_01/_Half/_Empty/_Looted`, `SafeDepositBox_Container/Cover_*` | Progressive looting with visible world state; per-box lockpicking |
| `Prop_DisplayCase_01/02` (broken-glass toggle), `Glass_Shard_*`, `Item_Mallet_01`, jewellery set | Smash-and-grab jewellery-store heist with noise and alarm consequences |
| `Item_DuffleBag_*` (5 states) + skinned strap on characters, `Prop_Money_*`, `GoldBar_*`, `VaultTrolley_01` | Bag carrying/throwing, loot weight and value, a visible "bag fills up" loop |
| `Prop_Camera_01` (pannable head), `Prop_AlarmButton_01`, `Prop_MetalDetector_*`, `Prop_Computer_01` | Stealth layer: camera cones, teller panic buttons, hack a terminal to loop cameras |
| 21 `Item_Mask_*` + 9 characters (civilian, suit, overalls, FBI, SWAT) | Crew customisation, disguise mechanic (overalls/suits blend in until masked), civilians and hostages vs SWAT/FBI escalation |
| `Item_ZipTies_01`, `Item_Handcuffs_01`, `Item_WalkieTalkie_01` | Hostage control, pager/radio checks |
| `Veh_SwatVan_01` (doors), `Veh_Car_Police_Heist_01` (wheels), `Veh_Helicopter_01` (rotors) | Police-response waves, roadblocks, rooftop helicopter escape |
| Weapons (separate mag/slide/trigger) + attachments + reticle meshes | Reload and slide animations by moving sub-parts; silencer for stealth |
| `FX_Fire_*`, `FX_Smoke_01` (fixed), `FX_Fog_01`, `FX_Sun_Beam_01` | "Botched" escalation states (fires, smoke-filled lobby), tear-gas cover, atmosphere |
| Building kit + `Demo.tscn` lobby | A playable bank-lobby greybox can be assembled almost immediately from the existing demo scene |
