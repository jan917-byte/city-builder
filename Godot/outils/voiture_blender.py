# La voiture du trafic, allégée depuis Godot/assets/FREE_CAR_01.blend → Godot/data/voiture.json.
# blender -b Godot/assets/FREE_CAR_01.blend --python Godot/outils/voiture_blender.py
# Couleur par sommet, carrosserie en BLANC : la teinte de l'instance (MultiMesh) la peint.
import bpy, bmesh, json, math, os
from mathutils import Vector
from mathutils.bvhtree import BVHTree

SORTIE = os.path.join(os.path.dirname(bpy.data.filepath), "..", "data", "voiture.json")
LARGEUR = 1.78          # la voiture que les files de trafic.gd supposent
COTES_ROUE = 8
ILOT_MIN = 0.03         # m², sous lequel un détail de couleur ne se lit plus

PEINTURE = (0.208, 0.333, 0.18)       # le vert d'origine, relevé dans la texture
VITRE = (0.28, 0.33, 0.36)            # la teinte de l'ancienne cabine, gardée

img = bpy.data.images[0]
W, H = img.size
PX = list(img.pixels)


def echantillon(u, v):
    x = min(W - 1, max(0, int((u % 1) * W)))
    y = min(H - 1, max(0, int((v % 1) * H)))
    k = (y * W + x) * 4
    return tuple(round(c, 3) for c in PX[k:k + 3])


def proche(a, b):
    return max(abs(x - y) for x, y in zip(a, b)) < 0.01


bm = bmesh.new()
couleurs = []   # une par face, dans l'ordre de création
roues = []
for o in bpy.data.objects:
    if o.type != 'MESH' or o.name in ("interior", "number"):
        continue
    if o.name.startswith("wheel"):
        roues.append(o.matrix_world.translation.copy())
        continue
    tmp = bmesh.new()
    tmp.from_mesh(o.data)
    tmp.transform(o.matrix_world)
    uvl = tmp.loops.layers.uv.active
    vitre = any(s.material and s.material.name == "WINDOW" for s in o.material_slots)
    # Rétros et poignées : les morceaux détachés de moins de 40 cm, sauf les phares
    # et feux (au bout de la carrosserie en y).
    tmp.verts.ensure_lookup_table()
    vu = set()
    for v0 in tmp.verts:
        if v0.index in vu:
            continue
        pile, comp = [v0], []
        vu.add(v0.index)
        while pile:
            a = pile.pop()
            comp.append(a)
            for e in a.link_edges:
                b = e.other_vert(a)
                if b.index not in vu:
                    vu.add(b.index)
                    pile.append(b)
        bas = Vector([min(p.co[i] for p in comp) for i in range(3)])
        haut = Vector([max(p.co[i] for p in comp) for i in range(3)])
        feu = max(abs(bas.y), abs(haut.y)) > 1.5
        if not vitre and (haut - bas).length < 0.4 and not feu:
            bmesh.ops.delete(tmp, geom=comp, context='VERTS')
    corresp = {}
    for v in tmp.verts:
        corresp[v] = bm.verts.new(v.co)
    for f in tmp.faces:
        u = sum(l[uvl].uv.x for l in f.loops) / len(f.loops)
        w = sum(l[uvl].uv.y for l in f.loops) / len(f.loops)
        c = VITRE if vitre else echantillon(u, w)
        try:
            bm.faces.new([corresp[v] for v in f.verts])
            couleurs.append(c)
        except ValueError:
            pass
    tmp.free()

# Les roues refaites à 8 côtés : 478 triangles chacune à l'origine.
PNEU, MOYEU = (0.2, 0.2, 0.2), (0.38, 0.42, 0.439)
for centre in roues:
    r, demi = 0.325, 0.13
    cote = 1 if centre.x > 0 else -1
    ext, intr, moy = [], [], []
    for k in range(COTES_ROUE):
        a = (k + 0.5) * math.tau / COTES_ROUE
        dy, dz = math.cos(a) * r, math.sin(a) * r
        ext.append(bm.verts.new(centre + Vector((cote * demi, dy, dz))))
        intr.append(bm.verts.new(centre + Vector((-cote * demi, dy, dz))))
        moy.append(bm.verts.new(centre + Vector((cote * (demi + 0.005), dy * 0.6, dz * 0.6))))
    for k in range(COTES_ROUE):
        j = (k + 1) % COTES_ROUE
        bm.faces.new([ext[k], ext[j], intr[j], intr[k]]); couleurs.append(PNEU)
        bm.faces.new([ext[k], moy[k], moy[j], ext[j]]); couleurs.append(PNEU)
    bm.faces.new(moy); couleurs.append(MOYEU)
bm.faces.index_update()
bm.normal_update()

# Les faces que la caméra ne voit jamais (dessus de l'horizon, vitres opaques) :
# un rayon sorti de la face doit s'échapper vers le ciel ou l'horizon.
arbre = BVHTree.FromBMesh(bm)
dirs = []
for i in range(24):
    for j in range(6):
        el = j / 5 * math.pi / 2 - 0.05
        az = i / 24 * math.tau
        dirs.append(Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el))))
cachees = []
for f in bm.faces:
    c = f.calc_center_median()
    vue = False
    for d in dirs:
        if f.normal.dot(d) <= 0.02:
            continue
        hit = arbre.ray_cast(c + d * 0.002 + f.normal * 0.001, d)
        if hit[0] is None:
            vue = True
            break
    if not vue:
        cachees.append(f)
garde = {f.index for f in bm.faces} - {f.index for f in cachees}
nb_avant = len(bm.faces)

