# La voiture du trafic, allégée depuis Godot/assets/FREE_CAR_01.blend → Godot/data/voiture.json.
# blender -b Godot/assets/FREE_CAR_01.blend --python Godot/outils/voiture_blender.py
# Couleur par face, carrosserie en BLANC : la teinte de l'instance (MultiMesh) la peint.
import bpy, bmesh, json, math, os
from mathutils import Vector
from mathutils.bvhtree import BVHTree

SORTIE = os.path.join(os.path.dirname(bpy.data.filepath), "..", "data", "voiture.json")
LARGEUR = 1.78          # la voiture que les files de trafic.gd supposent
COTES_ROUE = 10         # 8 se lisait octogonal de près

PEINTURE = (0.208, 0.333, 0.18)       # le vert d'origine, relevé dans la texture
VITRE = (0.28, 0.33, 0.36)            # la teinte de l'ancienne cabine, gardée
PNEU, MOYEU = (0.2, 0.2, 0.2), (0.38, 0.42, 0.439)

img = bpy.data.images[0]
W, H = img.size
PX = list(img.pixels)
palette = []


def teinte(c):
    """L'indice de la couleur dans la palette ; le vert d'origine devient le blanc à peindre."""
    if max(abs(x - y) for x, y in zip(c, PEINTURE)) < 0.01:
        c = (1.0, 1.0, 1.0)
    for i, q in enumerate(palette):
        if max(abs(x - y) for x, y in zip(c, q)) < 0.01:
            return i
    palette.append(c)
    return len(palette) - 1


def echantillon(u, v):
    x = min(W - 1, max(0, int((u % 1) * W)))
    y = min(H - 1, max(0, int((v % 1) * H)))
    k = (y * W + x) * 4
    return tuple(round(c, 3) for c in PX[k:k + 3])


def morceaux(bmx):
    bmx.verts.ensure_lookup_table()
    vu = set()
    for v0 in bmx.verts:
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
        yield comp


# --- lecture : la carrosserie d'un côté, les roues refaites de l'autre -------
caisse = bmesh.new()
roues = bmesh.new()
for o in bpy.data.objects:
    if o.type != 'MESH' or o.name in ("interior", "number"):
        continue
    tmp = bmesh.new()
    tmp.from_mesh(o.data)
    tmp.transform(o.matrix_world)
    if o.name.startswith("wheel"):
        # 478 triangles à l'origine. Centre et taille pris sur les sommets : l'origine
        # de l'objet n'est pas le moyeu.
        bas = Vector([min(v.co[i] for v in tmp.verts) for i in range(3)])
        haut = Vector([max(v.co[i] for v in tmp.verts) for i in range(3)])
        centre, r, demi = (bas + haut) / 2, (haut.z - bas.z) / 2, (haut.x - bas.x) / 2
        cote = 1 if centre.x > 0 else -1
        ext, intr, moy = [], [], []
        for k in range(COTES_ROUE):
            a = (k + 0.5) * math.tau / COTES_ROUE
            dy, dz = math.cos(a) * r, math.sin(a) * r
            ext.append(roues.verts.new(centre + Vector((cote * demi, dy, dz))))
            intr.append(roues.verts.new(centre + Vector((-cote * demi, dy, dz))))
            moy.append(roues.verts.new(centre + Vector((cote * demi, dy * 0.62, dz * 0.62))))
        neuves = []
        for k in range(COTES_ROUE):
            j = (k + 1) % COTES_ROUE
            neuves.append((roues.faces.new([ext[k], ext[j], intr[j], intr[k]]), PNEU))
            neuves.append((roues.faces.new([ext[k], moy[k], moy[j], ext[j]]), PNEU))
        neuves.append((roues.faces.new(moy), MOYEU))
        # 🔴 L'ordre des sommets ne dit pas le dehors des deux côtés : le flanc gauche
        # regardait l'essieu, invisible dans Godot. On retourne ce qui regarde dedans.
        for f, c in neuves:
            f.material_index = teinte(c)
            f.normal_update()
            m = f.calc_center_median() - centre
            dehors = Vector((cote, 0, 0)) if abs(f.normal.x) > 0.5 else Vector((0, m.y, m.z))
            if f.normal.dot(dehors) < 0:
                f.normal_flip()
        tmp.free()
        continue
    uvl = tmp.loops.layers.uv.active
    vitre = any(s.material and s.material.name == "WINDOW" for s in o.material_slots)
    # Rétros et poignées : les morceaux détachés de moins de 40 cm, sauf les phares
    # et feux (au bout de la carrosserie en y).
    for comp in list(morceaux(tmp)):
        bas = Vector([min(p.co[i] for p in comp) for i in range(3)])
        haut = Vector([max(p.co[i] for p in comp) for i in range(3)])
        feu = max(abs(bas.y), abs(haut.y)) > 1.5
        if not vitre and (haut - bas).length < 0.4 and not feu:
            bmesh.ops.delete(tmp, geom=comp, context='VERTS')
    corresp = {v: caisse.verts.new(v.co) for v in tmp.verts}
    for f in tmp.faces:
        u = sum(l[uvl].uv.x for l in f.loops) / len(f.loops)
        w = sum(l[uvl].uv.y for l in f.loops) / len(f.loops)
        try:
            nf = caisse.faces.new([corresp[v] for v in f.verts])
        except ValueError:
            continue
        nf.material_index = teinte(VITRE if vitre else echantillon(u, w))
    tmp.free()
