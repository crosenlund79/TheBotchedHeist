
## 9. Character animation compatibility (`Animations/Female/`)

*Added after the original discovery.* Can the 11 FBX animations in `Animations/Female/` animate our actual Synty Heist characters? **Yes.** None of them play directly, but all 11 play correctly after retargeting, on all nine characters. I verified this in Godot 4.6 by rendering and by measuring the poses against the source.

### 9.1 What the files are

- **Format:** binary FBX 7.x, exported with FBX SDK 2020.2. The `mixamorig` bone prefix identifies them as **Mixamo** exports ("without skin").
- **Contents:** no mesh, one 65-bone skeleton per file, and one clip per file named `mixamo_com`, at 30 fps and real-world scale.
- **Import:** all 11 import into Godot 4.6 with no errors or warnings. Each plays on its own skeleton; the right hand moves 0.65–1.72 m during the clip.
- **Loop flag:** no clip is flagged to loop at source, so the loop setting has to be set at import.
- **Root motion:** the locomotion clips carry forward movement on `Hips`; Mixamo has no root bone.
- **Rig size:** the source skeleton's hips sit at 1.043 m and the head at 1.60 m.

| File | Type | What it shows (identified from the render) | Length | Loop | Root speed (Synty scale) | Pose error vs source (mean / max) |
|---|---|---|---:|---|---:|---:|
| `Female_Idle.fbx` | Idle | Standing idle: weight shifts, glances around, relaxed arms | 16.63 s | loop, seam 0.04° | – | 2.9° / 5.1° |
| `Female_Walking.fbx` | Locomotion | Normal walk cycle | 0.97 s | loop, seam 0.04° | 1.41 m/s | 3.0° / 5.0° |
| `Female_Running.fbx` | Locomotion | Run cycle | 0.70 s | loop, seam 0.04° | 3.17 m/s | 2.8° / 5.0° |
| `Female_Sneak Walk.fbx` | Stealth | Exaggerated tiptoe sneak, hunched with arms out | 0.90 s | loop, seam 0.0° | 2.20 m/s | 2.7° / 5.0° |
| `Female_Crouched Walking.fbx` | Stealth | Low crouched walk cycle | 1.03 s | loop, seam 0.7° | 1.20 m/s | 2.6° / 5.0° |
| `Female_Firing Rifle.fbx` | Combat | Standing rifle aim with recoil kicks | 1.17 s | loop, seam 0.1° | – | 2.6° / 5.0° |
| `Female_Carrying.fbx` | Interaction | Standing in place holding an object in front with both hands (*probable*: no walking) | 10.00 s | loop, seam 0.06° | – | 2.9° / 5.0° |
| `Female_Crouching.fbx` | Stealth | One-shot: standing down to a crouch on one knee | 4.07 s | one-shot | – | 2.9° / 5.0° |
| `Female_Opening.fbx` | Interaction | Reaches forward and pulls something open at chest height (*probable*: door or drawer) | 5.23 s | one-shot | – | 2.9° / 5.0° |
| `Female_Picking Up Object.fbx` | Interaction | Bends, picks an object up from a low surface and lifts it | 3.43 s | one-shot | – | 2.9° / 5.0° |
| `Female_Button Pushing.fbx` | Interaction | Presses a button at chest height with the right hand | 3.23 s | one-shot | – | 2.8° / 5.0° |

### 9.2 Skeleton compatibility

| | Mixamo (`Animations/Female`) | Synty Heist characters |
|---|---|---|
| Bones | 65 (`mixamorig_Hips`, `Spine`, `Spine1`, `Spine2`, `LeftArm`, `LeftForeArm`…) | 50 (`Root`, `Hips`, `Spine_01..03`, `Clavicle_L`, `Shoulder_L`, `Elbow_L`…) |
| Root bone | none (motion is on `Hips`) | `Root` |
| Fingers | 5 per hand, 4 joints each | thumb, index, and one combined `Finger_01–04` chain |
| Extras | `HeadTop_End`, `Toe_End` | `Eyes`, `Eyebrows`, `Jaw` |
| Rest pose | T-pose, hips at 1.043 m | T-pose, hips at 0.876 m |

- **Direct playback does not work.** I tested this by adding each raw clip to a Synty prefab's AnimationPlayer: the bones moved **0.000 m** in all 11 clips, because no track path matches a Synty bone name.
- **All nine Synty characters share one identical skeleton:** the same 50 bone names and the same rest poses, within float noise. A clip that works on one works on all nine. The outfit meshes are just different skins on that skeleton.

### 9.3 Retargeting attempts (both succeeded)