# Une couleur, un matériau : la dissolution des faces plates ne franchit pas une couleur.
palette = []
idx = []
for k in range(nb_avant):
    c = couleurs[k]
    if proche(c, PEINTURE):
        c = (1.0, 1.0, 1.0)
    p = next((i for i, q in enumerate(palette) if proche(q, c)), None)
    if p is None:
        palette.append(c)
        p = len(palette) - 1
    idx.append(p)
for f in bm.faces:
    f.material_index = idx[f.index]
bmesh.ops.delete(bm, geom=cachees, context='FACES')
print("TRIS0", sum(len(f.verts) - 2 for f in bm.faces))
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)

# Calandre, joints, plaque : les îlots de couleur sous ILOT_MIN prennent la teinte
# du voisin le plus long. Les feux restent : ce sont eux qui disent l'avant.
FEUX = [(0.714, 0.361, 0.11), (0.631, 0.188, 0.192), (0.678, 0.659, 0.647)]
fixe = {i for i, c in enumerate(palette) if any(proche(c, q) for q in FEUX)}
for _ in range(4):
    vus = set()
    for f0 in bm.faces:
        if f0 in vus:
            continue
        ilot, pile = [], [f0]
        vus.add(f0)
        while pile:
            a = pile.pop()
            ilot.append(a)
            for e in a.edges:
                for b in e.link_faces:
                    if b not in vus and b.material_index == f0.material_index:
                        vus.add(b)
                        pile.append(b)
        if f0.material_index in fixe or sum(f.calc_area() for f in ilot) >= ILOT_MIN:
            continue
        bord = {}
        for a in ilot:
            for e in a.edges:
                for b in e.link_faces:
                    if b.material_index != f0.material_index:
                        bord[b.material_index] = bord.get(b.material_index, 0) + e.calc_length()
        if bord:
            neuf = max(bord, key=bord.get)
            for a in ilot:
                a.material_index = neuf
bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(4), verts=bm.verts, edges=bm.edges,
                         delimit={'MATERIAL'})
# 🔴 Une réduction par fusion d'arêtes (Decimate) à 0,6 fond les feux arrière et
# les montants de vitres : essayée, rejetée. Le plancher est ici, ~580 triangles.
bm.normal_update()
couche = bm.faces.layers.int.new("plan")
plan = []
for f in bm.faces:
    f[couche] = len(plan)
    plan.append(f.normal.copy())
bmesh.ops.triangulate(bm, faces=bm.faces, quad_method='BEAUTY', ngon_method='BEAUTY')
bm.verts.index_update()

# Blender (x, y, z), avant vers −y → Godot (x, z, −y), avant vers +z ; posée au sol, centrée.
mn = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
mx = Vector([max(v.co[i] for v in bm.verts) for i in range(3)])
ech = LARGEUR / (mx.x - mn.x)
mil = (mn + mx) / 2


def godot(p):
    q = (p - Vector((mil.x, mil.y, mn.z))) * ech
    return [round(q.x, 4), round(q.z, 4), round(-q.y, 4)]


# Un sommet par (sommet, face plane d'origine) : rendu plat sans tripler les sommets.
d = {"v": [], "n": [], "c": [], "i": []}
deja = {}
for f in bm.faces:
    nrm = plan[f[couche]]
    tri = []
    for l in f.loops:
        cle = (l.vert.index, f[couche])
        if cle not in deja:
            deja[cle] = len(d["v"])
            d["v"].append(godot(l.vert.co))
            d["n"].append([round(nrm.x, 4), round(nrm.z, 4), round(-nrm.y, 4)])
            d["c"].append(list(palette[f.material_index]))
        tri.append(deja[cle])
    d["i"] += [tri[0], tri[2], tri[1]]     # Godot tient la face avant en sens horaire
with open(SORTIE, "w", encoding="utf-8", newline="\n") as fh:
    json.dump(d, fh, separators=(",", ":"))
print("VOITURE %d faces vues sur %d, %d triangles, %d sommets, %.2f x %.2f x %.2f m"
      % (len(garde), nb_avant, len(bm.faces), len(d["v"]),
         (mx.x - mn.x) * ech, (mx.z - mn.z) * ech, (mx.y - mn.y) * ech))

# L'aperçu : le JSON relu tel que Godot le reçoit, peint de trois teintes.
if os.environ.get("APERCU"):
    for o in list(bpy.data.objects):
        o.hide_render = True
    pts = [(x, -z, y) for x, y, z in d["v"]]
    tris = [d["i"][k:k + 3] for k in range(0, len(d["i"]), 3)]
    for k, teinte in enumerate([(0.75, 0.2, 0.15), (0.2, 0.35, 0.6), (0.85, 0.85, 0.82)]):
        me = bpy.data.meshes.new("allegee%d" % k)
        me.from_pydata(pts, [], tris)
        att = me.color_attributes.new("c", 'FLOAT_COLOR', 'CORNER')
        for li, lp in enumerate(me.loops):
            c = d["c"][lp.vertex_index]
            t = teinte if c == [1.0, 1.0, 1.0] else (1, 1, 1)
            att.data[li].color = (*((x * y) ** 2.2 for x, y in zip(c, t)), 1)
        ob = bpy.data.objects.new("allegee%d" % k, me)
        ob.location = (2.6 * (k - 1), 0, 0)
        bpy.context.scene.collection.objects.link(ob)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.color_type = 'VERTEX'
    sc.render.resolution_x, sc.render.resolution_y = 1100, 520
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    for k, p in enumerate([(7, -9, 5), (-7, 9, 4)]):
        cam.location = p
        cam.rotation_euler = (Vector((0, 0, 0.5)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(os.environ["APERCU"], "allegee_%d.png" % k)
        bpy.ops.render.render(write_still=True)