for bmx in (caisse, roues):
    bmx.normal_update()

# --- les faces que la caméra ne voit jamais (dessus de l'horizon, vitres opaques)
# 🔴 Testée au SEUL centre, une face à moitié cachée partait : dessus des phares sous
# le capot, pneus dans le passage de roue. Une face part si TOUS ses points sont cachés.
tous_v, tous_f = [], []
for bmx in (caisse, roues):
    base = len(tous_v)
    bmx.verts.index_update()
    tous_v += [v.co.copy() for v in bmx.verts]
    tous_f += [[base + v.index for v in f.verts] for f in bmx.faces]
arbre = BVHTree.FromPolygons(tous_v, tous_f)
dirs = []
for i in range(24):
    for j in range(6):
        el = j / 5 * math.pi / 2 - 0.05
        az = i / 24 * math.tau
        dirs.append(Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el))))


def visible(f):
    c = f.calc_center_median()
    for p in [c] + [c + (v.co - c) * 0.85 for v in f.verts]:
        for d in dirs:
            if f.normal.dot(d) > 0.02 and arbre.ray_cast(p + f.normal * 0.002, d)[0] is None:
                return True
    return False


avant = len(caisse.faces) + len(roues.faces)
for bmx in (caisse, roues):
    bmesh.ops.delete(bmx, geom=[f for f in bmx.faces if not visible(f)], context='FACES')
vues = len(caisse.faces) + len(roues.faces)

# --- simplification de la carrosserie seule : les faces planes d'une même couleur
# fusionnent. Les roues n'y passent pas : leur flanc plan fondait en anneau troué.
bmesh.ops.remove_doubles(caisse, verts=caisse.verts, dist=0.0005)
bmesh.ops.dissolve_limit(caisse, angle_limit=math.radians(4), verts=caisse.verts,
                         edges=caisse.edges, delimit={'MATERIAL'})
# 🔴 Une réduction par fusion d'arêtes (Decimate) à 0,6 fond les feux arrière et
# les montants de vitres : essayée, rejetée. Fusionner les petits îlots de couleur
# aussi : la fente de calandre virait au rouge.

# --- export : Blender (x, y, z), avant vers −y → Godot (x, z, −y), avant vers +z
d = {"v": [], "n": [], "c": [], "i": []}
tris = 0
for bmx in (caisse, roues):
    bmx.normal_update()
    couche = bmx.faces.layers.int.new("plan")
    plan = []
    for f in bmx.faces:
        f[couche] = len(plan)
        plan.append(f.normal.copy())
    bmesh.ops.triangulate(bmx, faces=bmx.faces, quad_method='BEAUTY', ngon_method='BEAUTY')
    bmx.verts.index_update()
    tris += len(bmx.faces)
mn = Vector([min(v.co[i] for b in (caisse, roues) for v in b.verts) for i in range(3)])
mx = Vector([max(v.co[i] for b in (caisse, roues) for v in b.verts) for i in range(3)])
ech = LARGEUR / (mx.x - mn.x)
mil = (mn + mx) / 2


def godot(p):
    q = (p - Vector((mil.x, mil.y, mn.z))) * ech
    return [round(q.x, 4), round(q.z, 4), round(-q.y, 4)]


# Un sommet par (sommet, face plane d'origine) : rendu plat sans tripler les sommets.
for bmx in (caisse, roues):
    couche = bmx.faces.layers.int["plan"]
    plan = {}
    for f in bmx.faces:
        plan.setdefault(f[couche], f.normal.copy())
    deja = {}
    for f in bmx.faces:
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
      % (vues, avant, tris, len(d["v"]),
         (mx.x - mn.x) * ech, (mx.z - mn.z) * ech, (mx.y - mn.y) * ech))