**Path A: baked onto the unmodified prefabs (recommended for this project).** `tools/retarget_bake.gd` maps 40 bones: spine, neck and head, clavicles, arms, legs, feet, toes, thumbs, index fingers, and middle finger to the Synty `Finger` chain. Each frame, it transfers each bone's **world-space rotation away from its T-pose** from the Mixamo rig to the Synty rig. The hip translation is scaled ×0.84, the hip-height ratio.

The output is a pair of Synty-named `AnimationLibrary` resources:
- `synty_female_mixamo_rootmotion.res`: the original forward motion is kept.
- `synty_female_mixamo_inplace.res`: forward drift is removed from the 4 locomotion cycles and loop flags are set.

The existing prefabs play these with **no changes**, so hair, masks on `Head_Bone_Attachments`, the duffel strap and the `CharacterBody3D` collider keep working.

**Path B: Godot's built-in retargeting.** I re-imported the Mixamo FBXs and a copy of `Characters.fbx` with a `BoneMap` to `SkeletonProfileHumanoid` (rest fixer on). Import succeeded; Godot renamed the Synty skeleton to `GeneralSkeleton` with `motion_scale` 0.876, and the clips play on it with **the same poses as path A**.

Path B's drawbacks for this project:
- It changes the skeleton, so the existing prefabs, which use Synty bone names and attach hair through `BoneAttachment3D`, would have to be rebuilt on the re-imported scene.
- It keeps root motion on `Hips`. Mixamo has no root bone, so Godot cannot extract that motion as root motion.

Path B is the more maintainable pipeline if many more clips are added later. Path A works with today's assets.

**Fidelity, measured.** For each clip I compared the world-space direction of 10 limb segments (upper and lower arms, thighs, shins, torso, neck) between the Mixamo source and the Synty result over 41 samples:
- Mean error is about **2.8°**.
- Max error is **5.0–5.1°**. It is constant across clips, so it comes from the small difference between the two T-poses, not from drift.
- **Ground contact holds.** The lowest ankle position stays within 1 cm of the floor, matching the source.
- **Loops are seamless.** The worst seam is 0.7°.

### 9.4 Verdict per animation

| Status | Animations |
|---|---|
| **Works directly** (no conversion) | **None.** Bone names differ, so raw clips move 0 m on the Synty rig |
| **Works after retargeting** (done and verified on all 9 characters) | **All 11.** Idle, Walking, Running, Sneak Walk, Crouched Walking, Firing Rifle, Carrying, Crouching, Opening, Picking Up Object, Button Pushing |
| **Cannot currently be used** | None |

Usage caveats (gameplay integration, not compatibility problems):

- **Locomotion clips** (walk, run, sneak, crouch-walk) contain root motion. Use the in-place variants with code-driven movement at the measured speeds above, or the root-motion variants with your own extraction.
- **Firing Rifle** has no weapon in the clip. Attach a rifle to the right hand with a `BoneAttachment3D` and tuned offsets. The preview places it between the hands from script.
- **Carrying** is a stationary hold. Moving while carrying needs an arm layer over a walk cycle or another clip.
- **Crouching** is a one-way stand-to-crouch transition; its end pose differs from its start by up to 129°. **Picking Up Object** ends holding the object. Both need follow-up clips (crouch idle, stand up) or blending. **Opening** and **Button Pushing** return to their start pose, so they chain from idle.
- **Female motion style on male characters.** The male characters play the female clips without technical issues, but the walk and run styles look feminine. A male set would look better.
- **Licence.** Mixamo animations are generally royalty-free for use inside games, but they may not be redistributed as standalone files. Check the account's terms before shipping.

### 9.5 Evidence

- **Catalogue → Animations tab:**
  - a 33-second reel of a masked `SM_Chr_Female_Overall_01` performing all 11 clips;
  - a lineup of all nine characters, each on a different clip, two holding props;
  - a looping card per clip;
  - side-by-side pose sheets from paths A and B.
- **Video files:** `animation/reel_sequence.mp4` and `animation/reel_lineup.mp4`.
- **Baked libraries:** `animation/synty_female_mixamo_inplace.res` and `animation/synty_female_mixamo_rootmotion.res`, which use Synty bone paths `Skeleton3D:<bone>`.
- **BoneMaps:** `animation/synty_bonemap.tres` and `animation/mixamo_bonemap.tres`.
- **Scripts:** `tools/retarget_bake.gd`, `anim_inspect.gd`, `anim_fidelity.gd`, `anim_direct_seam.gd`, `anim_reel.gd`.

The Mixamo FBX files themselves were not modified.
