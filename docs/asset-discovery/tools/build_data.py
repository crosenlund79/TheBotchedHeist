import sys, os, json, base64, io
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from meta import classify
from PIL import Image
S = sys.argv[1]
def b64(im, q=78):
    buf = io.BytesIO(); im.save(buf, "WEBP", quality=q, method=6); return "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode()
def thumb(path, size=240):
    im = Image.open(path).convert("RGB")
    # crop to content bbox (background is flat)
    bg = im.getpixel((2, 2)); diff = Image.new("RGB", im.size, bg)
    from PIL import ImageChops
    bbox = ImageChops.difference(im, diff).convert("L").point(lambda v: 255 if v > 12 else 0).getbbox()
    if bbox:
        x0, y0, x1, y1 = bbox; cx, cy = (x0+x1)/2, (y0+y1)/2; r = max(x1-x0, y1-y0)/2*1.12 + 4
        r = min(r, im.size[0]/2)
        cx = min(max(cx, r), im.size[0]-r); cy = min(max(cy, r), im.size[1]-r)
        im = im.crop((int(cx-r), int(cy-r), int(cx+r), int(cy+r)))
    return b64(im.resize((size, size), Image.LANCZOS))
audit = json.load(open(f"{S}/audit_heist.json"))
models = []
for x in audit:
    if "/Prefab/" not in x["path"]: continue
    name = x["path"].split("/")[-1][:-5]
    cat, rep, use, comp, conf = classify(name)
    mats = sorted({m.get("path", "").replace("_mat.tres", "") for m in x["materials"] if m.get("path")})
    texs = sorted({m.get("albedo_tex", "") for m in x["materials"] if m.get("albedo_tex")})
    parts = [m["mesh"].rsplit(".", 1)[0] for m in x["meshes"]]
    hidden = [m["mesh"].rsplit(".", 1)[0] for m in x["meshes"] if not m["visible"]]
    skinned = x["skinned"]
    ab = x["aabbs"]
    if ab:
        mn = [min(a[i] for a in ab) for i in range(3)]; mx = [max(a[i]+a[i+3] for a in ab) for i in range(3)]
        dims = [round(mx[i]-mn[i], 2) for i in range(3)]
    else: dims = None
    status = "READY"
    notes = []
    if skinned:
        notes.append("Rigged: Skeleton3D with 50 bones, 10 outfit meshes share one skeleton (one visible per prefab). No usable animation clips: the AnimationPlayer is empty and the only clip (Take 001) is a static one-key pose. Animations must come from elsewhere.")
        dims = [0.5, round(max(a[1]+a[4] for a in ab), 2), 0.4]
    if hidden: notes.append("Hidden alternate parts: " + ", ".join(h.replace(name, "*") for h in hidden))
    if name == "SM_Item_Mask_Trump_01": notes.append("Real-person likeness: legal/brand review advised.")
    models.append({"name": name, "path": x["path"].replace("res://", "TheHeist.zip › polygon-heist-01/"),
        "cat": cat, "rep": rep, "use": use, "comp": comp, "conf": conf, "status": status,
        "tris": x["tris"], "verts": x["verts"], "parts": len(parts),
        "subparts": [p.replace(name, "*") for p in parts[1:]] if not skinned else [],
        "mats": mats, "texs": texs, "skinned": skinned, "bones": x["skeleton_bones"],
        "anims": "Static pose only (Take 001)" if skinned else "None",
        "coll": sorted(set(x["collision"])), "dims": dims, "notes": notes,
        "img": thumb(f"{S}/prev/models_fplus/{name}.png")})
