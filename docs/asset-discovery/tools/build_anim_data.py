import sys, os, json, base64, io, glob
from PIL import Image
S = sys.argv[1]
def webp_anim(frames, dur, q=62):
    buf = io.BytesIO(); frames[0].save(buf, "WEBP", save_all=True, append_images=frames[1:], duration=dur, loop=0, quality=q, method=4)
    return "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode()
raw = {r["file"]: r for r in json.load(open(f"{S}/anim_raw.json"))}
bake = {r["clip"]: r for r in json.load(open(f"{S}/bake_report.json"))}
fid = json.load(open(f"{S}/anim_fidelity.json"))
ds = json.load(open(f"{S}/anim_direct_seam.json"))
INFO = {
 "idle": ("Idle", "Standing idle: weight shifts, glances around, relaxed arms", "Default stance for crew, guards, tellers and civilians", "Confirmed", ""),
 "walking": ("Locomotion", "Normal walk cycle", "Casual movement, civilians, crew in disguise", "Confirmed", ""),
 "running": ("Locomotion", "Run cycle", "Escape, sprinting to the getaway, SWAT rush", "Confirmed", ""),
 "sneak_walk": ("Stealth", "Exaggerated tiptoe sneak, hunched with arms out", "Stealth approach past cameras and guards (cartoonish style)", "Confirmed", ""),
 "crouched_walking": ("Stealth", "Low crouched walk cycle", "Moving behind counters and cover", "Confirmed", ""),
 "firing_rifle": ("Combat", "Standing rifle aim with recoil kicks", "Shooting: SWAT and armed crew. Needs a rifle attached to the right hand", "Confirmed", "No weapon in the clip; the preview attaches SM_Wep_RifleSwat_01 between the hands."),
 "carrying": ("Interaction", "Standing in place while holding an object in front with both hands", "Holding a loot box or bag. It is stationary: there is no carry-walk cycle", "Probable", "Stationary hold; for carrying while moving, layer the arms over a walk or source a carry-walk clip."),
 "crouching": ("Stealth", "One-shot transition from standing down to a crouch on one knee", "Take cover, hide, kneel at a safe or a drill", "Confirmed", "One-way transition: it ends crouched (end pose differs from start by up to 129°). Needs a crouch idle and a stand-up clip to chain."),
 "opening": ("Interaction", "Reaches forward and pulls something open at chest height", "Opening doors, drawers, deposit boxes, the vault", "Probable", ""),
 "picking_up_object": ("Interaction", "Bends, picks an object up from a low surface and lifts it", "Grabbing loot, cash stacks, bags and tools", "Confirmed", "Ends holding the object (end pose differs from start), so blend into idle or carrying afterwards."),
 "button_pushing": ("Interaction", "Presses a button at chest height with the right hand", "Teller panic button, keypads, elevator, hacking a terminal", "Confirmed", ""),
}
anims = []
for clip, (cat, rep, use, conf, note) in INFO.items():
    b = bake[clip]; f = fid[clip]; s = ds[clip]; r = raw[b["file"]]
    frames = [Image.open(f"{S}/prev/anim_cards/{clip}_{i:02d}.png").convert("RGB").resize((240, 288), Image.LANCZOS) for i in range(16)]
    dur = max(60, int(b["length"] * 1000 / 16)) if b["length"] < 6 else 180
    speed = b["root_travel_m"] / b["length"] if b["in_place_variant"] else 0
    anims.append({"clip": clip, "file": b["file"], "cat": cat, "rep": rep, "use": use, "conf": conf, "note": note,
        "length": round(b["length"], 2), "frames": b["frames"], "src_tracks": b["source_tracks"], "src_bones": r["bone_count"],
        "loop": b["loop"], "root_motion": b["in_place_variant"], "speed": round(speed, 2), "travel": round(b["root_travel_m"], 2),
        "fid_mean": round(f["mean_deg"], 1), "fid_max": round(f["max_deg"], 1), "seam": round(s["loop_seam_max_deg"], 2),
        "direct": s["raw_direct_hand_moved_m"], "img": webp_anim(frames, dur)})
lineup = [Image.open(p).convert("RGB").resize((800, 338), Image.LANCZOS) for p in sorted(glob.glob(f"{S}/reel_l_lab/f_*.png"))[::2]]
seq = [Image.open(p).convert("RGB").resize((420, 315), Image.LANCZOS) for p in sorted(glob.glob(f"{S}/reel_s_lab/f_*.png"))[::3]]
sheet_custom = Image.open(f"{S}/sheets/anim_custom.png").convert("RGB"); sheet_custom.thumbnail((900, 1800))
sheet_off = Image.open(f"{S}/sheets/anim_official.png").convert("RGB"); sheet_off.thumbnail((900, 1800))
def still(im, q=72):
    buf = io.BytesIO(); im.save(buf, "WEBP", quality=q); return "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode()
d = json.load(open(f"{S}/catalogue_data.json"))
d["anims"] = anims
d["anim_reels"] = {"lineup": webp_anim(lineup, 1000 // 12, 60), "sequence": webp_anim(seq, 1000 // 8, 58),
                   "sheet_custom": still(sheet_custom), "sheet_official": still(sheet_off)}
json.dump(d, open(f"{S}/catalogue_data.json", "w"))
print(len(anims), os.path.getsize(f"{S}/catalogue_data.json") // 1024, "KB", {k: len(v) // 1024 for k, v in d["anim_reels"].items()})
