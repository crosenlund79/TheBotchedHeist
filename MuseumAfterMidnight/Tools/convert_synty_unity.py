#!/usr/bin/env python3
"""Imports selected Synty Unity prefabs into the Museum After Midnight Godot project.

Run outside Godot, against the extracted ModelProject/SyntyUnity.zip:
    python3 Tools/convert_synty_unity.py <extracted>/Synty

For each selected prefab it
  * follows the prefab (and nested prefab instances) to every MeshFilter/MeshRenderer and
    SkinnedMeshRenderer, resolving the FBX it uses and its Unity material list;
  * converts each Unity material (Synty Generic_Basic Shader Graph or built-in Standard) to a
    Godot StandardMaterial3D .tres: albedo texture, tint, alpha clip, emission, transparency;
  * copies only the FBX files and textures that are needed;
  * writes Assets/Imported/imported_manifest.json, which the game uses to apply the materials
    per mesh node at runtime (Synty character variants share one mesh with different textures,
    so materials are applied per instance instead of per FBX).
"""
import json
import os
import re
import shutil
import sys

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(PROJECT, "Assets", "Imported")

PACKS = {
    "PolygonWestern": "Western",
    "PolygonSamurai": "Samurai",
    "PolygonVikings": "Vikings",
    "PolygonSciFiCity": "SciFiCity",
    "PolygonHorrorMansion": "HorrorMansion",
    "PolygonGeneric": "Generic",
}

SELECTION = {
    "PolygonWestern": ["SM_Veh_Stagecoach_01", "SM_Prop_Piano_01", "SM_Wep_Revolver_01", "SM_Wep_Rifle_01",
                       "SM_Wep_Shotgun_01", "SM_Prop_Saddle_01", "SM_Prop_Cow_Skull_01", "SM_Prop_Lantern_Lit_01",
                       "SM_Env_Cactus_03", "SM_Env_Cactus_07", "SM_Bld_Sign_01", "SM_Bld_Sign_05",
                       "SM_Chr_Sheriff_01", "SM_Chr_Cowgirl_01"],
    "PolygonSamurai": ["SM_Prop_Statue_Lion_01", "SM_Prop_Statue_Lion_02", "SM_Prop_Bell_01", "SM_Prop_Bonsai_01",
                       "SM_Prop_Stone_Lantern_01", "SM_Prop_Paper_Lantern_01", "SM_Prop_WarriorShoulderArmor",
                       "SM_Wep_Odachi_01", "SM_Wep_Naginata_01", "SM_Wep_Ninjato_01", "SM_Wep_Sai_01",
                       "SM_Prop_Zen_Lantern_01", "SM_Chr_Samurai_Warrior_01_Black", "SM_Chr_Ninja_01_Black",
                       "SM_Chr_Geisha_01_White"],
    "PolygonVikings": ["SM_Veh_Boat_01", "SM_Prop_Shield_Decor_01", "SM_Prop_Shield_Decor_02", "SM_Prop_Shield_Decor_03",
                       "SM_Prop_Shield_Decor_04", "SM_Env_Stone_Statue_01", "SM_Prop_Rock_Totem_01", "SM_Prop_Chest_01",
                       "SM_Prop_Anvil_01", "SM_Wep_LargeAxe_01", "SM_Wep_Horn_01", "SM_Wep_Sword_01",
                       "SM_Chr_Chief_01_Brown", "SM_Chr_Shieldmadien_Brown"],
    "PolygonSciFiCity": ["SM_Veh_Hover_Bike_01", "SM_Veh_Hoverboard_01", "SM_Prop_Drone_01", "SM_Prop_Drone_Ball_01",
                         "SM_Prop_Drone_Quad_01", "SM_Prop_Hologram_Bottle_01", "SM_Prop_Robotic_Part_01",
                         "SM_Prop_VendingMachine_Soda_01", "SM_Sign_Neon_01", "SM_Sign_Neon_05", "SM_Sign_Neon_Flat_04",
                         "SM_Wep_Rifle_01", "SM_Wep_Pistol_01", "SM_Chr_Cop_01", "SM_Chr_Robot_01",
                         "SM_Chr_Hacker_Female_01"],
    "PolygonHorrorMansion": ["SM_Prop_Coffin_01", "SM_Prop_Gramophone_01", "SM_Prop_Crystal_Ball_01", "SM_Prop_Clock_01",
                             "SM_Prop_Mask_Count_01", "SM_Prop_Painting_01", "SM_Prop_Painting_02", "SM_Prop_Painting_03",
                             "SM_Prop_Painting_04", "SM_Prop_Mirror_01", "SM_Prop_Lamp_01", "SM_Prop_Chest_01",
                             "SM_Prop_Book_Open_01", "SM_Chr_Count_01", "SM_Chr_Witch_01"],
    "PolygonGeneric": ["SM_Gen_Prop_Statue_01", "SM_Gen_Prop_Statue_02", "SM_Gen_Prop_Statue_03", "SM_Gen_Prop_Statue_04",
                       "SM_Gen_Prop_Statue_05", "SM_Gen_Chr_Skeleton_01"],
}

