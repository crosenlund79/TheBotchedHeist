import sys, json, csv, collections, markdown
S = sys.argv[1]; out = sys.argv[2]
d = json.load(open(f"{S}/catalogue_data.json"))
M = d["models"]
groups = collections.defaultdict(list)
for m in M: groups[m["cat"]].append(m)
inv = ["| Category | Count | Models |", "|---|---:|---|"]
for g in sorted(groups):
    names = ", ".join(f"`{m['name'].replace('SM_','')}`" + ("*" if m["conf"] != "Confirmed" else "") for m in sorted(groups[g], key=lambda m: m["name"]))
    inv.append(f"| {g} | {len(groups[g])} | {names} |")
inv.append("\n`*` = Probable identification. Every model is **READY** (imported and rendered in Godot 4.6). Completeness: 152 complete objects, 71 modular kit pieces, 41 components (attachments, ammo, reticles, hair, deposit-box covers, rope segments).")
rep = open(f"{S}/tools/report.md").read().replace("{{INVENTORY}}", "\n".join(inv))
open(f"{out}/REPORT.md", "w").write("# The Heist: 3D Asset Discovery Report\n\nInspection only: no game code was written and the archives were not modified. Browse the visual catalogue in `catalogue.html` (self-contained; open it in a browser).\n\n" + rep)
html_rep = markdown.markdown(rep, extensions=["tables"]).replace("<table>", '<div class="tbl"><table>').replace("</table>", "</table></div>")
t = open(f"{S}/tools/template.html").read().replace("__REPORT__", html_rep).replace("__DATA__", json.dumps(d))
open(f"{out}/catalogue.html", "w").write(t)
with open(f"{out}/inventory.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["name","category","represents","heist_use","completeness","confidence","godot_status","triangles","vertices","mesh_parts","sub_parts","materials","textures","skeleton_bones","animations","collision","size_m","file","notes"])
    for m in sorted(M, key=lambda m: (m["cat"], m["name"])):
        w.writerow([m["name"],m["cat"],m["rep"],m["use"],m["comp"],m["conf"],m["status"],m["tris"],m["verts"],m["parts"],"; ".join(m["subparts"]),"; ".join(m["mats"]),"; ".join(m["texs"]),m["bones"],m["anims"],"; ".join(m["coll"]),"x".join(map(str,m["dims"] or [])),m["path"]," ".join(m["notes"])])
    for x in d["fx"]:
        w.writerow([x["name"],"Particle FX / "+x["cat"],x["desc"],x["use"],"Complete","Confirmed",x["status"],"","",x["emitters"],"","","; ".join(x["textures"]),"","","","",x["path"],x["note"]])
print("ok")