FXD = {
 "FX_Candle_Flame_01": ("Fire & Light", "Small flickering candle flame, 6 particles on a flame sprite, unshaded", "Candles in an office or vault, lantern flavour, a stealth 'light source' cue", "fx_fplus"),
 "FX_Fire_Small_01": ("Fire & Light", "Small fire: a 10×10 flipbook flame sprite plus an embers emitter", "Burning wastebin, small fire after a thermite cut, sabotage distraction", "anim"),
 "FX_Fire_Medium_01": ("Fire & Light", "Medium fire: flipbook flames, embers and a 'spread' emitter", "Burning car or desk, aftermath of an explosion", "anim"),
 "FX_Fire_Large_01": ("Fire & Light", "Large blaze: 3 emitters (flipbook flames, embers, spreading flames)", "Fire as a diversion, a burning getaway vehicle, the botched-heist chaos state", "anim"),
 "FX_Smoke_01": ("Smoke & Atmosphere", "Rising column of soft grey low-poly smoke puffs, 15 particles", "Smoke after a breach or explosion, a smoke-grenade cloud (needs more particles), chimneys", "gl"),
 "FX_Fog_01": ("Smoke & Atmosphere", "Low ground fog: 50 large soft billboards with proximity fade", "Tear gas or smoke-grenade cover, night exterior mood, vault mist", "anim"),
 "FX_Dust_01": ("Smoke & Atmosphere", "Floating dust motes, 80 additive dots over 8 s", "Dusty vault or basement air, light shafts; subtle", "fx_fplus"),
 "FX_Dust_Soft_01": ("Smoke & Atmosphere", "Softer, fainter version of the dust motes", "Ambient interior atmosphere; very subtle", "fx_fplus"),
 "FX_Sun_Beam_01": ("Smoke & Atmosphere", "Volumetric-looking light shaft built from 8 slow billboard beams", "Light through a skylight or window into the lobby or vault", "anim"),
 "FX_Rain_01": ("Weather", "Rain: 500 ribbon-trail streaks falling in a 1.3 m disc", "Night exterior or getaway mood (scale or tile it to cover an area)", "fx_fplus"),
 "FX_Snow_01": ("Weather", "Falling snowflakes, 150 additive dots", "Winter variant of an exterior level", "fx_fplus"),
 "FX_Leaves_01": ("Weather", "Drifting leaves, 50 textured leaf quads over 12 s", "Park or street ambience outside the bank", "fx_fplus"),
 "FX_Flies_01": ("Ambient Life", "Swarm of small dark flies buzzing around a point", "Rubbish bins or alleys, environmental storytelling", "anim"),
}
fxa = json.load(open(f"{S}/audit_fx.json"))
fx = []
for x in fxa:
    n = x["path"].split("/")[-1][:-5]
    if n not in FXD: continue
    cat, desc, use, src = FXD[n]
    if src == "anim":
        frames = [Image.open(f"{S}/prev/fxanim_fp/{n}_{i:02d}.png").convert("RGB").resize((240, 240), Image.LANCZOS) for i in range(24)]
        buf = io.BytesIO(); frames[0].save(buf, "WEBP", save_all=True, append_images=frames[1:], duration=100, loop=0, quality=70)
        img = "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode(); animated = True
    else:
        p = f"{S}/prev/fx/{n}.png" if src == "gl" else f"{S}/prev/fx_fplus/{n}.png"
        img = b64(Image.open(p).convert("RGB").resize((240, 240), Image.LANCZOS)); animated = False
    st = "READY"; note = ""
    if n == "FX_Smoke_01":
        st = "CONVERSION NEEDED"; note = "Invisible in Forward+ (the project's renderer): the turbulence block sets initial_displacement to 28–55 m with noise_scale 0, which throws the particles out of view. It renders in Compatibility (preview shown). Fix: set turbulence_enabled = false or initial displacement to 0. Verified: with turbulence off it renders correctly in Forward+."
    if n == "FX_Fog_01": note = "Uses proximity fade and distance fade; looks the same in Forward+ and Compatibility."
    parts = x["particles"]
    fx.append({"name": n, "cat": cat, "desc": desc, "use": use, "status": st, "note": note, "animated": animated,
        "emitters": len(parts), "particles": sum(p["amount"] for p in parts),
        "lifetime": max(p["lifetime"] for p in parts),
        "textures": sorted({d["material"].get("albedo_tex", "") for p in parts for d in p["draw_passes"] if d["material"].get("albedo_tex")}),
        "draw": sorted({d["mesh"] for p in parts for d in p["draw_passes"]}),
        "path": x["path"].replace("res://", "ParticleFX.zip › particle-fx/"), "img": img})
scenes = []
for fn, title, desc in [("prev/fplus/Heist_Demo.png", "Heist › Demo.tscn", "A dressed bank lobby built from 133 distinct prefabs (1,263 mesh instances, 10 lights). Forward+ render."),
                        ("prev/fplus/Heist_Overview.png", "Heist › Overview.tscn", "Every static prefab laid out on a showcase plinth (248 prefabs). Forward+ render."),
                        ("prev/scenes/FX_Overview.png", "ParticleFX › Overview.tscn", "All 13 effects side by side. Compatibility render: the smoke column is visible here and disappears in Forward+."),
                        ("prev/tests/test_fx_in_heist_lobby.png", "Integration test", "FX copied into the Heist project at a different folder path and placed in the Demo lobby with a SWAT character and a full loot bag. Paths resolved through UIDs, no errors."),
                        ("prev/tests/test_skinning_pose.png", "Skinning test", "Bones rotated from script (shoulders, head, knee): the meshes deform correctly. Proves the skeleton and skin weights work."),
                        ("prev/tests/test_masks_on_head_bone.png", "Mask attachment test", "Masks parented to the Head BoneAttachment3D. The skinned duffel-bag strap mesh is switched on for the first character."),
                        ("prev/tests/test_interactive_states.png", "Interactive parts test", "Sub-parts rotated about their own pivots: the vault door swings on its hinge, the SWAT van's rear doors open, the briefcase lid opens to show cash. The display case's broken-glass variant is switched on.")]:
    im = Image.open(f"{S}/{fn}").convert("RGB"); im.thumbnail((960, 600), Image.LANCZOS)
    scenes.append({"title": title, "desc": desc, "img": b64(im, 80)})
json.dump({"models": models, "fx": fx, "scenes": scenes}, open(f"{S}/catalogue_data.json", "w"))
print(len(models), len(fx), len(scenes), os.path.getsize(f"{S}/catalogue_data.json")//1024, "KB")
from collections import Counter
print(Counter(m["cat"] for m in models)); print(Counter(m["conf"] for m in models)); print(Counter(m["comp"] for m in models))