DOC_RE = re.compile(r"^--- !u!(\d+) &(-?\d+)", re.M)


class Converter:
    def __init__(self, root):
        self.root = root
        self.guid = {}          # guid -> absolute path
        self.prefab_index = {}  # (pack, name) -> path
        for dp, _, files in os.walk(root):
            for f in files:
                p = os.path.join(dp, f)
                if f.endswith(".meta"):
                    m = re.search(r"^guid: (\w+)", open(p, errors="ignore").read(), re.M)
                    if m:
                        self.guid[m.group(1)] = p[:-5]
                elif f.endswith(".prefab") and "/Snow" not in p:
                    pack = os.path.relpath(p, root).split(os.sep)[0]
                    self.prefab_index.setdefault((pack, f[:-7]), p)
        self.materials = {}     # unity mat path -> res path
        self.copied = set()
        self.report = {"materials": 0, "textures": 0, "fbx": 0, "missing": []}

    # ---------------------------------------------------------------- unity yaml
    @staticmethod
    def docs(path):
        text = open(path, errors="ignore").read()
        out = {}
        hits = list(DOC_RE.finditer(text))
        for i, m in enumerate(hits):
            end = hits[i + 1].start() if i + 1 < len(hits) else len(text)
            out[m.group(2)] = (int(m.group(1)), text[m.end():end])
        return out

    def renderers(self, prefab_path, mods=None):
        """[(game_object_name, fbx_path, mesh_name, [mat_paths])] for one prefab."""
        d = self.docs(prefab_path)
        names = {fid: (re.search(r"m_Name: (.*)", body) or [None, ""])[1].strip()
                 for fid, (cls, body) in d.items() if cls == 1}
        active = {fid: "m_IsActive: 0" not in body for fid, (cls, body) in d.items() if cls == 1}
        # A GameObject is visible only if it and all its parents are active.
        go_of_tf, parent_tf = {}, {}
        for fid, (cls, body) in d.items():
            if cls == 4:
                g = re.search(r"m_GameObject: \{fileID: (-?\d+)", body)
                f = re.search(r"m_Father: \{fileID: (-?\d+)", body)
                if g:
                    go_of_tf[fid] = g.group(1)
                    parent_tf[fid] = f.group(1) if f else "0"
        tf_of_go = {v: k for k, v in go_of_tf.items()}
        def visible(go):
            tf = tf_of_go.get(go)
            while tf and tf != "0":
                if not active.get(go_of_tf.get(tf, ""), True):
                    return False
                tf = parent_tf.get(tf)
            return active.get(go, True)
        meshes = {}
        for fid, (cls, body) in d.items():
            if cls == 33:   # MeshFilter
                go = re.search(r"m_GameObject: \{fileID: (-?\d+)", body).group(1)
                m = re.search(r"m_Mesh: \{fileID: (-?\d+), guid: (\w+)", body)
                if m:
                    meshes.setdefault(go, {})["mesh"] = (m.group(1), m.group(2))
        out = []
        for fid, (cls, body) in d.items():
            if cls in (23, 137):  # MeshRenderer, SkinnedMeshRenderer
                go = re.search(r"m_GameObject: \{fileID: (-?\d+)", body).group(1)
                mats = re.findall(r"- \{fileID: 2100000, guid: (\w+)", body.split("m_Materials:")[1].split("m_")[0]) \
                    if "m_Materials:" in body else []
                mesh = None
                if cls == 137:
                    m = re.search(r"m_Mesh: \{fileID: (-?\d+), guid: (\w+)", body)
                    mesh = (m.group(1), m.group(2)) if m else None
                else:
                    mesh = meshes.get(go, {}).get("mesh")
                if mesh and mesh[1] in self.guid:
                    out.append([names.get(go, ""), self.guid[mesh[1]], self.mesh_name(self.guid[mesh[1]], mesh[0]),
                                [self.guid[g] for g in mats if g in self.guid], visible(go)])
        # Nested prefab instances: recurse and apply material overrides.
        for fid, (cls, body) in d.items():
            if cls == 1001:
                src = re.search(r"m_SourcePrefab: \{fileID: \d+, guid: (\w+)", body)
                if not src or src.group(1) not in self.guid:
                    continue
                sub = self.renderers(self.guid[src.group(1)])
                for m in re.finditer(r"propertyPath: m_Materials\.Array\.data\[(\d+)\]\s+value:.*?\s+objectReference: \{fileID: 2100000, guid: (\w+)", body, re.S):
                    idx, g = int(m.group(1)), m.group(2)
                    for r in sub:
                        if g in self.guid and idx < len(r[3]):
                            r[3][idx] = self.guid[g]
                out.extend(sub)
        return out

    def mesh_name(self, fbx_path, file_id):
        meta = open(fbx_path + ".meta", errors="ignore").read()
        m = re.search(r"first:\s*\n\s*43: %s\s*\n\s*second: (.*)" % re.escape(file_id), meta)
        if not m:
            m = re.search(r"%s: (.*)" % re.escape(file_id), meta)
        return m.group(1).strip() if m else ""

    # ---------------------------------------------------------------- copying
    def res_for(self, abs_path, pack, sub):
        short = PACKS[pack]
        dst_dir = os.path.join(OUT, short, sub)
        os.makedirs(dst_dir, exist_ok=True)
        dst = os.path.join(dst_dir, os.path.basename(abs_path))
        if abs_path not in self.copied:
            shutil.copy2(abs_path, dst)
            self.copied.add(abs_path)
            self.report["textures" if sub == "Textures" else "fbx"] += 1
        return "res://" + os.path.relpath(dst, PROJECT).replace(os.sep, "/")

    def pack_of(self, path):
        return os.path.relpath(path, self.root).split(os.sep)[0]

    def material(self, mat_path):
        if mat_path in self.materials:
            return self.materials[mat_path]
        text = open(mat_path, errors="ignore").read()
        pack = self.pack_of(mat_path)

        def tex(*keys):
            for k in keys:
                m = re.search(r"- %s:\n\s+m_Texture: \{fileID: \d+, guid: (\w+)" % k, text)
                if m and m.group(1) in self.guid:
                    return self.guid[m.group(1)]
            return None

        def num(*keys, default=None):
            for k in keys:
                m = re.search(r"- %s: ([-\d.e]+)\n" % k, text)
                if m:
                    return float(m.group(1))
            return default

        def col(*keys):
            for k in keys:
                m = re.search(r"- %s: \{r: ([-\d.e]+), g: ([-\d.e]+), b: ([-\d.e]+), a: ([-\d.e]+)\}" % k, text)
                if m:
                    return [float(x) for x in m.groups()]
            return None

        name = os.path.basename(mat_path)[:-4]
        albedo = tex("_Albedo_Map", "_BaseMap", "_MainTex")
        emis = tex("_Emission_Map", "_EmissionMap")
        tint = col("_Albedo_Tint", "_BaseColor", "_Color") or [1, 1, 1, 1]
        # Synty's Generic shaders use _Emission_Color (map x colour); the built-in Standard
        # shader uses _EmissionColor. A black colour means no emission.
        emis_col = col("_Emission_Color") if "- _Emission_Color:" in text else (col("_EmissionColor") or [0, 0, 0, 0])
        emis_col = emis_col or [0, 0, 0, 0]
        if "- _Emission_Color:" not in text and "_EMISSION" not in text:
            emis_col = [0, 0, 0, 0]
        mode = num("_Mode", default=0)
        surface = num("_Surface", "_BUILTIN_Surface", default=0)
        transparent = mode >= 2 or surface == 1 or "glass" in name.lower()
        clip = (num("_AlphaClip", "_BUILTIN_AlphaClip", default=0) == 1 or mode == 1) and not transparent
        smooth = num("_Smoothness", "_Glossiness", default=0.15)
        metal = num("_Metallic", default=0.0)

        ext, lines, n = [], [], 1
        def add_tex(p):
            nonlocal n
            rid = "%d_tex" % n
            n += 1
            ext.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % (self.res_for(p, self.pack_of(p), "Textures"), rid))
            return rid
        lines.append('resource_name = "%s"' % name)
        if albedo:
            lines.append('albedo_texture = ExtResource("%s")' % add_tex(albedo))
        lines.append("albedo_color = Color(%.4f, %.4f, %.4f, %.4f)" % (tint[0], tint[1], tint[2], 0.35 if transparent else 1.0))
        lines.append("roughness = %.3f" % max(0.05, min(1.0, 1.0 - smooth)))
        lines.append("metallic = %.3f" % metal)
        if transparent:
            lines.append("transparency = 1")
            lines.append("cull_mode = 2")
        elif clip:
            lines.append("transparency = 2")
            lines.append("alpha_scissor_threshold = %.3f" % num("_Alpha_Clip_Threshold", "_Cutoff", default=0.5))
            lines.append("cull_mode = 2")
        if max(emis_col[:3]) > 0.01:
            lines.append("emission_enabled = true")
            lines.append("emission = Color(%.4f, %.4f, %.4f, 1)" % tuple(emis_col[:3]))
            lines.append("emission_operator = 1")  # multiply colour by map, as in Synty's shader
            if emis:
                lines.append('emission_texture = ExtResource("%s")' % add_tex(emis))
            lines.append("emission_energy_multiplier = 2.0")
        dst_dir = os.path.join(OUT, PACKS[pack], "Materials")
        os.makedirs(dst_dir, exist_ok=True)
        dst = os.path.join(dst_dir, name + ".tres")
        with open(dst, "w") as f:
            f.write('[gd_resource type="StandardMaterial3D" format=3]\n\n')
            f.write("\n".join(ext) + ("\n\n" if ext else ""))
            f.write("[resource]\n" + "\n".join(lines) + "\n")
        res = "res://" + os.path.relpath(dst, PROJECT).replace(os.sep, "/")
        self.materials[mat_path] = res
        self.report["materials"] += 1
        return res

    # ---------------------------------------------------------------- main
    def run(self):
        manifest = {}
        for pack, names in SELECTION.items():
            for name in names:
                path = self.prefab_index.get((pack, name))
                if not path:
                    self.report["missing"].append("%s/%s" % (pack, name))
                    continue
                parts = []
                for go, fbx, mesh, mats, vis in self.renderers(path):
                    if not vis:
                        continue
                    parts.append({"node": go, "mesh": mesh,
                                  "fbx": self.res_for(fbx, self.pack_of(fbx), "Models"),
                                  "materials": [self.material(m) for m in mats]})
                if not parts:
                    self.report["missing"].append("%s/%s (no renderers)" % (pack, name))
                    continue
                # The main FBX is the one holding the body (Characters.fbx for characters);
                # attachments from other FBX files are merged onto its skeleton in Godot.
                main = next((q["fbx"] for q in parts if os.path.basename(q["fbx"]).lower().endswith("characters.fbx")), parts[0]["fbx"])
                manifest[name] = {"pack": PACKS[pack], "fbx": main, "parts": parts,
                                  "character": "_Chr_" in name}
        with open(os.path.join(OUT, "imported_manifest.json"), "w") as f:
            json.dump(manifest, f, indent=1)
        print("prefabs: %d  fbx: %d  materials: %d  textures: %d" % (
            len(manifest), self.report["fbx"], self.report["materials"], self.report["textures"]))
        if self.report["missing"]:
            print("missing:", self.report["missing"])


if __name__ == "__main__":
    Converter(os.path.abspath(sys.argv[1])).run()
